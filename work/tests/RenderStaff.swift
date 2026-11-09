import AppKit

@main struct RenderStaff {
    static func main() throws {
        let examples: [(String, StaffClef)] = [
            ("CmMaj7", .treble), ("C7b9", .treble), ("F#mMaj7", .treble), ("B7b9", .treble),
            ("Cb7b9", .treble), ("Bbm7b5", .treble), ("CmMaj7", .bass), ("C7b9", .bass),
            ("F#7b9", .bass), ("Bb7b9", .bass), ("D#maj7", .treble), ("Gbsus4", .bass)
        ]
        let width = 1200, height = 1680
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
        let context = graphics.cgContext
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        for (index, example) in examples.enumerated() {
            context.saveGState()
            context.translateBy(x: CGFloat(index % 2) * 600, y: CGFloat(index / 2) * 280)
            ("\(example.0) · \(example.1.label)" as NSString).draw(at: NSPoint(x: 40, y: 12), withAttributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .medium), .foregroundColor: NSColor.black
            ])
            StaffDrawing.draw(notes: Chord(literal: example.0).staffNotes!, clef: example.1,
                              in: NSRect(x: 20, y: 30, width: 560, height: 195))
            (Chord(literal: example.0).formula! as NSString).draw(at: NSPoint(x: 230, y: 245), withAttributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 17, weight: .medium), .foregroundColor: NSColor.darkGray
            ])
            context.restoreGState()
        }
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Rendered twelve notation examples with chord formulas")
    }
}
