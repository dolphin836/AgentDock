import AppKit

// 渲染 App 图标(Finder/DMG 展示用):深色圆角方底 + 白色机器人(与菜单栏图标同源)
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // 背景:近黑圆角方(macOS 图标网格:1024 中留边距 ~100)
    let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                          xRadius: 185, yRadius: 185)
    NSColor(calibratedRed: 0.045, green: 0.045, blue: 0.055, alpha: 1).setFill()
    bg.fill()

    // 机器人:18pt 设计网格放大,白色,居中
    let s: CGFloat = 824 * 0.72 / 18
    let ox: CGFloat = 100 + (824 - 18 * s) / 2
    let oy: CGFloat = 100 + (824 - 18 * s) / 2 - 20
    let body = NSBezierPath()
    body.append(NSBezierPath(roundedRect: NSRect(x: ox + 3.2*s, y: oy + 2.6*s, width: 11.6*s, height: 10.6*s), xRadius: 2.8*s, yRadius: 2.8*s))
    body.append(NSBezierPath(roundedRect: NSRect(x: ox + 8.1*s, y: oy + 12.6*s, width: 1.8*s, height: 3.2*s), xRadius: 0.9*s, yRadius: 0.9*s))
    body.append(NSBezierPath(roundedRect: NSRect(x: ox + 1.0*s, y: oy + 5.6*s, width: 1.7*s, height: 4.6*s), xRadius: 0.85*s, yRadius: 0.85*s))
    body.append(NSBezierPath(roundedRect: NSRect(x: ox + 15.3*s, y: oy + 5.6*s, width: 1.7*s, height: 4.6*s), xRadius: 0.85*s, yRadius: 0.85*s))
    NSColor.white.setFill()
    body.fill()
    // 眼睛用底色填充(镂空会穿透背景层)
    let eyes = NSBezierPath()
    eyes.append(NSBezierPath(ovalIn: NSRect(x: ox + 5.0*s, y: oy + 6.6*s, width: 3.2*s, height: 3.2*s)))
    eyes.append(NSBezierPath(ovalIn: NSRect(x: ox + 9.8*s, y: oy + 6.6*s, width: 3.2*s, height: 3.2*s)))
    NSColor(calibratedRed: 0.045, green: 0.045, blue: 0.055, alpha: 1).setFill()
    eyes.fill()
    return true
}
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: "assets/AppIcon.png"))
print("assets/AppIcon.png written")
