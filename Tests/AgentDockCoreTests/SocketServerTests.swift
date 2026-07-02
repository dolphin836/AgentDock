import Testing
import Foundation
import Darwin
@testable import AgentDockCore

private func connectAndSend(_ path: String, _ text: String) {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    withUnsafeMutableBytes(of: &addr.sun_path) { buf in
        path.utf8CString.withUnsafeBytes { src in
            buf.copyMemory(from: UnsafeRawBufferPointer(rebasing: src.prefix(buf.count - 1)))
        }
    }
    let len = socklen_t(MemoryLayout<sockaddr_un>.size)
    _ = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, len) }
    }
    _ = text.withCString { write(fd, $0, strlen($0)) }
    close(fd)
}

@Suite struct SocketServerTests {
    @Test func receivesLinesFromClients() async throws {
        let path = NSTemporaryDirectory() + "agentdock-test-\(UUID().uuidString.prefix(8)).sock"
        let received = Mutex<[String]>([])
        let server = SocketServer(path: path) { data in
            received.withLock { $0.append(String(decoding: data, as: UTF8.self)) }
        }
        try server.start()
        defer { server.stop() }

        connectAndSend(path, "hello\nworld\n")
        connectAndSend(path, "tail-no-newline")

        try await Task.sleep(for: .milliseconds(300))
        let lines = received.withLock { $0 }.sorted()
        #expect(lines == ["hello", "tail-no-newline", "world"])
    }
}

/// 简易线程安全容器(测试用)
final class Mutex<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()
    init(_ value: T) { self.value = value }
    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock(); defer { lock.unlock() }
        return body(&value)
    }
}
