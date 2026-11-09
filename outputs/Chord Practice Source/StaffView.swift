import AppKit
import CoreText
import SwiftUI

/// Drawn locally at the window's resolution; no image assets or network fonts are needed.
struct StaffNotationView: NSViewRepresentable {
    let notes: [StaffNote]
    let clef: StaffClef

    func makeNSView(context: Context) -> StaffCanvas { StaffCanvas() }
    func updateNSView(_ view: StaffCanvas, context: Context) {
        view.notes = notes
        view.clef = clef
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel("\(clef.label) clef: " + clef.writtenNotes(notes).map(\.spokenName).joined(separator: ", "))
        view.needsDisplay = true
    }
}

final class StaffCanvas: NSView {
    var notes: [StaffNote] = []
    var clef: StaffClef = .treble
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        StaffDrawing.draw(notes: notes, clef: clef, in: bounds)
    }
}

enum StaffDrawing {
    private static let color = NSColor(calibratedRed: 0.12, green: 0.20, blue: 0.17, alpha: 1)

    /// Core Text supplies the actual music-glyph outline, avoiding font-dependent baselines.
    private static func glyphPath(_ symbol: String) -> CGPath? {
        let font = NSFont(name: "Apple Symbols", size: 100) ?? NSFont.systemFont(ofSize: 100)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: symbol, attributes: [.font: font]))
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            for index in 0..<count {
                if let outline = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) {
                    path.addPath(outline, transform: CGAffineTransform(translationX: positions[index].x, y: positions[index].y))
                }
            }
        }
        return path.isEmpty ? nil : path
    }

    private static let glyphs: [String: CGPath] = {
        var result: [String: CGPath] = [:]
        for symbol in ["𝄞", "𝄢", "♭", "♯", "𝄫", "𝄪"] {
            result[symbol] = glyphPath(symbol)
        }
        return result
    }()

    private static func drawGlyph(_ symbol: String, x: CGFloat, top: CGFloat, height: CGFloat,
                                  alignRight: Bool = false, context: CGContext) {
        guard let path = glyphs[symbol] else { return }
        let box = path.boundingBoxOfPath
        guard box.height > 0 else { return }
        let scale = height / box.height
        context.saveGState()
        context.translateBy(x: alignRight ? x - box.width * scale : x, y: top + height)
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    /// The drawing uses a flipped coordinate system (origin at the upper left).
    static func draw(notes original: [StaffNote], clef: StaffClef, in bounds: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext, !original.isEmpty,
              bounds.width > 0, bounds.height > 0 else { return }
        let notes = clef.writtenNotes(original)
        let gap = min(24, max(12, bounds.width / 20), bounds.height / 9.6)
        let width = min(bounds.width - 16, 480)
        let left = bounds.midX - width / 2
        let right = left + width
        let bottom = bounds.midY + gap * 2
        let top = bottom - gap * 4
        let positions = notes.map { $0.diatonicPosition - clef.bottomPosition }
        let ys = positions.map { bottom - CGFloat($0) * gap / 2 }
        let noteX = left + width * 0.60
        let headWidth = gap * 1.30
        let headHeight = gap * 0.86
        let downStem = (positions.min()! + positions.max()!) >= 8
        var offsets = [CGFloat](repeating: 0, count: notes.count)
        let order = downStem ? Array(notes.indices.reversed()) : Array(notes.indices)
        var previous: Int?
        for index in order {
            if let prior = previous, abs(positions[index] - positions[prior]) == 1, offsets[prior] == 0 {
                offsets[index] = downStem ? -(headWidth - 1) : headWidth - 1
            }
            previous = index
        }

        context.saveGState()
        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(max(1, gap * 0.045))
        for line in 0..<5 {
            let y = bottom - CGFloat(line) * gap
            context.move(to: CGPoint(x: left, y: y))
            context.addLine(to: CGPoint(x: right, y: y))
        }
        context.strokePath()

        drawGlyph(clef.symbol, x: left + gap * 0.45,
                  top: clef == .treble ? top - gap * 1.55 : top - gap * 0.05,
                  height: gap * (clef == .treble ? 7 : 3.5), context: context)

        context.setStrokeColor(color.cgColor)
        context.setLineWidth(max(1.2, gap * 0.06))
        for index in notes.indices {
            var ledgers: [Int] = []
            if positions[index] <= -2 { ledgers = Array(stride(from: -2, through: positions[index], by: -2)) }
            if positions[index] >= 10 { ledgers = Array(stride(from: 10, through: positions[index], by: 2)) }
            for ledger in ledgers {
                let y = bottom - CGFloat(ledger) * gap / 2
                let x = noteX + offsets[index]
                context.move(to: CGPoint(x: x - headWidth * 0.78, y: y))
                context.addLine(to: CGPoint(x: x + headWidth * 0.78, y: y))
            }
        }
        context.strokePath()

        // Accidentals in neighboring spaces get separate columns, so they never collide.
        var columns: [[CGFloat]] = []
        var columnWidths: [CGFloat] = []
        var accidentals: [(column: Int, symbol: String, top: CGFloat, height: CGFloat)] = []
        let leftmostHead = noteX + (offsets.min() ?? 0) - headWidth / 2
        for index in notes.indices.reversed() where notes[index].accidental != 0 {
            let y = ys[index]
            let column = columns.firstIndex { $0.allSatisfy { abs($0 - y) >= gap * 3 } } ?? columns.count
            if column == columns.count { columns.append([]); columnWidths.append(0) }
            columns[column].append(y)
            let alteration = notes[index].accidental
            let symbol = alteration == -2 ? "𝄫" : alteration == -1 ? "♭" : alteration == 1 ? "♯" : "𝄪"
            let height = gap * (alteration == 2 ? 1.05 : 2.35)
            let glyphTop = y - gap * (alteration < 0 ? 1.75 : alteration == 2 ? 0.525 : 1.175)
            if let box = glyphs[symbol]?.boundingBoxOfPath, box.height > 0 {
                columnWidths[column] = max(columnWidths[column], box.width / box.height * height)
            }
            accidentals.append((column, symbol, glyphTop, height))
        }
        var columnRightEdges: [CGFloat] = []
        var edge = leftmostHead - gap * 0.55
        for width in columnWidths {
            columnRightEdges.append(edge)
            edge -= width + gap * 0.35
        }
        for accidental in accidentals {
            drawGlyph(accidental.symbol, x: columnRightEdges[accidental.column], top: accidental.top,
                      height: accidental.height, alignRight: true, context: context)
        }

        context.setLineWidth(max(1.5, gap * 0.075))
        let stemX = noteX + (downStem ? -headWidth / 2 + 1 : headWidth / 2 - 1)
        context.move(to: CGPoint(x: stemX, y: downStem ? ys.min()! : ys.max()!))
        context.addLine(to: CGPoint(x: stemX, y: downStem ? ys.max()! + gap * 3.15 : ys.min()! - gap * 3.15))
        context.strokePath()
        for index in notes.indices {
            context.saveGState()
            context.translateBy(x: noteX + offsets[index], y: ys[index])
            context.rotate(by: -.pi / 9)
            context.fillEllipse(in: CGRect(x: -headWidth / 2, y: -headHeight / 2, width: headWidth, height: headHeight))
            context.restoreGState()
        }
        context.restoreGState()
    }
}
