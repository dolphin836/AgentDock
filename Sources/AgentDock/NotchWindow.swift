import AppKit
import SwiftUI
import AgentDockCore

/// 悬停状态:由窗口层的全局鼠标监听驱动,视图层只读
/// 展开面板的页面
enum PanelTab {
    case sessions, usage, settings
}

@MainActor
@Observable
final class HoverState {
    var hovering = false
    /// 快捷键固定展开:与悬停互相独立,再按一次取消
    var pinnedOpen = false
    /// 展开面板当前页
    var activeTab: PanelTab = .sessions
    /// 当前实际渲染的内容尺寸(由视图上报),用于精确判定悬停区域
    var contentSize: CGSize = .zero
}

/// 无边框面板默认不能成为 key window;快捷键录制需要接收键盘事件
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 悬浮在刘海周围的无边框面板。收起态只显示状态条,悬停/告警时展开。
@MainActor
final class NotchWindow {
    private let panel: NSPanel
    private let store: SessionStore
    let hoverState = HoverState()
    private var monitors: [Any] = []
    /// 悬停展开的回调(用于按需刷新限额等「用户正在看」才需要新鲜的数据)
    var onHoverBegan: (() -> Void)?

    init(store: SessionStore, settings: AppSettings) {
        self.store = store
        panel = KeyablePanel(
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

        let root = NotchRootView(store: store, settings: settings, hoverState: hoverState)
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
        startMouseTracking()
    }

    /// 全局 + 本地鼠标移动监听:仅当指针位于"当前实际内容矩形"内才算悬停,
    /// 避免 SwiftUI onHover 在展开/收起动画期间把下方空白区也算进去。
    private func startMouseTracking() {
        let handler: @Sendable (NSEvent) -> Void = { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: handler) {
            monitors.append(m)
        }
        monitors.append(NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { event in
            Task { @MainActor [weak self] in self?.updateHover() }
            return event
        } as Any)
    }

    /// 设置里切换了展示屏幕:立即重挂
    func reposition() {
        position()
    }

    /// 快捷键录制期间需要键盘焦点
    func makeKeyForTyping() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
    }

    private func updateHover() {
        guard let screen = AppSettings.shared.targetScreen else { return }
        let size = hoverState.contentSize
        guard size.width > 1, size.height > 1 else {
            hoverState.hovering = false
            return
        }
        // 内容贴屏幕顶端水平居中(坐标系原点在左下)
        let rect = NSRect(x: screen.frame.midX - size.width / 2,
                          y: screen.frame.maxY - size.height,
                          width: size.width, height: size.height)
        let point = NSEvent.mouseLocation
        if hoverState.hovering != rect.contains(point) {
            hoverState.hovering = rect.contains(point)
            if hoverState.hovering { onHoverBegan?() }
        }
    }

    private func position() {
        // 挂靠屏幕跟随设置(默认主屏);无物理刘海时中段充当"虚拟刘海"
        guard let screen = AppSettings.shared.targetScreen else { return }
        let width: CGFloat = 900
        let height: CGFloat = 600  // 面板最大展开高度,空白区不影响悬停判定
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
