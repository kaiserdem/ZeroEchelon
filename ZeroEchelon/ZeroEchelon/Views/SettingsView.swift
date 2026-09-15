import SwiftUI

struct SettingsView: View {
    @Binding var locale: ContentLocale
    @Binding var speakOnAppear: Bool
    var onClose: () -> Void

    @State private var showLanguage = false

    private var isUkrainian: Bool { locale == .uk }

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
                        .onChange(of: speakOnAppear) { _, newValue in
                            AppPreferences.speakOnAppear = newValue
                        }
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
        HStack(spacing: 12) {
            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.backward")
                        .font(.body.weight(.bold))
                    Text(backTitle)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(CivicTheme.muted)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CivicTheme.ink)

            Spacer(minLength: 8)

            Color.clear
                .frame(width: 88, height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private func settingsBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(CivicTheme.muted)
                .textCase(.uppercase)
                .tracking(0.6)
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
}

struct LanguageSettingsView: View {
    @Binding var locale: ContentLocale
    var onClose: () -> Void

    private var isUkrainian: Bool { locale == .uk }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onClose) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.bold))
                        Text(isUkrainian ? "Назад" : "Back")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(CivicTheme.muted)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 8)

                Text(isUkrainian ? "Мова" : "Language")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(CivicTheme.ink)

                Spacer(minLength: 8)

                Color.clear
                    .frame(width: 88, height: 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

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

#Preview {
    SettingsView(locale: .constant(.uk), speakOnAppear: .constant(true), onClose: {})
}
