import SwiftUI

private enum FifthsTheme {
    static let ink = Color(red: 0.12, green: 0.20, blue: 0.17)
    static let forest = Color(red: 0.15, green: 0.34, blue: 0.26)
    static let paper = Color(red: 0.96, green: 0.96, blue: 0.93)
    static let muted = Color(red: 0.43, green: 0.48, blue: 0.44)
}

struct CircleOfFifthsView: View {
    @Binding var selectedIndex: Int
    @Binding var preferFlats: Bool
    @Binding var selectedMode: ScaleMode
    private var key: CircleKey { CircleOfFifths.key(at: selectedIndex, preferFlats: preferFlats) }
    private var scale: ModalScale { ModalScale(tonic: key.majorName, mode: selectedMode)! }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Text("Scale").font(.system(size: 12, weight: .medium))
                    Picker("Scale mode", selection: $selectedMode) {
                        ForEach(ScaleMode.allCases) { mode in Text(mode.displayName).tag(mode) }
                    }
                    .labelsHidden().frame(width: 210)
                    .accessibilityLabel("Scale mode")
                    Spacer(minLength: 8)
                    Text(selectedMode.formula)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(FifthsTheme.muted).lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityLabel("Scale formula: \(selectedMode.formula)")
                }
                Text(selectedMode == .ionian ? "Major keys outside · relative minors inside" : "Scale tonics outside · parent major keys inside")
                    .font(.system(size: 11)).foregroundStyle(FifthsTheme.muted)
                FifthsWheel(selectedIndex: $selectedIndex, preferFlats: $preferFlats, mode: selectedMode)
                    .frame(height: max(250, min(370, geometry.size.height - 280)))
                keyDetails
                Text("Clockwise: fifths   ·   Counterclockwise: fourths")
                    .font(.system(size: 10)).foregroundStyle(FifthsTheme.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .foregroundStyle(FifthsTheme.ink)
    }

    private var keyDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(scale.tonic) \(selectedMode.shortName.uppercased()) SCALE")
                    .font(.system(size: 10, weight: .semibold)).tracking(1)
                Spacer(minLength: 8)
                Text(scale.alteredNotes.isEmpty ? "Natural notes" : scale.alteredNotes.joined(separator: "  "))
                    .font(.system(size: 11)).lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityLabel("Scale accidentals: \(scale.signatureDescription)")
            }.foregroundStyle(FifthsTheme.muted)

            Text(scale.notes.joined(separator: "   "))
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityLabel("\(scale.tonic) \(selectedMode.shortName) scale: " + scale.notes.joined(separator: ", "))

            HStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { degree in
                    VStack(spacing: 5) {
                        Text(scale.romanDegrees[degree]).font(.system(size: 10)).foregroundStyle(FifthsTheme.muted)
                        Text(scale.seventhChords[degree])
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Degree \(scale.romanDegrees[degree]): \(scale.seventhChords[degree])")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Diatonic seventh chords")

            Divider().overlay(FifthsTheme.forest.opacity(0.08))

            HStack {
                Text(selectedMode == .ionian ? "ii – V – I" : "Tonic chord · parent major")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(FifthsTheme.muted)
                Spacer(minLength: 8)
                Text(selectedMode == .ionian
                     ? [scale.seventhChords[1], scale.seventhChords[4], scale.seventhChords[0]].joined(separator: "  →  ")
                     : "\(scale.seventhChords[0])  ·  \(scale.parentMajor) major")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(FifthsTheme.forest)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(FifthsTheme.ink.opacity(0.06)))
    }
}

private struct FifthsWheel: View {
    @Binding var selectedIndex: Int
    @Binding var preferFlats: Bool
    let mode: ScaleMode
    private var key: CircleKey { CircleOfFifths.key(at: selectedIndex, preferFlats: preferFlats) }
    private var scale: ModalScale { ModalScale(tonic: key.majorName, mode: mode)! }

    var body: some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.width, geometry.size.height) - 12
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                Circle().fill(.white)
                    .frame(width: diameter * 0.98, height: diameter * 0.98).position(center)
                FifthsSector(index: selectedIndex).fill(FifthsTheme.forest.opacity(0.11))
                    .frame(width: diameter, height: diameter).position(center)
                Circle().stroke(FifthsTheme.forest.opacity(0.18), lineWidth: 1)
                    .frame(width: diameter * 0.98, height: diameter * 0.98).position(center)
                Circle().stroke(FifthsTheme.forest.opacity(0.13), lineWidth: 1)
                    .frame(width: diameter * 0.70, height: diameter * 0.70).position(center)
                Circle().fill(FifthsTheme.paper)
                    .frame(width: diameter * 0.41, height: diameter * 0.41).position(center)

                ForEach(0..<12, id: \.self) { index in
                    majorButton(index: index)
                        .position(point(at: index, radius: diameter * 0.42, center: center))
                }
                ForEach(0..<12, id: \.self) { index in
                    innerButton(index: index)
                        .position(point(at: index, radius: diameter * 0.285, center: center))
                }
                centerLabel(diameter: diameter).position(center)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interactive circle of fifths")
    }

    private func majorButton(index: Int) -> some View {
        let item = CircleOfFifths.key(at: index, preferFlats: preferFlats)
        let itemScale = ModalScale(tonic: item.majorName, mode: mode)!
        let selected = selectedIndex == index
        return Button { selectedIndex = index } label: {
            Text(index == 6 ? "F♯/G♭" : item.majorName)
                .font(.system(size: index == 6 ? 16 : 21, weight: selected ? .semibold : .medium))
                .lineLimit(1).minimumScaleFactor(0.75)
                .frame(width: 64, height: 36)
                .foregroundStyle(selected ? .white : FifthsTheme.ink)
                .background(selected ? FifthsTheme.forest : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .ionian
                            ? "\(item.majorName) major, relative \(item.relativeMinor) minor, \(item.signatureDescription)"
                            : "\(item.majorName) \(mode.shortName), parent \(itemScale.parentMajor) major, \(itemScale.signatureDescription)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help("Explore \(item.majorName) \(mode.shortName)")
    }

    private func innerButton(index: Int) -> some View {
        let item = CircleOfFifths.key(at: index, preferFlats: preferFlats)
        let itemScale = ModalScale(tonic: item.majorName, mode: mode)!
        let selected = selectedIndex == index
        return Button { selectedIndex = index } label: {
            Text(mode == .ionian ? item.relativeMinor + "m" : itemScale.parentMajor)
                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                .frame(width: 46, height: 27)
                .foregroundStyle(selected ? FifthsTheme.forest : FifthsTheme.muted)
                .background(selected ? FifthsTheme.forest.opacity(0.08) : .clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .ionian
                            ? "\(item.relativeMinor) minor, relative of \(item.majorName) major"
                            : "\(itemScale.parentMajor) major, parent of \(item.majorName) \(mode.shortName)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(mode == .ionian ? "Explore \(item.majorName) major and \(item.relativeMinor) minor" : "Explore \(item.majorName) \(mode.shortName)")
    }

    private func centerLabel(diameter: CGFloat) -> some View {
        VStack(spacing: 3) {
            Text(key.majorName).font(.system(size: 30, weight: .semibold))
            Text(mode.shortName.uppercased()).font(.system(size: 9, weight: .medium)).tracking(0.7)
                .foregroundStyle(FifthsTheme.muted)
            Text(mode == .ionian ? "\(key.relativeMinor) minor" : "Parent: \(scale.parentMajor) major")
                .font(.system(size: mode == .ionian ? 13 : 11, weight: .medium))
            Text(scale.signatureDescription).font(.system(size: 10)).foregroundStyle(FifthsTheme.muted)
                .lineLimit(1).minimumScaleFactor(0.7)
            if selectedIndex == 6 {
                Picker("Key spelling", selection: $preferFlats) {
                    Text("F♯").tag(false)
                    Text("G♭").tag(true)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 102)
                .accessibilityLabel("Enharmonic key spelling")
                .padding(.top, 2)
            }
        }
        .frame(width: diameter * 0.36)
        .multilineTextAlignment(.center)
        .foregroundStyle(FifthsTheme.ink)
    }

    private func point(at index: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = Double(index) * .pi / 6 - .pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private struct FifthsSector: Shape {
    let index: Int
    func path(in rect: CGRect) -> Path {
        let diameter = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = Double(index) * .pi / 6 - .pi / 2 - .pi / 12
        let end = start + .pi / 6
        var path = Path()
        for step in 0...32 {
            let angle = start + (end - start) * Double(step) / 32
            let point = CGPoint(x: center.x + cos(angle) * diameter * 0.49,
                                y: center.y + sin(angle) * diameter * 0.49)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for step in (0...32).reversed() {
            let angle = start + (end - start) * Double(step) / 32
            path.addLine(to: CGPoint(x: center.x + cos(angle) * diameter * 0.205,
                                    y: center.y + sin(angle) * diameter * 0.205))
        }
        path.closeSubpath()
        return path
    }
}
