# Chord Practice

A native macOS app for practicing jazz chords, reading notation, and exploring scales. It works offline.

- **Practice:** Shuffle a custom pool of chord roots and qualities. Set the interval and session length, and show chord symbols, a treble or bass staff, or both.
- **Chord audio:** Choose an instrument and the chord tones you want to hear. Replay the current chord at any time.
- **Circle of Fifths:** Compare all seven diatonic modes, including Dorian and Mixolydian. Each tonic shows the scale notes, formula, and diatonic seventh chords.
- **Metronome:** Set or tap a tempo, choose the beats per bar, and keep the click running during practice.

## Build and run

The app runs on macOS 13 Ventura or later, on Apple silicon and Intel. Building requires Xcode command-line tools (`xcode-select --install` if needed).

From the repository root:

```sh
zsh "outputs/Chord Practice Source/Build.command"
open "outputs/Chord Practice.app"
```

The script builds and locally signs a universal app. See the [user guide](outputs/Read%20Me.txt) for settings, supported chord symbols, and shortcuts.
