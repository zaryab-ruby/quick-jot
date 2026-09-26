// Renders the QuickJot app icon and packs it into an .icns file.
// Usage: swift scripts/make-icon.swift Resources/AppIcon.icns
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Resources/AppIcon.icns")

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    // macOS icon grid: 824pt body centred on a 1024pt canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 28
    shadow.set()
    NSColor(white: 0.25, alpha: 1).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [NSColor(white: 0.44, alpha: 1), NSColor(white: 0.24, alpha: 1)])!
        .draw(in: bodyPath, angle: -90)
    NSColor.white.withAlphaComponent(0.14).setStroke()
    bodyPath.lineWidth = 4
    bodyPath.stroke()

    // Tab pill, like the selected scratchpad tab.
    let accent = NSColor(srgbRed: 0.24, green: 0.51, blue: 0.96, alpha: 1)
    accent.setFill()
    NSBezierPath(roundedRect: NSRect(x: 196, y: 690, width: 300, height: 92), xRadius: 26, yRadius: 26).fill()

    // Text lines.
    NSColor.white.withAlphaComponent(0.9).setFill()
    for (index, width) in [632.0, 520, 580, 380].enumerated() {
        let y = 560 - CGFloat(index) * 112
        NSBezierPath(roundedRect: NSRect(x: 196, y: y, width: width, height: 44), xRadius: 22, yRadius: 22).fill()
    }

    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(pixels: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(pixels: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(output.path)")
