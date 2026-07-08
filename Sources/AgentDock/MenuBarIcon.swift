import AppKit

/// 菜单栏图标:实心机器人头 + 镂空圆眼 + 天线 + 双耳(矢量绘制)。
/// 18pt 模板图——macOS 菜单栏建议尺寸,系统自动适配深浅色外观。
@MainActor
enum MenuBarIcon {
    static func robot(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let s = size / 18.0  // 以 18pt 网格设计,可整体缩放

            let body = NSBezierPath()
            // 头:宽圆角方形
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 3.2 * s, y: 2.6 * s, width: 11.6 * s, height: 10.6 * s),
                xRadius: 2.8 * s, yRadius: 2.8 * s))
            // 天线:顶部居中圆头短柱
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 8.1 * s, y: 12.6 * s, width: 1.8 * s, height: 3.2 * s),
                xRadius: 0.9 * s, yRadius: 0.9 * s))
            // 双耳:两侧竖圆角条
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 1.0 * s, y: 5.6 * s, width: 1.7 * s, height: 4.6 * s),
                xRadius: 0.85 * s, yRadius: 0.85 * s))
            body.append(NSBezierPath(
                roundedRect: NSRect(x: 15.3 * s, y: 5.6 * s, width: 1.7 * s, height: 4.6 * s),
                xRadius: 0.85 * s, yRadius: 0.85 * s))
            NSColor.black.setFill()
            body.fill()

            // 眼睛:从实心头上镂空(模板图里透明即"白")
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            let eyes = NSBezierPath()
            eyes.append(NSBezierPath(ovalIn: NSRect(x: 5.0 * s, y: 6.6 * s, width: 3.2 * s, height: 3.2 * s)))
            eyes.append(NSBezierPath(ovalIn: NSRect(x: 9.8 * s, y: 6.6 * s, width: 3.2 * s, height: 3.2 * s)))
            eyes.fill()
            return true
        }
        image.isTemplate = true  // 模板模式:菜单栏深浅色自动反转
        return image
    }
}
