import AppKit
import Foundation
import AgentDockCore

/// 应用内一键更新(对齐 Wallpaper Exchange UpdateService):
/// 下载 DMG → 挂载 → 退出后由 helper 原地替换 .app → 清 quarantine → 重启。
@MainActor
enum AppUpdater {
    enum Phase: Equatable {
        case idle
        case downloading(fraction: Double?, detail: String)
        case installing
        case restarting
        case failed(String)
    }

    private static var activeTask: Task<Void, Never>?
    private static var cancelDownload: (() -> Void)?

    /// 开始安装;`onPhase` 在主线程回调进度。无可用 DMG 时返回 false(调用方回退打开 download)。
    @discardableResult
    static func install(_ info: UpdateInfo, onPhase: @escaping (Phase) -> Void) -> Bool {
        guard let url = info.inAppUpdateURL else { return false }
        activeTask?.cancel()
        cancelDownload?()
        let task = Task { @MainActor in
            await downloadAndInstall(version: info.version, url: url, onPhase: onPhase)
        }
        activeTask = task
        return true
    }

    static func cancel() {
        cancelDownload?()
        activeTask?.cancel()
        activeTask = nil
        cancelDownload = nil
    }

    // MARK: - Pipeline

    private static func downloadAndInstall(
        version: String,
        url: URL,
        onPhase: @escaping (Phase) -> Void
    ) async {
        let dmgPath = NSTemporaryDirectory() + "agentdock-update-\(version).dmg"
        let dmgURL = URL(fileURLWithPath: dmgPath)
        onPhase(.downloading(fraction: nil, detail: "connecting…"))

        do {
            try await downloadWithProgress(from: url, to: dmgURL) { written, total in
                if total > 0 {
                    let pct = Double(written) / Double(total)
                    let detail = String(
                        format: "%.1f / %.1f MB · %.0f%%",
                        Double(written) / 1024 / 1024,
                        Double(total) / 1024 / 1024,
                        pct * 100
                    )
                    onPhase(.downloading(fraction: pct, detail: detail))
                } else {
                    let detail = String(format: "%.1f MB…", Double(written) / 1024 / 1024)
                    onPhase(.downloading(fraction: nil, detail: detail))
                }
            }
        } catch is CancellationError {
            onPhase(.idle)
            return
        } catch {
            onPhase(.failed(error.localizedDescription))
            return
        }

        guard !Task.isCancelled else {
            onPhase(.idle)
            return
        }

        onPhase(.installing)

        let mountPoint: String
        do {
            mountPoint = try attachDMG(at: dmgPath)
        } catch {
            onPhase(.failed("mount failed: \(error.localizedDescription)"))
            return
        }

        guard let sourceApp = locateAppBundle(in: mountPoint) else {
            _ = try? detachDMG(mountPoint: mountPoint)
            onPhase(.failed("no .app in installer"))
            return
        }

        let destApp = Bundle.main.bundleURL.path
        spawnInstallHelper(
            ourPID: ProcessInfo.processInfo.processIdentifier,
            sourceApp: sourceApp,
            destApp: destApp,
            mountPoint: mountPoint,
            dmgFile: dmgPath,
            needsAdmin: !FileManager.default.isWritableFile(atPath: destApp)
                && !FileManager.default.isWritableFile(
                    atPath: (destApp as NSString).deletingLastPathComponent)
        )

        onPhase(.restarting)
        try? await Task.sleep(nanoseconds: 600_000_000)
        NSApp.terminate(nil)
    }

    // MARK: - Download

    private static func downloadWithProgress(
        from url: URL,
        to dest: URL,
        onProgress: @escaping (_ written: Int64, _ total: Int64) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let delegate = DownloadProgressDelegate(destURL: dest)
            delegate.onProgress = { written, total in
                Task { @MainActor in onProgress(written, total) }
            }
            delegate.onComplete = { result in
                Task { @MainActor in cancelDownload = nil }
                switch result {
                case .success: cont.resume()
                case .failure(let error): cont.resume(throwing: error)
                }
            }
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 300
            let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            Task { @MainActor in
                cancelDownload = { task.cancel() }
            }
            task.resume()
        }
    }

    // MARK: - DMG

    private static func attachDMG(at path: String) throws -> String {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["attach", "-nobrowse", "-noverify", "-noautoopen", path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "AppUpdater", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "hdiutil attach \(proc.terminationStatus)"])
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: data, encoding: .utf8) ?? ""
        for line in stdout.split(separator: "\n") {
            if let range = line.range(of: "/Volumes/") {
                return String(line[range.lowerBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        throw NSError(domain: "AppUpdater", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "no mount point"])
    }

    private static func detachDMG(mountPoint: String) throws {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        proc.arguments = ["detach", "-force", mountPoint]
        try proc.run()
        proc.waitUntilExit()
    }

    private static func locateAppBundle(in mountPoint: String) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: mountPoint) else {
            return nil
        }
        for name in contents where name.hasSuffix(".app") {
            return (mountPoint as NSString).appendingPathComponent(name)
        }
        return nil
    }

    // MARK: - Helper

    private static func spawnInstallHelper(
        ourPID: Int32,
        sourceApp: String,
        destApp: String,
        mountPoint: String,
        dmgFile: String,
        needsAdmin: Bool
    ) {
        let scriptPath = NSTemporaryDirectory() + "agentdock-update-helper.sh"
        let q = { (s: String) -> String in
            "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }

        let replaceBlock = """
        STAGE="$DEST.update-staging"
        /bin/rm -rf "$STAGE"
        /bin/cp -R "$SRC" "$STAGE"
        /bin/rm -rf "$DEST"
        /bin/mv "$STAGE" "$DEST"
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" >/dev/null 2>&1 || true
        """

        let body: String
        if needsAdmin {
            // 提权替换写进单独脚本,osascript 只负责跑它(避免层层转义)
            let elevatePath = NSTemporaryDirectory() + "agentdock-update-elevate.sh"
            let elevateBody = """
            #!/bin/bash
            set -e
            SRC=\(q(sourceApp))
            DEST=\(q(destApp))
            \(replaceBlock)
            """
            do {
                try elevateBody.write(toFile: elevatePath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: elevatePath)
            } catch {
                NSLog("AppUpdater: write elevate script failed: \(error)")
                return
            }

            body = """
            #!/bin/bash
            set -e
            PID=\(ourPID)
            VOL=\(q(mountPoint))
            DMG=\(q(dmgFile))
            ELEV=\(q(elevatePath))
            DEST=\(q(destApp))

            for _ in $(seq 1 30); do
              if ! /bin/ps -p $PID > /dev/null 2>&1; then break; fi
              sleep 1
            done

            /usr/bin/osascript -e "do shell script \\"$ELEV\\" with administrator privileges"

            /usr/bin/hdiutil detach "$VOL" -force >/dev/null 2>&1 || true
            /bin/rm -f "$DMG"
            /bin/rm -f "$ELEV"
            /usr/bin/open "$DEST"
            /bin/rm -f "$0"
            """
        } else {
            body = """
            #!/bin/bash
            set -e
            PID=\(ourPID)
            SRC=\(q(sourceApp))
            DEST=\(q(destApp))
            VOL=\(q(mountPoint))
            DMG=\(q(dmgFile))

            for _ in $(seq 1 30); do
              if ! /bin/ps -p $PID > /dev/null 2>&1; then break; fi
              sleep 1
            done

            \(replaceBlock)

            /usr/bin/hdiutil detach "$VOL" -force >/dev/null 2>&1 || true
            /bin/rm -f "$DMG"
            /usr/bin/open "$DEST"
            /bin/rm -f "$0"
            """
        }

        do {
            try body.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        } catch {
            NSLog("AppUpdater: write helper failed: \(error)")
            return
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-c", "/usr/bin/nohup \(q(scriptPath)) >/dev/null 2>&1 &"]
        try? proc.run()
    }
}

// MARK: - Download delegate

private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destURL: URL
    var onProgress: ((_ written: Int64, _ total: Int64) -> Void)?
    var onComplete: ((Result<Void, Error>) -> Void)?
    private var completed = false

    init(destURL: URL) {
        self.destURL = destURL
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress?(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        do {
            try? FileManager.default.removeItem(at: destURL)
            try FileManager.default.moveItem(at: location, to: destURL)
            completed = true
            onComplete?(.success(()))
        } catch {
            completed = true
            onComplete?(.failure(error))
        }
        session.finishTasksAndInvalidate()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !completed else { return }
        if let error {
            if (error as NSError).code == NSURLErrorCancelled {
                onComplete?(.failure(CancellationError()))
            } else {
                onComplete?(.failure(error))
            }
        }
        session.finishTasksAndInvalidate()
    }
}
