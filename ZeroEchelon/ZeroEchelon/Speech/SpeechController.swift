import AVFoundation
import Foundation
import Speech

@MainActor
@Observable
final class SpeechController {
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    private(set) var isListening = false
    private(set) var lastError: String?

    var canDictate: Bool {
        SFSpeechRecognizer.authorizationStatus() != .denied
            && SFSpeechRecognizer.authorizationStatus() != .restricted
    }

    func speak(_ text: String, language: String) {
        stopDictation()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        stopDictation()
    }

    /// Starts on-device speech recognition and streams partial results into `on partial`.
    func startDictation(locale: ContentLocale, onPartial: @escaping (String) -> Void) {
        lastError = nil
        synthesizer.stopSpeaking(at: .immediate)

        Task {
            let auth = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
                SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
            }
            guard auth == .authorized else {
                lastError = locale == .uk
                    ? "Немає дозволу на розпізнавання мови"
                    : "Speech recognition not allowed"
                return
            }

            let micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
            guard micGranted else {
                lastError = locale == .uk
                    ? "Немає доступу до мікрофона"
                    : "Microphone access denied"
                return
            }

            do {
                try beginRecognition(locale: locale, onPartial: onPartial)
            } catch {
                lastError = error.localizedDescription
                stopDictation()
            }
        }
    }

    func stopDictation() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    private func beginRecognition(locale: ContentLocale, onPartial: @escaping (String) -> Void) throws {
        stopDictation()

        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale.speechLanguageCode))
        guard let recognizer, recognizer.isAvailable else {
            throw DictationError.unavailable
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    onPartial(result.bestTranscription.formattedString)
                    if result.isFinal {
                        self.stopDictation()
                    }
                }
                if error != nil {
                    self.stopDictation()
                }
            }
        }
    }
}

private enum DictationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Speech recognition unavailable"
        }
    }
}
