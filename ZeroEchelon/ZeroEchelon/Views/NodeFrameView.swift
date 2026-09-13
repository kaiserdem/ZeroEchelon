import SwiftUI
import UIKit

/// Locked product visual system: Civic Signal (design proposal C).
enum CivicTheme {
    static let canvas = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let vetoCanvas = Color(red: 0.99, green: 0.96, blue: 0.95)
    static let surface = Color.white
    static let ink = Color(red: 0.05, green: 0.12, blue: 0.28)
    static let muted = Color(red: 0.32, green: 0.38, blue: 0.48)
    static let accent = Color(red: 0.05, green: 0.27, blue: 0.62)
    static let danger = Color(red: 0.85, green: 0.12, blue: 0.16)
    static let warning = Color(red: 0.95, green: 0.72, blue: 0.08)
    static let antiFill = Color(red: 1.0, green: 0.94, blue: 0.94)
    static let barFill = Color(red: 0.93, green: 0.94, blue: 0.97)
    static let secondaryFill = Color(red: 0.88, green: 0.91, blue: 0.96)

    static let corner: CGFloat = 10
    static let buttonCorner: CGFloat = 12

    static let voiceFont = Font.system(size: 33, weight: .bold)
    static let helperFont = Font.system(size: 16, weight: .medium)
    static let buttonFont = Font.system(size: 19, weight: .bold)
    static let badgeFont = Font.system(size: 11, weight: .bold)
    static let emergencyLabel = Font.system(size: 12, weight: .semibold)
    static let emergencyTitle = Font.system(size: 22, weight: .bold)
}

struct NodeFrameView: View {
    @Bindable var engine: ProtocolEngine
    var speech: SpeechController
    @Binding var speakOnAppear: Bool
    var onSelect: ((String) -> Void)?

    private var isVeto: Bool { engine.currentNode.veto }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.35)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    badge

                    Text(engine.voiceText)
                        .font(CivicTheme.voiceFont)
                        .foregroundStyle(CivicTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let anti = engine.antiPatternText {
                        Label(anti, systemImage: "exclamationmark.triangle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(CivicTheme.danger)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                CivicTheme.antiFill,
                                in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                            )
                    }

                    if let detail = engine.detailBlock {
                        Text(detail)
                            .font(engine.currentNode.id == "Loc-2"
                                  ? .system(size: 36, weight: .bold, design: .rounded)
                                  : .title3.weight(.semibold))
                            .foregroundStyle(CivicTheme.ink)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                CivicTheme.surface,
                                in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: CivicTheme.corner)
                                    .stroke(CivicTheme.secondaryFill, lineWidth: 1)
                            }
                    }

                    if engine.showsHandoverQR {
                        handoverQRBlock
                    }

                    if engine.isManualLocationEntry {
                        manualLocationInput
                    }

                    Group {
                        if engine.currentNode.id == "Type" {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10),
                                ],
                                spacing: 10
                            ) {
                                ForEach(Array(engine.visibleButtons.enumerated()), id: \.element.id) { index, button in
                                    actionButton(button, index: index)
                                }
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(engine.visibleButtons.enumerated()), id: \.element.id) { index, button in
                                    actionButton(button, index: index)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)

            EmergencyBar(
                locale: engine.locale,
                show101: engine.showsRescue101,
                prioritize101: engine.prioritize101,
                emphasizeCall: engine.currentNode.id == "Call"
            ) { number in
                dial(number)
            }
        }
        .background(screenBackground)
        .ignoresSafeArea(edges: .bottom)
        .onAppear { speakCurrent() }
        .onChange(of: engine.currentNode.id) { _, _ in
            speech.stopDictation()
            speakCurrent()
        }
        .onChange(of: engine.manualLocationFieldIndex) { _, _ in
            if engine.isManualLocationEntry {
                speakCurrent()
            }
        }
        .onChange(of: engine.locale) { _, _ in
            speakCurrent()
        }
    }

    private var handoverQRBlock: some View {
        VStack(spacing: 10) {
            if let image = QRCodeImage.make(from: engine.handoverQRPayload) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260, maxHeight: 260)
                    .padding(12)
                    .background(
                        Color.white,
                        in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                    )
                    .accessibilityLabel(engine.locale == .uk
                                        ? "QR-код звіту для медика"
                                        : "Report QR code for medic")
            } else {
                Text(engine.locale == .uk
                     ? "QR зараз недоступний. Покажіть текст вище."
                     : "QR unavailable. Show the text above.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(CivicTheme.muted)
            }

            Text(engine.locale == .uk
                 ? "Код містить текст звіту. Мережа не потрібна."
                 : "The code holds the report text. No network needed.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(CivicTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var manualLocationInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField(engine.manualLocationPlaceholder, text: Binding(
                    get: { engine.manualLocationDraft },
                    set: { engine.manualLocationDraft = $0 }
                ))
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .onSubmit { handle("next") }
                .padding(14)
                .background(
                    CivicTheme.surface,
                    in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: CivicTheme.corner)
                        .stroke(CivicTheme.accent.opacity(0.35), lineWidth: 1.5)
                }

                Button {
                    toggleDictation()
                } label: {
                    Image(systemName: speech.isListening ? "mic.fill" : "mic")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(speech.isListening ? Color.white : CivicTheme.accent)
                        .frame(width: 52, height: 52)
                        .background(
                            speech.isListening ? CivicTheme.danger : CivicTheme.secondaryFill,
                            in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(engine.locale == .uk ? "Диктовка" : "Dictate")
            }

            if let error = speech.lastError {
                Text(error)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(CivicTheme.danger)
            }
        }
    }

    private func toggleDictation() {
        if speech.isListening {
            speech.stopDictation()
            return
        }
        speech.startDictation(locale: engine.locale) { partial in
            engine.manualLocationDraft = partial
        }
    }

    private var screenBackground: Color {
        isVeto ? CivicTheme.vetoCanvas : CivicTheme.canvas
    }

    private var badge: some View {
        HStack(spacing: 8) {
            Text(engine.screenBadge)
                .font(CivicTheme.badgeFont)
                .foregroundStyle(CivicTheme.accent)
                .textCase(.uppercase)
                .tracking(0.6)

            Capsule()
                .fill(CivicTheme.warning)
                .frame(width: 28, height: 6)
        }
    }

    @ViewBuilder
    private func actionButton(_ button: ProtocolButton, index: Int) -> some View {
        let primary = index == 0 || engine.currentNode.id == "Type"
        Button {
            handle(button.when)
        } label: {
            Text(button.title(for: engine.locale))
                .font(CivicTheme.buttonFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(buttonInk(primary: primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .background(
                    buttonFill(primary: primary),
                    in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                )
        }
        .buttonStyle(.plain)
    }

    private func buttonFill(primary: Bool) -> Color {
        if isVeto { return CivicTheme.warning }
        if primary { return CivicTheme.accent }
        return CivicTheme.secondaryFill
    }

    private func buttonInk(primary: Bool) -> Color {
        if isVeto { return CivicTheme.ink }
        if primary { return .white }
        return CivicTheme.accent
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Group {
                if engine.canGoBack {
                    Button {
                        engine.goBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.backward")
                                .font(.body.weight(.bold))
                            Text(engine.locale == .uk ? "Назад" : "Back")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(CivicTheme.accent)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Line 24")
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(CivicTheme.accent)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .frame(minWidth: 88, alignment: .leading)

            Spacer(minLength: 8)

            localeCapsules

            Button {
                speakOnAppear.toggle()
            } label: {
                Image(systemName: speakOnAppear ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(CivicTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(CivicTheme.secondaryFill, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.locale == .uk ? "Голос" : "Voice")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(screenBackground)
    }

    private var localeCapsules: some View {
        HStack(spacing: 0) {
            localeChip(.uk, title: "UA")
            localeChip(.en, title: "EN")
        }
        .background(CivicTheme.secondaryFill, in: Capsule())
    }

    private func localeChip(_ locale: ContentLocale, title: String) -> some View {
        Button {
            engine.locale = locale
        } label: {
            Text(title)
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(engine.locale == locale ? Color.white : CivicTheme.accent)
                .background {
                    if engine.locale == locale {
                        Capsule().fill(CivicTheme.accent)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func speakCurrent() {
        guard speakOnAppear else { return }
        speech.speak(engine.voiceText, language: engine.locale.speechLanguageCode)
    }

    private func handle(_ when: String) {
        speech.stopDictation()
        if let onSelect {
            onSelect(when)
            return
        }
        do {
            let result = try engine.select(edgeWhen: when)
            if let url = result.externalURL {
                UIApplication.shared.open(url)
            }
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    private func dial(_ number: String) {
        guard let url = URL(string: "tel:\(number)") else { return }
        UIApplication.shared.open(url)
    }
}

struct EmergencyBar: View {
    var locale: ContentLocale
    var show101: Bool
    var prioritize101: Bool
    var emphasizeCall: Bool
    var onDial: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            if prioritize101 {
                Text(locale == .uk
                     ? "Спочатку 101. 103 — якщо є поранені на безпечній відстані"
                     : "101 first. 103 — if casualties are at a safe distance")
                    .font(CivicTheme.emergencyLabel)
                    .foregroundStyle(CivicTheme.muted)
                    .multilineTextAlignment(.center)
            }

            if prioritize101, show101 {
                Button {
                    onDial("101")
                } label: {
                    Text(locale == .uk ? "ВИКЛИКАТИ 101 (ДСНС)" : "CALL 101 (rescue)")
                        .font(CivicTheme.emergencyTitle)
                        .foregroundStyle(CivicTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            CivicTheme.warning,
                            in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onDial("103")
                } label: {
                    Text(locale == .uk ? "Викликати 103" : "Call 103")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(CivicTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                                .stroke(CivicTheme.danger, lineWidth: 2)
                        }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onDial("103")
                } label: {
                    Text(locale == .uk ? "ВИКЛИКАТИ 103" : "CALL 103")
                        .font(CivicTheme.emergencyTitle)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, emphasizeCall ? 20 : 17)
                        .background(
                            CivicTheme.danger,
                            in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                        )
                }
                .buttonStyle(.plain)

                if show101 {
                    Button {
                        onDial("101")
                    } label: {
                        Text(locale == .uk ? "Викликати 101 (ДСНС)" : "Call 101 (rescue)")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(CivicTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                CivicTheme.secondaryFill,
                                in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(CivicTheme.barFill)
    }
}

enum QRCodeImage {
    static func make(from string: String, scale: CGFloat = 10) -> UIImage? {
        let data = Data(string.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
