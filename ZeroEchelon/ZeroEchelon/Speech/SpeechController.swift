import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class SpeechController: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var audioPlayer: AVAudioPlayer?
    private var speakTask: Task<Void, Never>?
    private var speakGeneration = 0

    @Published private(set) var isListening = false
    @Published private(set) var lastError: String?

    var canDictate: Bool {
        SFSpeechRecognizer.authorizationStatus() != .denied
            && SFSpeechRecognizer.authorizationStatus() != .restricted
    }

    func speak(_ text: String, language: String) {
        stopSpeakingOnly()
        stopDictation()
        lastError = nil

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Ukrainian: never use AVSpeech — without a real uk voice it reads Cyrillic with a Russian voice.
        if language.lowercased().hasPrefix("uk") {
            let generation = speakGeneration
            speakTask = Task { [weak self] in
                await self?.speakUkrainianOnline(trimmed, generation: generation)
            }
            return
        }

        speakWithAppleTTS(trimmed, language: language)
    }

    /// Status line for Settings — Ukrainian uses online neural TTS.
    static func voiceStatus(for language: String) -> (installed: Bool, name: String) {
        if language.lowercased().hasPrefix("uk") {
            return (true, "Українська (онлайн)")
        }
        guard let voice = preferredAppleVoice(for: language) else {
            return (false, "")
        }
        return (true, voice.name)
    }

    func stop() {
        stopSpeakingOnly()
        stopDictation()
    }

    private func stopSpeakingOnly() {
        speakGeneration += 1
        speakTask?.cancel()
        speakTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func speakUkrainianOnline(_ text: String, generation: Int) async {
        do {
            try configurePlaybackSession()
            let data = try await UkrainianOnlineTTS.audioData(for: text)
            guard !Task.isCancelled, generation == speakGeneration else { return }
            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            audioPlayer = player
            player.play()
        } catch is CancellationError {
            return
        } catch {
            guard generation == speakGeneration else { return }
            lastError = error.localizedDescription
        }
    }

    private func speakWithAppleTTS(_ text: String, language: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.preferredAppleVoice(for: language)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    private func configurePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private static func preferredAppleVoice(for language: String) -> AVSpeechSynthesisVoice? {
        let wanted = language.lowercased()
        let prefix = String(wanted.prefix(2))
        let matching = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            let code = voice.language.lowercased()
            return code == wanted || code.hasPrefix(prefix + "-") || code == prefix
        }
        return matching.max(by: { $0.quality.rawValue < $1.quality.rawValue })
            ?? AVSpeechSynthesisVoice(language: language)
    }

    /// Starts on-device speech recognition and streams partial results into `on partial`.
    func startDictation(locale: ContentLocale, onPartial: @escaping (String) -> Void) {
        lastError = nil
        stopSpeakingOnly()

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

            let micGranted = await Self.requestMicrophonePermission()
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

    private static func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                cont.resume(returning: granted)
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
