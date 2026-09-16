import AVFoundation
import Foundation

/// Fetches Ukrainian speech audio (never Russian). Used when system TTS mis-speaks `uk` text.
enum UkrainianOnlineTTS {
    /// Google Translate TTS — `tl=uk` forces a Ukrainian voice (not `ru`).
    static func audioData(for text: String) async throws -> Data {
        let chunks = chunk(text, maxLength: 160)
        var combined = Data()
        for piece in chunks {
            try Task.checkCancellation()
            let data = try await fetchChunk(piece)
            combined.append(data)
        }
        guard !combined.isEmpty else {
            throw TTSError.emptyAudio
        }
        return combined
    }

    private static func fetchChunk(_ text: String) async throws -> Data {
        var components = URLComponents(string: "https://translate.googleapis.com/translate_tts")!
        components.queryItems = [
            URLQueryItem(name: "ie", value: "UTF-8"),
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "tl", value: "uk"),
            URLQueryItem(name: "q", value: text),
        ]
        guard let url = components.url else { throw TTSError.badURL }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 15_8 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw TTSError.httpFailed
        }
        guard data.count > 64 else { throw TTSError.emptyAudio }
        return data
    }

    /// Splits on sentence ends / spaces so each request stays under the TTS length limit.
    static func chunk(_ text: String, maxLength: Int) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }
        guard normalized.count > maxLength else { return [normalized] }

        var parts: [String] = []
        var current = ""
        let tokens = normalized.components(separatedBy: " ")
        for token in tokens {
            let next = current.isEmpty ? token : current + " " + token
            if next.count <= maxLength {
                current = next
                continue
            }
            if !current.isEmpty {
                parts.append(current)
            }
            if token.count > maxLength {
                var rest = token
                while rest.count > maxLength {
                    let idx = rest.index(rest.startIndex, offsetBy: maxLength)
                    parts.append(String(rest[..<idx]))
                    rest = String(rest[idx...])
                }
                current = rest
            } else {
                current = token
            }
        }
        if !current.isEmpty {
            parts.append(current)
        }
        return parts
    }

    enum TTSError: LocalizedError {
        case badURL
        case httpFailed
        case emptyAudio

        var errorDescription: String? {
            switch self {
            case .badURL: "Невірна адреса озвучення"
            case .httpFailed: "Не вдалося завантажити український голос (потрібен інтернет)"
            case .emptyAudio: "Порожня відповідь озвучення"
            }
        }
    }
}
