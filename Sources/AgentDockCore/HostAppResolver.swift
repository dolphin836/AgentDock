import Foundation
import Darwin

/// 由进程 pid 沿父进程链向上探测宿主 .app 路径,与 agentdock-emit 脚本的逻辑一致:
/// 取链上「最顶层」的 .app——CLI 自身可能打包成内部 bundle(如 Claude 桌面端内的
/// claude.app),真正的 GUI 宿主(Cursor/iTerm/Claude Desktop...)在链条更上方。
/// 用于给磁盘回填、没经过发射脚本的会话补齐 appPath(点击跳转与图标都依赖它)。
public enum HostAppResolver {

    public static func appPath(forPid pid: Int32, maxDepth: Int = 12) -> String? {
        var current = pid
        var topmost: String?
        for _ in 0..<maxDepth {
            guard current > 1 else { break }
            if let exe = executablePath(of: current),
               let range = exe.range(of: ".app/") {
                topmost = String(exe[..<range.lowerBound]) + ".app"
            }
            guard let parent = parentPid(of: current), parent != current else { break }
            current = parent
        }
        return topmost
    }

    /// 扫描运行中的进程,找可执行名匹配的进程,返回 cwd → 宿主 App(可能为空串)。
    /// codex 会话的注册信息里没有 pid,只能反过来「按 cwd 找还活着的 codex 进程」:
    /// key 集合本身就是存活判据,value 用于补齐点击跳转/图标的宿主。
    /// 前缀匹配:codex CLI 的真实可执行名带平台后缀(codex-aarch64-apple-darwin)。
    public static func hostAppsByCwd(executablePrefix: String) -> [String: String] {
        var pids = [Int32](repeating: 0, count: 8192)
        let count = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.stride))
        guard count > 0 else { return [:] }
        let prefix = executablePrefix.lowercased()
        var result: [String: String] = [:]
        for pid in pids.prefix(Int(count)) where pid > 0 {
            guard let exe = executablePath(of: pid),
                  (exe as NSString).lastPathComponent.lowercased().hasPrefix(prefix),
                  let cwd = currentWorkingDirectory(of: pid)
            else { continue }
            let app = appPath(forPid: pid) ?? result[cwd] ?? ""
            result[cwd] = app
        }
        return result
    }

    static func currentWorkingDirectory(of pid: Int32) -> String? {
        var vpi = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.stride)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &vpi, size) > 0 else { return nil }
        return withUnsafeBytes(of: &vpi.pvi_cdir.vip_path) { raw in
            raw.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) }
        }
    }

    static func executablePath(of pid: Int32) -> String? {
        var buf = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 else { return nil }
        return String(cString: buf)
    }

    static func parentPid(of pid: Int32) -> Int32? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }
}
