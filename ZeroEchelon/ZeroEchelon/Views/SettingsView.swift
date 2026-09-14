import SwiftUI

struct SettingsView: View {
    @Binding var locale: ContentLocale
    @Binding var speakOnAppear: Bool
    @Environment(\.dismiss) private var dismiss

    private var isUkrainian: Bool { locale == .uk }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker(isUkrainian ? "Мова" : "Language", selection: $locale) {
                        Text("Українська").tag(ContentLocale.uk)
                        Text("English").tag(ContentLocale.en)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .onChange(of: locale) { _, newValue in
                        AppPreferences.locale = newValue
                    }

                    Toggle(isUkrainian ? "Озвучення екранів" : "Speak screens aloud", isOn: $speakOnAppear)
                        .tint(CivicTheme.accent)
                        .onChange(of: speakOnAppear) { _, newValue in
                            AppPreferences.speakOnAppear = newValue
                        }
                } header: {
                    Text(isUkrainian ? "Інтерфейс" : "Interface")
                }

                Section {
                    Link(destination: AppLegalLinks.privacy) {
                        labelRow(
                            title: isUkrainian ? "Політика конфіденційності" : "Privacy Policy",
                            systemImage: "hand.raised.fill"
                        )
                    }
                    Link(destination: AppLegalLinks.support) {
                        labelRow(
                            title: isUkrainian ? "Підтримка" : "Support",
                            systemImage: "questionmark.circle.fill"
                        )
                    }
                    Link(destination: AppLegalLinks.terms) {
                        labelRow(
                            title: isUkrainian ? "Умови користування" : "Terms of Use",
                            systemImage: "doc.text.fill"
                        )
                    }
                } header: {
                    Text(isUkrainian ? "Про додаток" : "About")
                } footer: {
                    Text(versionFooter)
                        .font(.footnote)
                        .foregroundStyle(CivicTheme.muted)
                }
            }
            .navigationTitle(isUkrainian ? "Налаштування" : "Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(isUkrainian ? "Готово" : "Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func labelRow(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .foregroundStyle(CivicTheme.accent)
    }

    private var versionFooter: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return isUkrainian
            ? "Line 24 · версія \(short) (\(build))"
            : "Line 24 · version \(short) (\(build))"
    }
}

#Preview {
    SettingsView(locale: .constant(.uk), speakOnAppear: .constant(true))
}
