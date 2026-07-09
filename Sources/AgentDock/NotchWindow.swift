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
    /// 菜单栏模式下箭头相对面板内容左缘的 x(指向状态栏图标中心)
    var menuBarCaretX: CGFloat = NotchLayout.totalWidth / 2
}

/// 无边框面板默认不能成为 key window;快捷键录制需要接收键盘事件
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// 悬浮面板。刘海模式贴屏幕顶端居中;菜单栏模式挂在状态栏图标下方。
@MainActor
final class NotchWindow {
    private let panel: NSPanel
    private let store: SessionStore
    let hoverState = HoverState()
    private var monitors: [Any] = []
    /// 悬停展开的回调(用于按需刷新限额等「用户正在看」才需要新鲜的数据)
    var onHoverBegan: (() -> Void)?
    /// 菜单栏模式下用于定位的状态栏按钮(由 AppDelegate 注入)
    weak var statusButton: NSStatusBarButton?

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
        applyVisibility()
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

    /// 设置里切换了展示屏幕 / 挂靠位置:立即重挂
    func reposition() {
        position()
        applyVisibility()
    }

    /// 会话/审批变化时调用(菜单栏模式需在「等你处理」时自动弹出)
    func refreshVisibility() {
        position()
        applyVisibility()
    }

    /// 快捷键录制期间需要键盘焦点
    func makeKeyForTyping() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKey()
    }

    /// 菜单栏模式:左键切换固定展开
    func togglePinned() {
        hoverState.pinnedOpen.toggle()
        if hoverState.pinnedOpen {
            onHoverBegan?()
            position()
            applyVisibility()
        } else if !hoverState.hovering {
            applyVisibility()
        }
    }

    private var isExpanded: Bool {
        hoverState.hovering || hoverState.pinnedOpen || hasWaitingSessions
    }

    private var hasWaitingSessions: Bool {
        store.sessions.contains { session in
            if session.state == .waitingApproval { return true }
            return session.state == .waitingInput
                && session.recentEvents.last?.tool.map(isUserFacingTool) == true
        }
    }

    private func updateHover() {
        let placement = AppSettings.shared.panelPlacement
        let point = NSEvent.mouseLocation
        let inside: Bool
        switch placement {
        case .notch:
            inside = notchHitRect()?.contains(point) ?? false
        case .menuBar:
            inside = menuBarHitRect()?.contains(point) ?? false
        }
        if hoverState.hovering != inside {
            hoverState.hovering = inside
            if inside { onHoverBegan?() }
            position()
            applyVisibility()
        } else if placement == .menuBar, isExpanded {
            // 图标可能随菜单栏布局漂移,展开时持续对齐
            position()
        }
    }

    /// 刘海模式:内容贴屏幕顶端水平居中
    private func notchHitRect() -> NSRect? {
        guard let screen = AppSettings.shared.targetScreen else { return nil }
        let size = hoverState.contentSize
        guard size.width > 1, size.height > 1 else { return nil }
        return NSRect(x: screen.frame.midX - size.width / 2,
                      y: screen.frame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    /// 菜单栏模式:状态栏按钮 ∪ 已展开面板内容
    private func menuBarHitRect() -> NSRect? {
        var rects: [NSRect] = []
        if let button = statusButton, let win = button.window {
            let b = button.convert(button.bounds, to: nil)
            rects.append(win.convertToScreen(b).insetBy(dx: -2, dy: -2))
        }
        if isExpanded, let content = menuBarContentRect() {
            rects.append(content)
        }
        guard let first = rects.first else { return nil }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }

    private func menuBarContentRect() -> NSRect? {
        let size = hoverState.contentSize
        guard size.width > 1, size.height > 1 else { return nil }
        // 面板窗口左上角对齐内容;内容从窗口顶部向下排
        let frame = panel.frame
        return NSRect(x: frame.minX + (frame.width - size.width) / 2,
                      y: frame.maxY - size.height,
                      width: size.width, height: size.height)
    }

    private func position() {
        switch AppSettings.shared.panelPlacement {
        case .notch:
            positionForNotch()
        case .menuBar:
            positionForMenuBar()
        }
    }

    private func positionForNotch() {
        guard let screen = AppSettings.shared.targetScreen else { return }
        let width: CGFloat = 900
        let height: CGFloat = 600
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }

    private func positionForMenuBar() {
        let width: CGFloat = 900
        let height: CGFloat = 600
        let panelW = NotchLayout.totalWidth
        // 箭头尖与菜单栏图标之间留一点空隙
        let gapBelowIcon: CGFloat = 2
        guard let button = statusButton, let win = button.window else {
            // 图标尚未就绪:先藏到屏外
            panel.setFrame(NSRect(x: -4000, y: -4000, width: width, height: height), display: false)
            return
        }
        let btnScreen = win.convertToScreen(button.convert(button.bounds, to: nil))
        // 面板水平以图标中心对齐并夹在屏幕内;箭头单独指向图标
        let screen = win.screen ?? NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen?.frame ?? .zero
        var x = btnScreen.midX - panelW / 2
        let minX = screenFrame.minX + 8
        let maxX = screenFrame.maxX - panelW - 8
        if maxX >= minX { x = min(max(x, minX), maxX) }
        // 窗口顶边 = 图标底边 - gap(箭头尖贴在顶边)
        let y = btnScreen.minY - gapBelowIcon - height
        let frameX = x - (width - panelW) / 2
        // 箭头 x:相对面板内容左缘,夹在圆角内侧以免画出卡片
        let rawCaret = btnScreen.midX - x
        hoverState.menuBarCaretX = min(max(rawCaret, 18), panelW - 18)
        panel.setFrame(NSRect(x: frameX, y: y, width: width, height: height), display: true)
    }

    /// 刘海模式始终显示(收起条);菜单栏模式仅展开时显示面板
    private func applyVisibility() {
        switch AppSettings.shared.panelPlacement {
        case .notch:
            panel.orderFrontRegardless()
        case .menuBar:
            if isExpanded || hoverState.pinnedOpen || hoverState.hovering || hasWaitingSessions {
                panel.orderFrontRegardless()
            } else {
                panel.orderOut(nil)
            }
        }
    }
}
