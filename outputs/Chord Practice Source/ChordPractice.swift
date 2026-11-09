import SwiftUI
import AppKit
import Combine

// Explicitly use the property wrapper, preserving macOS 13 support across newer SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>

private let ink = Color(red: 0.12, green: 0.20, blue: 0.17)
private let forest = Color(red: 0.15, green: 0.34, blue: 0.26)
private let paper = Color(red: 0.96, green: 0.96, blue: 0.93)
private let muted = Color(red: 0.43, green: 0.48, blue: 0.44)

@MainActor final class PracticeModel: ObservableObject {
    @Published private(set) var settings: PracticeSettings
    @Published private(set) var chord: Chord
    @Published private(set) var running = false
    @Published private(set) var remaining: Double
    @Published private(set) var displayed = 0
    @Published private(set) var sessionRemaining: Double?
    @Published private(set) var audioError: String?
    private var deck: ChordDeck
    private var clock: PracticeClock
    private var sessionClock: SessionClock
    private var timer: AnyCancellable?
    private var soundPlayer: (any ChordSoundPlaying)?
    private let storageKey = "practice.settings.v1"
    private let defaults: UserDefaults?
    private let now: () -> Double
    private var uptime: Double { now() }
    var completed: Bool { sessionRemaining == 0 }
    var canReplaySound: Bool { !settings.audio.midiNotes(for: chord, clef: settings.staffClef).isEmpty }
    var soundStatusMessage: String? {
        if let audioError { return audioError }
        if chord.staffNotes == nil { return "Sound is unavailable for this chord symbol." }
        if !canReplaySound { return "This chord has none of the selected tones." }
        return nil
    }

    init(settingsOverride: PracticeSettings? = nil, defaults: UserDefaults? = .standard,
         now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }, automaticTimer: Bool = true,
         soundPlayer: (any ChordSoundPlaying)? = nil) {
        self.defaults = defaults
        self.now = now
        self.soundPlayer = soundPlayer
        let saved = defaults?.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(PracticeSettings.self, from: $0) }
        let settings = (settingsOverride ?? saved ?? PracticeSettings()).validated()
        self.settings = settings
        var deck = ChordDeck(chords: settings.chords)
        chord = deck.next() ?? Chord(root: "C", suffix: "Δ7")
        self.deck = deck
        clock = PracticeClock(duration: settings.interval)
        remaining = settings.interval
        sessionClock = SessionClock(duration: settings.sessionDuration)
        sessionRemaining = settings.sessionDuration
        if automaticTimer {
            timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in
                self?.tick()
            }
        }
    }

    func toggle() {
        if running { pause() }
        else {
            let now = uptime
            if completed {
                sessionClock = SessionClock(duration: settings.sessionDuration)
                sessionRemaining = settings.sessionDuration
                clock = PracticeClock(duration: settings.interval)
                remaining = settings.interval
                if let next = deck.next() { chord = next }
                displayed = 0
            }
            clock.start(at: now)
            sessionClock.start(at: now)
            running = true
            if displayed == 0 { displayed = 1 }
            playAutomatically()
        }
    }
    func pause() {
        let now = uptime
        if sessionClock.tick(at: now) { finish(at: now); return }
        sessionClock.pause(at: now)
        sessionRemaining = sessionClock.remaining
        clock.pause(at: now)
        remaining = clock.remaining
        running = false
        stopAudio()
    }
    func next() {
        guard !completed else { return }
        let now = uptime
        if sessionClock.tick(at: now) { finish(at: now); return }
        sessionRemaining = sessionClock.remaining
        if let next = deck.next() { chord = next }
        displayed += 1
        clock.reset(duration: settings.interval, at: now)
        remaining = settings.interval
        playAutomatically()
    }
    func apply(_ value: PracticeSettings) {
        pause()
        settings = value.validated()
        audioError = nil
        deck = ChordDeck(chords: settings.chords)
        if let next = deck.next() { chord = next }
        displayed = 0
        clock = PracticeClock(duration: settings.interval)
        remaining = settings.interval
        sessionClock = SessionClock(duration: settings.sessionDuration)
        sessionRemaining = settings.sessionDuration
        saveSettings()
    }
    func setDisplayMode(_ mode: ChordDisplayMode) {
        settings.displayMode = mode
        saveSettings()
    }
    func setClef(_ clef: StaffClef) {
        settings.staffClef = clef
        saveSettings()
        if running { playAutomatically() } else { stopAudio() }
    }
    func setAudioOptions(_ options: ChordAudioOptions) {
        let old = settings.audio
        settings.audio = options.validated()
        audioError = nil
        saveSettings()
        let voicesChanged = old.instrument != settings.audio.instrument || old.selectedTones != settings.audio.selectedTones
        if old.enabled && !settings.audio.enabled {
            stopAudio()
        } else if voicesChanged {
            if running { playAutomatically() } else { stopAudio() }
        } else {
            soundPlayer?.setVolume(settings.audio.volume)
            if !old.enabled && settings.audio.enabled && running { playAutomatically() }
        }
    }
    func replayChord() {
        playSound(options: settings.audio, clef: settings.staffClef)
    }
    func previewAudio(_ options: ChordAudioOptions, clef: StaffClef) {
        playSound(options: options.validated(), clef: clef)
    }
    func stopAudio() {
        soundPlayer?.stop()
    }
    private func playAutomatically() {
        if settings.audio.enabled {
            playSound(options: settings.audio, clef: settings.staffClef)
        } else {
            stopAudio()
        }
    }
    private func playSound(options: ChordAudioOptions, clef: StaffClef) {
        audioError = nil
        let notes = options.midiNotes(for: chord, clef: clef)
        guard !notes.isEmpty else { stopAudio(); return }
        do {
            if soundPlayer == nil { soundPlayer = ChordAudioPlayer() }
            let duration = min(2, max(0.15, settings.interval * 0.8))
            try soundPlayer?.play(notes: notes, instrument: options.instrument, volume: options.volume, duration: duration)
        } catch {
            stopAudio()
            audioError = error.localizedDescription
        }
    }
    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults?.set(data, forKey: storageKey)
        }
    }
    func tick() {
        guard running else { return }
        let now = uptime
        if sessionClock.tick(at: now) { finish(at: now); return }
        sessionRemaining = sessionClock.remaining
        if clock.tick(at: now) {
            if let next = deck.next() { chord = next }
            displayed += 1
            playAutomatically()
        }
        remaining = clock.remaining
    }

    private func finish(at now: Double) {
        clock.pause(at: now)
        remaining = 0
        sessionRemaining = 0
        running = false
        stopAudio()
    }
}

private func timeLabel(_ seconds: Double) -> String {
    let total = max(0, Int(ceil(seconds)))
    return String(format: "%d:%02d", total / 60, total % 60)
}

enum AppSection: String, CaseIterable, Identifiable {
    case practice, circleOfFifths, metronome
    var id: String { rawValue }
    var label: String {
        switch self {
        case .practice: return "Practice"
        case .circleOfFifths: return "Circle of Fifths"
        case .metronome: return "Metronome"
        }
    }
}

struct MainView: View {
    @ObservedObject var model: PracticeModel
    @StateObject private var metronome = MetronomeModel()
    @ViewState private var showSettings = false
    @ViewState private var activeTab: AppSection = .practice
    @ViewState private var circleIndex = 0
    @ViewState private var circlePreferFlats = false
    @ViewState private var circleScaleMode: ScaleMode = .ionian
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func openSettings() { model.pause(); showSettings = true }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "music.note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(forest)
                    .frame(width: 40, height: 40)
                    .background(forest.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Chord Practice").font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    Text(activeTab == .practice ? "A little focus. A new chord." : activeTab == .circleOfFifths ? "Explore keys and how they connect." : "Find your tempo. Keep the pulse.").font(.system(size: 12)).foregroundStyle(muted).lineLimit(1)
                }
                Spacer()
                if metronome.running && activeTab != .metronome {
                    Button(action: metronome.stop) {
                        Label("\(metronome.tempo) BPM", systemImage: "metronome")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(forest)
                            .padding(.horizontal, 10).padding(.vertical, 10)
                            .background(.white.opacity(0.8), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Stop the metronome")
                    .accessibilityLabel("Stop metronome, \(metronome.tempo) beats per minute")
                }
                Button(action: openSettings) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.white.opacity(0.8), in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(",", modifiers: .command)
                .help("Choose chords and interval (⌘,)")
            }
            .padding(.bottom, 22)

            Picker("App section", selection: $activeTab) {
                ForEach(AppSection.allCases) { section in Text(section.label).tag(section) }
            }
            .pickerStyle(.segmented).labelsHidden()
            .frame(width: 420).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 18)

            if activeTab == .practice {
                practiceContent
            } else if activeTab == .circleOfFifths {
                CircleOfFifthsView(selectedIndex: $circleIndex, preferFlats: $circlePreferFlats, selectedMode: $circleScaleMode)
            } else {
                MetronomeView(model: metronome)
            }
        }
        .padding(30)
        .foregroundStyle(ink)
        .background(paper)
        .frame(minWidth: 600, idealWidth: 720, minHeight: 820, idealHeight: 850)
        .sheet(isPresented: $showSettings, onDismiss: model.stopAudio) {
            SettingsView(initial: model.settings, onSave: model.apply, onPreview: model.previewAudio)
        }
        .onChange(of: activeTab) { section in
            if section != .practice { model.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title == "Chord Practice" {
                model.pause()
                metronome.stop()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification)) { _ in
            model.pause()
            metronome.stop()
        }
    }

    private var practiceContent: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Display", selection: Binding(get: { model.settings.displayMode }, set: model.setDisplayMode)) {
                    ForEach(ChordDisplayMode.allCases) { mode in Text(mode.label).tag(mode) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                .accessibilityLabel("Display mode")
                Spacer()
                if model.settings.displayMode != .chordName {
                    Picker("Clef", selection: Binding(get: { model.settings.staffClef }, set: model.setClef)) {
                        ForEach(StaffClef.allCases) { clef in Text(clef.label).tag(clef) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 170)
                    .accessibilityLabel("Staff clef")
                }
            }
            .padding(.bottom, 18)

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    Circle().fill(model.running ? forest : muted.opacity(0.5)).frame(width: 6, height: 6)
                    Text(model.completed ? "SESSION COMPLETE" : (model.running ? "PRACTICING" : (model.displayed == 0 ? "READY WHEN YOU ARE" : "PAUSED")))
                        .font(.system(size: 10, weight: .semibold)).tracking(2)
                }
                .foregroundStyle(muted)
                .padding(.top, 31)

                Spacer(minLength: 20)
                VStack(spacing: 12) {
                    PracticeDisplay(chord: model.chord, mode: model.settings.displayMode, clef: model.settings.staffClef)
                    if model.settings.displayMode != .staff {
                        Text(model.chord.formula ?? "Formula unavailable for this symbol")
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .tracking(1).foregroundStyle(muted)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .accessibilityLabel("Chord composition: \(model.chord.formula ?? "unavailable")")
                    }
                }
                    .id(model.chord)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, minHeight: 160)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: model.chord)
                    .padding(.horizontal, 38)
                Spacer(minLength: 20)

                VStack(spacing: 11) {
                    HStack {
                        Text(model.running ? "NEXT CHORD" : "INTERVAL")
                            .font(.system(size: 10, weight: .medium)).tracking(1.5)
                        Spacer()
                        Text("\(model.running ? model.remaining : model.settings.interval, specifier: "%.1f") s")
                            .font(.system(size: 12, weight: .medium, design: .monospaced)).monospacedDigit()
                    }.foregroundStyle(muted)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(forest.opacity(0.08))
                            Capsule().fill(forest.opacity(model.running ? 0.8 : 0.25))
                                .frame(width: max(0, geometry.size.width * model.remaining / model.settings.interval))
                        }
                    }
                    .frame(height: 4)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue("\(model.remaining, specifier: "%.1f") seconds")
                }
                .padding(.horizontal, 32).padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(ink.opacity(0.06), lineWidth: 1))

            AudioControlsView(
                options: Binding(get: { model.settings.audio }, set: model.setAudioOptions),
                canReplay: model.canReplaySound, statusMessage: model.soundStatusMessage, onReplay: model.replayChord
            )
            .padding(.top, 14)

            HStack(spacing: 7) {
                Image(systemName: model.completed ? "checkmark.circle" : "timer")
                Text(model.completed ? "Session complete" : "Practice time")
                Spacer()
                if let seconds = model.sessionRemaining {
                    Text(model.completed ? "Well played. Ready for another?" : "\(timeLabel(seconds)) remaining")
                        .monospacedDigit()
                } else {
                    Text("No time limit")
                }
            }
            .font(.system(size: 12, weight: .medium)).foregroundStyle(muted)
            .padding(.horizontal, 3).padding(.top, 17)

            HStack(spacing: 12) {
                Button(action: model.toggle) {
                    HStack(spacing: 9) {
                        Image(systemName: model.running ? "pause.fill" : "play.fill").font(.system(size: 12))
                        Text(model.completed ? "Practice again" : (model.running ? "Pause" : (model.displayed == 0 ? "Start practice" : "Resume")))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 51)
                    .foregroundStyle(.white)
                    .background(forest, in: RoundedRectangle(cornerRadius: 15))
                    .contentShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])
                .help("Start or pause (Space)")

                Button(action: model.next) {
                    HStack(spacing: 8) {
                        Text("Next").font(.system(size: 14, weight: .medium))
                        Image(systemName: "forward.end.fill").font(.system(size: 11))
                    }
                    .frame(width: 112, height: 51)
                    .background(.white, in: RoundedRectangle(cornerRadius: 15))
                    .contentShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])
                .help("Show next chord (→)")
                .disabled(model.completed)
                .opacity(model.completed ? 0.45 : 1)
            }
            .padding(.top, 20)

            HStack {
                Button(action: openSettings) {
                    HStack(spacing: 5) {
                        Text("\(model.settings.chords.count) chords")
                        Text("·")
                        Text(model.settings.summary)
                    }
                    .font(.system(size: 11)).foregroundStyle(muted)
                }.buttonStyle(.plain).help("Edit your chord selection")
                Spacer(minLength: 6)
                Text("Space to \(model.running ? "pause" : "play")")
                    .font(.system(size: 11)).foregroundStyle(muted.opacity(0.8))
            }
            .padding(.top, 18)
        }
    }
}

struct PracticeDisplay: View {
    let chord: Chord
    let mode: ChordDisplayMode
    let clef: StaffClef

    var body: some View {
        if mode == .chordName {
            ChordDisplay(chord: chord)
        } else if let notes = chord.staffNotes {
            VStack(spacing: 0) {
                StaffNotationView(notes: notes, clef: clef)
                    .frame(height: mode == .both ? 195 : 235)
                if mode == .both {
                    Text(chord.name).font(.system(size: 37, weight: .regular))
                        .lineLimit(1).minimumScaleFactor(0.3).foregroundStyle(ink)
                        .accessibilityLabel("Chord name: \(chord.name)")
                }
            }
            .frame(maxWidth: .infinity)
        } else if mode == .staff {
            VStack(spacing: 10) {
                Image(systemName: "music.note").font(.system(size: 30))
                Text("Staff notation unavailable").font(.system(size: 15, weight: .medium))
                Text("Choose a supported chord type in Settings.").font(.system(size: 12))
            }
            .foregroundStyle(muted)
            .frame(maxWidth: .infinity, minHeight: 235)
        } else {
            VStack(spacing: 14) {
                ChordDisplay(chord: chord)
                Text("Staff notation is available for the chord types in Settings.\nThis custom symbol is shown as a chord name.")
                    .font(.system(size: 12)).foregroundStyle(muted).multilineTextAlignment(.center)
            }
        }
    }
}

struct ChordDisplay: View {
    let chord: Chord
    var body: some View {
        Group {
            if let literal = chord.literal {
                Text(literal).font(.system(size: 156, weight: .regular))
            } else {
                (Text(chord.root).font(.system(size: 176, weight: .regular))
                 + Text(chord.accidental).font(.system(size: 87, weight: .regular)).baselineOffset(55)
                 + Text(chord.suffix).font(.system(size: chord.suffix == "sus4" ? 57 : 75, weight: .regular)).baselineOffset(0))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.15)
        .foregroundStyle(ink)
        .accessibilityLabel(chord.name)
        .textSelection(.enabled)
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ViewState private var draft: PracticeSettings
    let onSave: (PracticeSettings) -> Void
    let onPreview: (ChordAudioOptions, StaffClef) -> Void
    init(initial: PracticeSettings, onSave: @escaping (PracticeSettings) -> Void,
         onPreview: @escaping (ChordAudioOptions, StaffClef) -> Void) {
        _draft = State(initialValue: initial)
        self.onSave = onSave
        self.onPreview = onPreview
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Make it your practice").font(.system(size: 24, weight: .semibold))
                Text("Choose your chords, interval, and total practice time.")
                    .font(.system(size: 13)).foregroundStyle(muted)
            }
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            AudioOptionsEditor(options: $draft.audio, onPreview: { onPreview(draft.audio, draft.staffClef) })
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("Display").font(.system(size: 14, weight: .semibold))
                Picker("Display mode", selection: $draft.displayMode) {
                    ForEach(ChordDisplayMode.allCases) { mode in Text(mode.label).tag(mode) }
                }.pickerStyle(.segmented).labelsHidden()
                if draft.displayMode != .chordName {
                    Picker("Staff clef", selection: $draft.staffClef) {
                        ForEach(StaffClef.allCases) { clef in Text(clef.label).tag(clef) }
                    }.pickerStyle(.segmented)
                    Text("Root-position chords. Bass clef places them two octaves lower.")
                        .font(.system(size: 11)).foregroundStyle(muted)
                }
                if draft.displayMode == .staff {
                    Text("Staff only hides the chord name and composition numbers.")
                        .font(.system(size: 11)).foregroundStyle(muted)
                }
            }
            Divider()
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Change every").font(.system(size: 14, weight: .semibold))
                    Text("0.5 to 300 seconds").font(.system(size: 11)).foregroundStyle(muted)
                }
                Spacer()
                TextField("Seconds", value: $draft.interval, format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder).frame(width: 70)
                    .accessibilityLabel("Interval in seconds")
                Text("seconds").font(.system(size: 13)).foregroundStyle(muted)
                Stepper("Interval", value: $draft.interval, in: 0.5...300, step: 0.5).labelsHidden()
            }
            HStack(spacing: 7) {
                Text("Quick set").font(.system(size: 11)).foregroundStyle(muted).padding(.trailing, 5)
                ForEach([2.0, 4, 8, 15, 30], id: \.self) { value in
                    choice("\(Int(value))s", selected: draft.interval == value) { draft.interval = value }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Total practice time").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Toggle("No time limit", isOn: $draft.unlimitedSession)
                        .font(.system(size: 11)).toggleStyle(.checkbox)
                }
                if !draft.unlimitedSession {
                    HStack(spacing: 10) {
                        TextField("Minutes", value: $draft.sessionMinutes, format: .number.precision(.fractionLength(0...1)))
                            .textFieldStyle(.roundedBorder).frame(width: 70)
                            .accessibilityLabel("Total practice time in minutes")
                        Text("minutes").font(.system(size: 13)).foregroundStyle(muted)
                        Stepper("Practice minutes", value: $draft.sessionMinutes, in: 0.5...240, step: 0.5).labelsHidden()
                        Spacer()
                        ForEach([5.0, 10, 20], id: \.self) { minutes in
                            choice("\(Int(minutes))m", selected: draft.sessionMinutes == minutes) { draft.sessionMinutes = minutes }
                                .frame(width: 49)
                        }
                    }
                }
                Text("Chords repeat in a new random order until the session ends.")
                    .font(.system(size: 11)).foregroundStyle(muted)
            }

            Divider()
            Picker("Chord source", selection: $draft.useCustom) {
                Text("Choose notes & types").tag(false)
                Text("Custom chord list").tag(true)
            }.pickerStyle(.segmented).labelsHidden()

            if draft.useCustom {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your chords").font(.system(size: 14, weight: .semibold))
                    Text("Separate chords with commas or new lines. Use any notation you like.")
                        .font(.system(size: 12)).foregroundStyle(muted)
                    TextEditor(text: $draft.customText)
                        .font(.system(size: 18, design: .monospaced))
                        .padding(8).frame(height: 194)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ink.opacity(0.15)))
                        .accessibilityLabel("Custom chords, separated by commas or new lines")
                    Text("For example: D−7, G7, CΔ7, CmMaj7, G7♭9")
                        .font(.system(size: 11)).foregroundStyle(muted)
                    if !draft.customChords.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Chord composition").font(.system(size: 12, weight: .semibold))
                            ForEach(draft.customChords, id: \.self) { chord in
                                HStack {
                                    Text(chord.name).font(.system(size: 12, weight: .medium))
                                        .lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 8)
                                    Text(chord.formula ?? "Formula unavailable")
                                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Notes").font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Button(draft.roots.count == 12 ? "Clear" : "Select all") {
                            draft.roots = draft.roots.count == 12 ? [] : Array(0..<12)
                        }.buttonStyle(.plain).font(.system(size: 11, weight: .medium)).foregroundStyle(forest)
                        Picker("Accidentals", selection: $draft.useSharps) {
                            Text("♭ Flats").tag(false)
                            Text("♯ Sharps").tag(true)
                        }.pickerStyle(.segmented).frame(width: 155).labelsHidden()
                    }
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(0..<12, id: \.self) { index in
                            choice(draft.rootNames[index], selected: draft.roots.contains(index)) {
                                if draft.roots.contains(index) { draft.roots.removeAll { $0 == index } }
                                else { draft.roots.append(index) }
                            }
                        }
                    }
                    Text("Chord types").font(.system(size: 14, weight: .semibold)).padding(.top, 4)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                        ForEach(ChordQuality.allCases) { quality in
                            Button {
                                if draft.qualities.contains(quality) { draft.qualities.removeAll { $0 == quality } }
                                else { draft.qualities.append(quality) }
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(quality.label).font(.system(size: 12)).lineLimit(1).minimumScaleFactor(0.85)
                                        Spacer(minLength: 5)
                                        Text("C\(quality.symbol)").font(.system(size: 14, weight: .medium))
                                    }
                                    Text(quality.formula)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(draft.qualities.contains(quality) ? forest.opacity(0.85) : muted)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .foregroundStyle(draft.qualities.contains(quality) ? forest : muted)
                                .background(draft.qualities.contains(quality) ? forest.opacity(0.09) : .white, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(draft.qualities.contains(quality) ? forest.opacity(0.5) : ink.opacity(0.12)))
                                .contentShape(RoundedRectangle(cornerRadius: 9))
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(draft.qualities.contains(quality) ? .isSelected : [])
                                .accessibilityLabel("\(quality.label), C\(quality.symbol), composition \(quality.formula)")
                        }
                    }
                }
            }
            }
            .padding(.trailing, 3)
            }
            .frame(height: 510)

            HStack {
                Text(draft.chords.isEmpty ? "Choose at least one chord to continue." : "\(draft.chords.count) chords in your practice pool")
                    .font(.system(size: 12)).foregroundStyle(draft.chords.isEmpty ? .red : muted)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { onSave(draft); dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).tint(forest)
                    .disabled(draft.chords.isEmpty || !draft.interval.isFinite || draft.interval < 0.5 || draft.interval > 300
                              || (!draft.unlimitedSession && (!draft.sessionMinutes.isFinite || draft.sessionMinutes < 0.5 || draft.sessionMinutes > 240)))
            }
        }
        .padding(28).frame(width: 530).background(paper).foregroundStyle(ink)
    }

    private func choice(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .foregroundStyle(selected ? Color.white : ink)
                .background(selected ? forest : .white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? forest : ink.opacity(0.12)))
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

#if !TESTING
@main struct ChordPracticeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = PracticeModel()
    var body: some Scene {
        Window("Chord Practice", id: "practice") {
            MainView(model: model).preferredColorScheme(.light)
        }
        .defaultSize(width: 720, height: 850)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(after: .toolbar) {
                Button("Enter Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                    .keyboardShortcut("f", modifiers: [.control, .command])
            }
        }
    }
}
#endif
