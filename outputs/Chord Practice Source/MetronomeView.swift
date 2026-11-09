import SwiftUI

private let metronomeInk = Color(red: 0.12, green: 0.20, blue: 0.17)
private let metronomeForest = Color(red: 0.15, green: 0.34, blue: 0.26)
private let metronomePaper = Color(red: 0.96, green: 0.96, blue: 0.93)
private let metronomeMuted = Color(red: 0.43, green: 0.48, blue: 0.44)

struct MetronomeView: View {
    @ObservedObject var model: MetronomeModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Find your pulse").font(.system(size: 22, weight: .semibold))
                    Text("A steady beat for your practice.")
                        .font(.system(size: 12)).foregroundStyle(metronomeMuted)
                }

                pulseCard
                settingsCard

                Text("The metronome keeps ticking when you return to Practice.")
                    .font(.system(size: 11))
                    .foregroundStyle(metronomeMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if let errorMessage = model.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(metronomeMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 680)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(metronomeInk)
        .tint(metronomeForest)
        .frame(minWidth: 540, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var pulseCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(model.tempo)")
                    .font(.system(size: 62, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Text("BPM")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(metronomeMuted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(model.tempo) beats per minute")

            HStack(spacing: 12) {
                ForEach(0..<model.beatsPerBar, id: \.self) { beat in
                    let active = model.running && model.currentBeat == beat
                    Circle()
                        .fill(active ? metronomeForest : metronomeForest.opacity(0.09))
                        .overlay(Circle().strokeBorder(
                            model.accentFirstBeat && beat == 0 ? metronomeForest.opacity(0.7) : .clear,
                            lineWidth: 2))
                        .frame(width: 18, height: 18)
                }
            }
            .frame(height: 22)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.beatsPerBar) beats per bar")
            .accessibilityValue(model.running ? "Beat \(model.currentBeat + 1)" : "Stopped")

            HStack(spacing: 10) {
                Button(action: model.toggle) {
                    Label(model.running ? "Stop" : "Start", systemImage: model.running ? "stop.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 142, height: 42)
                        .foregroundStyle(.white)
                        .background(metronomeForest, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Button(action: model.tap) {
                    Label("Tap tempo", systemImage: "hand.tap")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 124, height: 42)
                        .background(metronomePaper, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .help("Tap several times at the tempo you want")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(metronomeInk.opacity(0.06), lineWidth: 1))
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Text("Tempo").font(.system(size: 13, weight: .semibold)).frame(width: 55, alignment: .leading)
                tempoStep("Decrease tempo", symbol: "minus", value: model.tempo - 1)
                    .disabled(model.tempo <= 30)
                Slider(value: Binding(get: { Double(model.tempo) }, set: { model.setTempo(Int($0.rounded())) }), in: 30...300, step: 1)
                    .accessibilityLabel("Tempo")
                    .accessibilityValue("\(model.tempo) beats per minute")
                tempoStep("Increase tempo", symbol: "plus", value: model.tempo + 1)
                    .disabled(model.tempo >= 300)
            }

            HStack(spacing: 8) {
                Text("Quick set").font(.system(size: 11)).foregroundStyle(metronomeMuted)
                    .frame(width: 55, alignment: .leading)
                ForEach([60, 80, 100, 120], id: \.self) { tempo in
                    Button { model.setTempo(tempo) } label: {
                        Text("\(tempo)")
                            .font(.system(size: 11, weight: .medium)).monospacedDigit()
                            .foregroundStyle(model.tempo == tempo ? .white : metronomeInk)
                            .frame(width: 54, height: 28)
                            .background(model.tempo == tempo ? metronomeForest : metronomeForest.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(tempo) beats per minute")
                    .accessibilityAddTraits(model.tempo == tempo ? .isSelected : [])
                }
                Spacer(minLength: 0)
            }

            Divider()

            HStack(spacing: 14) {
                Picker("Beats per bar", selection: Binding(get: { model.beatsPerBar }, set: model.setBeatsPerBar)) {
                    ForEach(1...8, id: \.self) { beats in
                        Text("\(beats)").tag(beats)
                    }
                }
                .frame(width: 165)
                Spacer(minLength: 0)
                Toggle("Accent first beat", isOn: Binding(get: { model.accentFirstBeat }, set: model.setAccentFirstBeat))
                    .toggleStyle(.checkbox)
            }
            .font(.system(size: 12))

            HStack(spacing: 12) {
                Text("Volume").font(.system(size: 12, weight: .medium)).frame(width: 55, alignment: .leading)
                Slider(value: Binding(get: { model.volume }, set: model.setVolume), in: 0...1)
                    .accessibilityLabel("Metronome volume")
                    .accessibilityValue("\(Int((model.volume * 100).rounded())) percent")
                Text("\(Int((model.volume * 100).rounded()))%")
                    .font(.system(size: 11)).monospacedDigit()
                    .foregroundStyle(metronomeMuted)
                    .frame(width: 36, alignment: .trailing)
            }
        }
        .padding(18)
        .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(metronomeInk.opacity(0.06), lineWidth: 1))
    }

    private func tempoStep(_ title: String, symbol: String, value: Int) -> some View {
        Button { model.setTempo(value) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(metronomeForest.opacity(0.07), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }
}
