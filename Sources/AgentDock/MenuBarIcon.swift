import AppKit

/// 菜单栏图标:实心机器人头 + 镂空/眨眼圆眼 + 天线 + 双耳。
/// - 刘海模式:模板图(系统自动适配深浅色)
/// - 菜单栏模式:按状态着色 + 运行中眨眼
@MainActor
enum MenuBarIcon {
    /// 状态着色(非模板);nil = 模板黑,由系统着色
    enum Tint {
        case template
        case phosphor
        case cyan
        case amber
        case yellow
        case idle
    }

    static func robot(size: CGFloat = 18, tint: Tint = .template, eyesOpen: Bool = true) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let s = size / 18.0

            let body = NSBezierPath()
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 3.2 * s, y: 2.6 * s, width: 11.6 * s, height: 10.6 * s),
                xRadius: 2.8 * s, yRadius: 2.8 * s))
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 8.1 * s, y: 12.6 * s, width: 1.8 * s, height: 3.2 * s),
                xRadius: 0.9 * s, yRadius: 0.9 * s))
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 1.0 * s, y: 5.6 * s, width: 1.7 * s, height: 4.6 * s),
                xRadius: 0.85 * s, yRadius: 0.85 * s))
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 15.3 * s, y: 5.6 * s, width: 1.7 * s, height: 4.6 * s),
                xRadius: 0.85 * s, yRadius: 0.85 * s))

            fillColor(for: tint).setFill()
            body.fill()

            // 眼睛:模板模式镂空;磷光绿/黄用白眼;其余着色模式用深色眼
            if tint == .template {
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                eyePaths(size: size, open: eyesOpen).fill()
            } else {
                eyeColor(for: tint).setFill()
                eyePaths(size: size, open: eyesOpen).fill()
            }
            return true
        }
        image.isTemplate = (tint == .template)
        return image
    }

    private static func fillColor(for tint: Tint) -> NSColor {
        switch tint {
        case .template:
            return .black
        case .phosphor:
            // 菜单栏运行中:低饱和薄荷绿,菜单栏小尺寸下不刺眼
            return NSColor(red: 0.45, green: 0.68, blue: 0.52, alpha: 1)
        case .cyan:
            return NSColor(red: 0.38, green: 0.91, blue: 0.96, alpha: 1)
        case .amber:
            return NSColor(red: 1.0, green: 0.73, blue: 0.33, alpha: 1)
        case .yellow:
            // 菜单栏待审批:低饱和暖黄,小尺寸下不刺眼
            return NSColor(red: 0.82, green: 0.72, blue: 0.38, alpha: 1)
        case .idle:
            return NSColor(white: 0.72, alpha: 1)
        }
    }

    private static func eyeColor(for tint: Tint) -> NSColor {
        switch tint {
        case .phosphor, .yellow:
            return .white
        default:
            return NSColor.black.withAlphaComponent(0.85)
        }
    }

    private static func eyePaths(size: CGFloat, open: Bool) -> NSBezierPath {
        let s = size / 18.0
        let paths = NSBezierPath()
        if open {
            paths.append(NSBezierPath(ovalIn: NSRect(x: 5.0 * s, y: 6.6 * s, width: 3.2 * s, height: 3.2 * s)))
            paths.append(NSBezierPath(ovalIn: NSRect(x: 9.8 * s, y: 6.6 * s, width: 3.2 * s, height: 3.2 * s)))
        } else {
            // 眨眼:压成细缝
            paths.append(NSBezierPath(
                roundedRect: NSRect(x: 5.0 * s, y: 7.8 * s, width: 3.2 * s, height: 0.9 * s),
                xRadius: 0.45 * s, yRadius: 0.45 * s))
            paths.append(NSBezierPath(
                roundedRect: NSRect(x: 9.8 * s, y: 7.8 * s, width: 3.2 * s, height: 0.9 * s),
                xRadius: 0.45 * s, yRadius: 0.45 * s))
        }
        return paths
    }
}
