import AVFoundation
import Foundation

@MainActor
final class SpeechController {
    private let synthesizer = AVSpeechSynthesizer()
    var isEnabled = true

    func speak(_ text: String, language: String) {
        guard isEnabled else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
