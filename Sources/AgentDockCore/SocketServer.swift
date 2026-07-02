import Foundation
import Darwin

/// Unix domain socket server,按 \n 分帧,每行回调一次。
/// 单个连接出错只断开该连接,不影响 server。
public final class SocketServer: @unchecked Sendable {
    private let path: String
    private let onLine: @Sendable (Data) -> Void
    private let queue = DispatchQueue(label: "agentdock.socket")
    private var listenFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var connections: [Int32: (source: DispatchSourceRead, buffer: Data)] = [:]

    public init(path: String, onLine: @escaping @Sendable (Data) -> Void) {
        self.path = path
        self.onLine = onLine
    }

    public func start() throws {
        try FileManager.default.createDirectory(
            atPath: (path as NSString).deletingLastPathComponent,
            withIntermediateDirectories: true)
        unlink(path)

        listenFD = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listenFD >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            path.utf8CString.withUnsafeBytes { src in
                buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(buf.count - 1)))
            }
        }
        let len = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listenFD, $0, len) }
        }
        guard bindResult == 0, listen(listenFD, 16) == 0 else {
            close(listenFD)
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }

        let source = DispatchSource.makeReadSource(fileDescriptor: listenFD, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptConnection() }
        source.resume()
        acceptSource = source
    }

    public func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            for (fd, conn) in connections { conn.source.cancel(); close(fd) }
            connections.removeAll()
            if listenFD >= 0 { close(listenFD); listenFD = -1 }
            unlink(path)
        }
    }

    private func acceptConnection() {
        let fd = accept(listenFD, nil, nil)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.readFrom(fd: fd) }
        connections[fd] = (source, Data())
        source.resume()
    }

    private func readFrom(fd: Int32) {
        var chunk = [UInt8](repeating: 0, count: 4096)
        let n = read(fd, &chunk, chunk.count)
        if n <= 0 {
            closeConnection(fd: fd)
            return
        }
        connections[fd]?.buffer.append(contentsOf: chunk[0..<n])
        drainLines(fd: fd)
    }

    private func drainLines(fd: Int32) {
        guard var buffer = connections[fd]?.buffer else { return }
        while let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<nl]
            buffer = buffer[buffer.index(after: nl)...]
            if !line.isEmpty { onLine(Data(line)) }
        }
        connections[fd]?.buffer = Data(buffer)
    }

    private func closeConnection(fd: Int32) {
        // 连接关闭时缓冲里可能还有最后一行(无换行结尾)
        if let remaining = connections[fd]?.buffer, !remaining.isEmpty {
            onLine(remaining)
        }
        connections[fd]?.source.cancel()
        connections[fd] = nil
        close(fd)
    }
}
