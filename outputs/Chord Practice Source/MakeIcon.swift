import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(calibratedRed: 0.15, green: 0.34, blue: 0.26, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 200, yRadius: 200).fill()
let white = NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.93, alpha: 1)
("C" as NSString).draw(at: NSPoint(x: 190, y: 170), withAttributes: [.font: NSFont.systemFont(ofSize: 610, weight: .regular), .foregroundColor: white])
("Δ7" as NSString).draw(at: NSPoint(x: 610, y: 280), withAttributes: [.font: NSFont.systemFont(ofSize: 145, weight: .medium), .foregroundColor: NSColor(calibratedRed: 0.81, green: 0.9, blue: 0.59, alpha: 1)])
image.unlockFocus()
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}

// ICNS stores PNG representations with a four-character size tag.
func uint32Data(_ value: Int) -> Data {
    var number = UInt32(value).bigEndian
    return withUnsafeBytes(of: &number) { Data($0) }
}
var chunks = Data()
let representations = [
    ("icp4", "icon_16x16.png"), ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"), ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"), ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png"), ("ic11", "icon_16x16@2x.png"),
    ("ic12", "icon_32x32@2x.png"), ("ic13", "icon_128x128@2x.png"),
    ("ic14", "icon_256x256@2x.png")
]
for (tag, file) in representations {
    let png = try Data(contentsOf: URL(fileURLWithPath: destination).appendingPathComponent(file))
    chunks.append(Data(tag.utf8))
    chunks.append(uint32Data(png.count + 8))
    chunks.append(png)
}
var icon = Data("icns".utf8)
icon.append(uint32Data(chunks.count + 8))
icon.append(chunks)
try icon.write(to: URL(fileURLWithPath: destination).deletingLastPathComponent().appendingPathComponent("AppIcon.icns"))
