import SwiftUI
import UIKit

struct SettingsView: View {
    @Binding var locale: ContentLocale
    @Binding var speakOnAppear: Bool
    var onClose: () -> Void

    @State private var showLanguage = false

    private var isUkrainian: Bool { locale == .uk }

    private var voiceStatus: (installed: Bool, name: String) {
        SpeechController.voiceStatus(for: locale.speechLanguageCode)
    }

    var body: some View {
        Group {
            if showLanguage {
                LanguageSettingsView(
                    locale: $locale,
                    onClose: { showLanguage = false }
                )
            } else {
                settingsRoot
            }
        }
    }

    private var settingsRoot: some View {
        VStack(spacing: 0) {
            settingsChrome(
                title: isUkrainian ? "Налаштування" : "Settings",
                backTitle: isUkrainian ? "Назад" : "Back",
                action: onClose
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    settingsBlock(title: isUkrainian ? "Інтерфейс" : "Interface") {
                        Button {
                            showLanguage = true
                        } label: {
                            settingsNavRow(
                                title: isUkrainian ? "Мова" : "Language",
                                value: locale.displayName
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().overlay(CivicTheme.border.opacity(0.5))

                        Toggle(isOn: $speakOnAppear) {
                            Text(isUkrainian ? "Озвучення екранів" : "Speak screens aloud")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(CivicTheme.ink)
                        }
                        .tint(CivicTheme.success)
                        .padding(.vertical, 4)
                        .onChange(of: speakOnAppear) { newValue in
                            AppPreferences.speakOnAppear = newValue
                        }

                        Divider().overlay(CivicTheme.border.opacity(0.5))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(isUkrainian ? "Голос озвучення" : "Spoken voice")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(CivicTheme.ink)

                            Text(voiceStatusLine)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(CivicTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)

                            if !voiceStatus.installed {
                                Text(voiceInstallHint)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(CivicTheme.ink.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } label: {
                                    Text(isUkrainian ? "Відкрити Налаштування iPhone" : "Open iPhone Settings")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(CivicTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 10)
                    }

                    settingsBlock(title: isUkrainian ? "Про додаток" : "About") {
                        Link(destination: AppLegalLinks.privacy) {
                            settingsLinkRow(
                                title: isUkrainian ? "Політика конфіденційності" : "Privacy Policy"
                            )
                        }
                        Divider().overlay(CivicTheme.border.opacity(0.5))
                        Link(destination: AppLegalLinks.support) {
                            settingsLinkRow(
                                title: isUkrainian ? "Підтримка" : "Support"
                            )
                        }
                        Divider().overlay(CivicTheme.border.opacity(0.5))
                        Link(destination: AppLegalLinks.terms) {
                            settingsLinkRow(
                                title: isUkrainian ? "Умови користування" : "Terms of Use"
                            )
                        }
                    }

                    Text(versionFooter)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CivicTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .background(CivicTheme.canvas.ignoresSafeArea())
        .tint(CivicTheme.accent)
    }

    private func settingsChrome(title: String, backTitle: String, action: @escaping () -> Void) -> some View {
        SettingsChromeBar(title: title, backTitle: backTitle, action: action)
    }

    private func settingsBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CivicTheme.muted)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                CivicTheme.secondaryFill,
                in: RoundedRectangle(cornerRadius: CivicTheme.corner)
            )
        }
    }

    private func settingsNavRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CivicTheme.ink)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(CivicTheme.muted)
            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CivicTheme.muted)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func settingsLinkRow(title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CivicTheme.accent)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CivicTheme.muted)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private var versionFooter: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return isUkrainian
            ? "Line 24 · версія \(short) (\(build))"
            : "Line 24 · version \(short) (\(build))"
    }

    private var voiceStatusLine: String {
        if voiceStatus.installed {
            return isUkrainian
                ? "Зараз: \(voiceStatus.name). Потрібен інтернет."
                : "Using: \(voiceStatus.name)"
        }
        return isUkrainian
            ? "Український голос недоступний."
            : "No system voice is installed for this language."
    }

    private var voiceInstallHint: String {
        if isUkrainian {
            return "Озвучення українською йде через окремий онлайн-голос (не системний російський TTS)."
        }
        return "Download a system voice in Settings → Accessibility → Spoken Content → Voices."
    }
}

struct LanguageSettingsView: View {
    @Binding var locale: ContentLocale
    var onClose: () -> Void

    private var isUkrainian: Bool { locale == .uk }

    var body: some View {
        VStack(spacing: 0) {
            SettingsChromeBar(
                title: isUkrainian ? "Мова" : "Language",
                backTitle: isUkrainian ? "Назад" : "Back",
                action: onClose
            )

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isUkrainian ? "Оберіть мову додатку" : "Choose app language")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(CivicTheme.muted)
                        .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(ContentLocale.allCases, id: \.self) { option in
                            if option != ContentLocale.allCases.first {
                                Divider().overlay(CivicTheme.border.opacity(0.5))
                            }
                            Button {
                                locale = option
                                AppPreferences.locale = option
                            } label: {
                                HStack {
                                    Text(option.displayName)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(CivicTheme.ink)
                                    Spacer()
                                    if locale == option {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(CivicTheme.accent)
                                    }
                                }
                                .padding(.vertical, 18)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(
                        CivicTheme.secondaryFill,
                        in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .background(CivicTheme.canvas.ignoresSafeArea())
    }
}

/// Centered title that stays on one line on narrow phones (e.g. iPhone 7).
private struct SettingsChromeBar: View {
    var title: String
    var backTitle: String
    var action: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CivicTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 96)

            HStack(spacing: 0) {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.bold))
                        Text(backTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(CivicTheme.muted)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(locale: .constant(.uk), speakOnAppear: .constant(true), onClose: {})
    }
}
#endif
