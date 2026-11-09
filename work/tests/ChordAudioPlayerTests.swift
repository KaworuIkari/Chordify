import Foundation
import AVFoundation

@main
struct ChordAudioPlayerTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    @MainActor static func render(_ player: ChordAudioPlayer, frames: Int) throws -> Float {
        let format = player.offlineFormat!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        var remaining = frames
        var peak: Float = 0
        var retries = 0
        while remaining > 0 {
            let count = AVAudioFrameCount(min(remaining, 4096))
            switch try player.renderOffline(count, into: buffer) {
            case .success:
                check(buffer.frameLength > 0, "Render made no progress")
                for channel in 0..<Int(format.channelCount) {
                    let data = buffer.floatChannelData![channel]
                    for index in 0..<Int(buffer.frameLength) {
                        check(data[index].isFinite, "Nonfinite output")
                        peak = max(peak, abs(data[index]))
                    }
                }
                remaining -= Int(buffer.frameLength)
                retries = 0
            case .cannotDoInCurrentContext:
                retries += 1
                check(retries < 100, "Render did not become ready")
            default: fatalError("Offline render failed")
            }
        }
        return peak
    }
    @MainActor static func main() async throws {
        let player = ChordAudioPlayer(offlineSampleRate: 44_100)
        check(player.offlineFormat == nil, "Initialization must be lazy")
        for instrument in ChordInstrument.allCases {
            try player.play(notes: [60, 64, 67], instrument: instrument, volume: 0.7, duration: 5)
            let peak = try render(player, frames: 22_050)
            check(peak > 0.00001, "Silent instrument: \(instrument)")
            player.stop()
            _ = try render(player, frames: 4096)
            let stopped = try render(player, frames: 4096)
            check(stopped < 0.00001, "Stuck notes: \(instrument), peak \(stopped)")
        }
        try player.play(notes: [60, 64, 67], instrument: .piano, volume: 0, duration: 5)
        _ = try render(player, frames: 4096) // Allow mixer gain ramp to settle.
        let muted = try render(player, frames: 4096)
        check(muted < 0.00001, "Volume zero must be silent")
        try player.play(notes: [72], instrument: .piano, volume: 1, duration: 0.05)
        try await Task.sleep(nanoseconds: 100_000_000)
        _ = try render(player, frames: 220_500) // Render five seconds for the release envelope.
        let timed = try render(player, frames: 4096)
        check(timed < 0.00001, "Released notes must eventually become silent")
        try player.play(notes: [60], instrument: .strings, volume: 1, duration: 0.05)
        _ = try render(player, frames: 4096)
        try player.play(notes: [67], instrument: .strings, volume: 1, duration: 5)
        try await Task.sleep(nanoseconds: 100_000_000)
        let replacement = try render(player, frames: 22_050)
        check(replacement > 0.00001, "Old timer must not stop replacement")
        player.stop()
        _ = try render(player, frames: 4096)
        let hardStopped = try render(player, frames: 4096)
        check(hardStopped < 0.00001, "Hard stop must silence replacement")
        do { try player.play(notes: [], instrument: .piano, volume: 1, duration: 1); fatalError("Empty notes accepted") } catch is ChordAudioPlayer.PlaybackError {}
        do { try player.play(notes: [128], instrument: .piano, volume: 1, duration: 1); fatalError("Invalid note accepted") } catch is ChordAudioPlayer.PlaybackError {}
        do { try player.play(notes: [60], instrument: .piano, volume: 1, duration: .infinity); fatalError("Invalid duration accepted") } catch is ChordAudioPlayer.PlaybackError {}
        print("Offline audio tests passed for piano, electric piano, guitar and strings.")
    }
}
