import SwiftUI

private typealias AudioViewState<Value> = SwiftUI.State<Value>

private let audioInk = Color(red: 0.12, green: 0.20, blue: 0.17)
private let audioForest = Color(red: 0.15, green: 0.34, blue: 0.26)
private let audioPaper = Color(red: 0.96, green: 0.96, blue: 0.93)
private let audioMuted = Color(red: 0.43, green: 0.48, blue: 0.44)

struct AudioControlsView: View {
    @Binding var options: ChordAudioOptions
    let canReplay: Bool
    let statusMessage: String?
    let onReplay: () -> Void
    @AudioViewState private var showTones = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Toggle("Auto sound", isOn: optionBinding(\.enabled))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .help("Play the selected tones when the chord changes")
                Spacer(minLength: 0)
                Picker("Instrument", selection: optionBinding(\.instrument)) {
                    ForEach(ChordInstrument.allCases) { instrument in
                        Text(instrument.label).tag(instrument)
                    }
                }
                .labelsHidden()
                .frame(width: 142)
                .accessibilityLabel("Instrument")
                Button { showTones.toggle() } label: {
                    Label("Tones", systemImage: "slider.horizontal.3")
                }
                .popover(isPresented: $showTones, arrowEdge: .bottom) {
                    AudioOptionsEditor(options: $options, onPreview: canReplay ? onReplay : nil)
                        .padding(20)
                        .frame(width: 340)
                        .background(audioPaper)
                }
                Button(action: onReplay) {
                    Label("Replay", systemImage: "speaker.wave.2")
                }
                .disabled(!canReplay)
                .help("Play the current chord with the selected tones")
            }
            .controlSize(.small)
            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(audioMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(audioInk)
        .tint(audioForest)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 540)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(audioInk.opacity(0.06), lineWidth: 1))
    }

    private func optionBinding<Value>(_ keyPath: WritableKeyPath<ChordAudioOptions, Value>) -> Binding<Value> {
        Binding(get: { options[keyPath: keyPath] }, set: { value in
            var updated = options
            updated[keyPath: keyPath] = value
            options = updated.validated()
        })
    }
}

struct AudioOptionsEditor: View {
    @Binding var options: ChordAudioOptions
    var onPreview: (() -> Void)? = nil

    private var selectedTones: [ChordTone] {
        ChordTone.allCases.filter { options.selectedTones.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Toggle("Automatic chord sound", isOn: optionBinding(\.enabled))
                .toggleStyle(.switch)
                .font(.system(size: 13, weight: .medium))
            Picker("Instrument", selection: optionBinding(\.instrument)) {
                ForEach(ChordInstrument.allCases) { instrument in
                    Text(instrument.label).tag(instrument)
                }
            }
            .font(.system(size: 12))

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Chord tones").font(.system(size: 13, weight: .semibold))
                ForEach(ChordTone.allCases) { tone in
                    Toggle(tone.label, isOn: toneBinding(tone))
                        .toggleStyle(.checkbox)
                        .disabled(selectedTones.count == 1 && selectedTones.contains(tone))
                        .font(.system(size: 12))
                }
                HStack(spacing: 6) {
                    preset("All tones", tones: ChordTone.allCases)
                    preset("3rd + 7th", tones: [.third, .seventh])
                    preset("Root only", tones: [.root])
                }
                .padding(.top, 2)
                Text("Only available tones are played. Triads omit the 7th and 9th; suspended chords use the 4th in place of the 3rd.")
                    .font(.system(size: 11))
                    .foregroundStyle(audioMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int((options.validated().volume * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(audioMuted)
                }
                .font(.system(size: 12, weight: .medium))
                Slider(value: optionBinding(\.volume), in: 0...1)
                    .accessibilityLabel("Chord volume")
                    .accessibilityValue("\(Int((options.validated().volume * 100).rounded())) percent")
            }
            if let onPreview {
                Button(action: onPreview) {
                    Label("Preview sound", systemImage: "speaker.wave.2")
                }
                .controlSize(.small)
            }
        }
        .foregroundStyle(audioInk)
        .tint(audioForest)
    }

    private func optionBinding<Value>(_ keyPath: WritableKeyPath<ChordAudioOptions, Value>) -> Binding<Value> {
        Binding(get: { options[keyPath: keyPath] }, set: { value in
            var updated = options
            updated[keyPath: keyPath] = value
            options = updated.validated()
        })
    }

    private func toneBinding(_ tone: ChordTone) -> Binding<Bool> {
        Binding(get: { options.selectedTones.contains(tone) }, set: { enabled in
            var updated = options
            let current = selectedTones
            guard enabled || current.count > 1 || !current.contains(tone) else { return }
            updated.selectedTones = ChordTone.allCases.filter {
                $0 == tone ? enabled : current.contains($0)
            }
            options = updated.validated()
        })
    }

    private func preset(_ title: String, tones: [ChordTone]) -> some View {
        let selected = selectedTones == ChordTone.allCases.filter { tones.contains($0) }
        return Button {
            var updated = options
            updated.selectedTones = ChordTone.allCases.filter { tones.contains($0) }
            options = updated.validated()
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected ? Color.white : audioInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(selected ? audioForest : audioForest.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
