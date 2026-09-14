import Foundation

enum AppPreferences {
    static let localeKey = "line24.locale"
    static let speakOnAppearKey = "line24.speakOnAppear"

    static var locale: ContentLocale {
        get {
            guard let raw = UserDefaults.standard.string(forKey: localeKey),
                  let value = ContentLocale(rawValue: raw)
            else { return .uk }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: localeKey) }
    }

    static var speakOnAppear: Bool {
        get {
            if UserDefaults.standard.object(forKey: speakOnAppearKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: speakOnAppearKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: speakOnAppearKey) }
    }
}

enum AppLegalLinks {
    static let privacy = URL(string: "https://kaiserdem.github.io/ZeroEchelon/legal/privacy.html")!
    static let support = URL(string: "https://kaiserdem.github.io/ZeroEchelon/legal/support.html")!
    static let terms = URL(string: "https://kaiserdem.github.io/ZeroEchelon/legal/terms.html")!
}
