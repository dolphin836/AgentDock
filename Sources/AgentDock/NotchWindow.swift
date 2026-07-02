import AppKit
import SwiftUI
import AgentDockCore

/// 悬浮在刘海周围的无边框面板。收起态只显示状态点条,悬停/告警时展开。
@MainActor
final class NotchWindow {
    private let panel: NSPanel
    private let store: SessionStore

    init(store: SessionStore, settings: AppSettings) {
        self.store = store
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let root = NotchRootView(store: store, settings: settings)
        panel.contentView = NSHostingView(rootView: root)
    }

    func show() {
        position()
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.position() }
        }
    }

    private func position() {
        // 始终挂在主屏(系统设置里带菜单栏的那块,screens.first);
        // 主屏没有物理刘海时,三段式布局的中段充当"虚拟刘海"
        guard let screen = NSScreen.screens.first else { return }
        let width: CGFloat = 720
        let height: CGFloat = 420  // 面板最大展开高度,内容不满时其余区域点击穿透由 SwiftUI hit-test 决定
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
