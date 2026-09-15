import SwiftUI
import UIKit

/// Line 24 visual system — tokens from Figma UI kit (navy / danger / Inter ramp via SF).
enum CivicTheme {
    static let canvas = Color.white
    static let vetoCanvas = Color.white
    static let surface = Color.white
    /// Headings / primary text `#010F17`
    static let ink = Color(red: 1 / 255, green: 15 / 255, blue: 23 / 255)
    /// Secondary `#5B617F`
    static let muted = Color(red: 91 / 255, green: 97 / 255, blue: 127 / 255)
    /// Primary Dark Navy `#08324A`
    static let accent = Color(red: 8 / 255, green: 50 / 255, blue: 74 / 255)
    /// Tile labels `#292B3D`
    static let textPrimary = Color(red: 41 / 255, green: 43 / 255, blue: 61 / 255)
    /// Feedback / emergency `#801717`
    static let danger = Color(red: 128 / 255, green: 23 / 255, blue: 23 / 255)
    /// Voice-on accent `#0E7B46`
    static let success = Color(red: 14 / 255, green: 123 / 255, blue: 70 / 255)
    /// Kept for rare emphasis; kit prefers navy for veto CTAs
    static let warning = Color(red: 0.95, green: 0.72, blue: 0.08)
    static let antiFill = danger.opacity(0.06)
    static let antiBorder = danger.opacity(0.2)
    static let barFill = Color.white
    /// Navy @ 6%
    static let secondaryFill = accent.opacity(0.06)
    static let border = accent.opacity(0.2)

    static let corner: CGFloat = 16
    static let buttonCorner: CGFloat = 16
    static let pillCorner: CGFloat = 10

    static let voiceFont = Font.system(size: 28, weight: .semibold)
    static let helperFont = Font.system(size: 17, weight: .medium)
    static let buttonFont = Font.system(size: 20, weight: .bold)
    static let badgeFont = Font.system(size: 15, weight: .semibold)
    static let emergencyLabel = Font.system(size: 15, weight: .semibold)
    static let emergencyTitle = Font.system(size: 20, weight: .bold)
    static let typeLabelFont = Font.system(size: 15, weight: .semibold)
}

struct NodeFrameView: View {
    @Bindable var engine: ProtocolEngine
    var speech: SpeechController
    @Binding var speakOnAppear: Bool
    var onSelect: ((String) -> Void)?
    var onOpenLastReport: (() -> Void)?

    @State private var showSettings = false

    private var isVeto: Bool { engine.currentNode.veto }

    var body: some View {
        Group {
            if showSettings {
                SettingsView(
                    locale: $engine.locale,
                    speakOnAppear: $speakOnAppear,
                    onClose: { showSettings = false }
                )
            } else {
                protocolFrame
            }
        }
    }

    private var protocolFrame: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(engine.voiceText)
                        .font(CivicTheme.voiceFont)
                        .foregroundStyle(CivicTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let anti = engine.antiPatternText {
                        Label(anti, systemImage: "exclamationmark.triangle.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(CivicTheme.danger)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                CivicTheme.antiFill,
                                in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: CivicTheme.corner)
                                    .stroke(CivicTheme.antiBorder, lineWidth: 1)
                            }
                    }

                    if let detail = engine.detailBlock {
                        Text(detail)
                            .font(engine.currentNode.id == "Loc-2"
                                  ? .system(size: 32, weight: .bold, design: .rounded)
                                  : .system(size: 22, weight: .semibold))
                            .foregroundStyle(CivicTheme.ink)
                            .lineSpacing(4)
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                CivicTheme.secondaryFill,
                                in: RoundedRectangle(cornerRadius: CivicTheme.corner)
                            )
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
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                ],
                                spacing: 12
                            ) {
                                ForEach(engine.visibleButtons, id: \.id) { button in
                                    typeIconButton(button)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(Array(engine.visibleButtons.enumerated()), id: \.element.id) { index, button in
                                    actionButton(button, index: index)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)

                    if engine.currentNode.id == "Home",
                       let summary = engine.lastEventSummaryLine
                    {
                        lastEventCard(summary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
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
        .onChange(of: engine.locale) { _, newLocale in
            AppPreferences.locale = newLocale
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
                    .frame(maxWidth: 280, maxHeight: 280)
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
                     ? "QR зараз недоступний. Поверніться до звіту."
                     : "QR unavailable. Go back to the report.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CivicTheme.muted)
            }
        }
        .frame(maxWidth: .infinity)
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
                        .stroke(CivicTheme.border, lineWidth: 1.5)
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
                        .overlay {
                            if !speech.isListening {
                                RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                                    .stroke(CivicTheme.border, lineWidth: 1.5)
                            }
                        }
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

    @ViewBuilder
    private func typeIconButton(_ button: ProtocolButton) -> some View {
        let title = button.title(for: engine.locale)
        Button {
            handle(button.when)
        } label: {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 4) {
                        Spacer(minLength: 0)
                        Image("type_\(button.when)")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 40, maxHeight: 40)
                            .accessibilityHidden(true)

                        Text(title)
                            .font(CivicTheme.typeLabelFont)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CivicTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 4)
                }
                .background(
                    CivicTheme.secondaryFill,
                    in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private func actionButton(_ button: ProtocolButton, index: Int) -> some View {
        let primary = index == 0
        Button {
            handle(button.when)
        } label: {
            Text(button.title(for: engine.locale))
                .font(CivicTheme.buttonFont)
                .multilineTextAlignment(.center)
                .foregroundStyle(buttonInk(primary: primary))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .padding(.horizontal, 14)
                .background(
                    buttonFill(primary: primary),
                    in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                )
                .overlay {
                    if !primary && !isVeto {
                        RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                            .stroke(CivicTheme.border, lineWidth: 1.5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func buttonFill(primary: Bool) -> Color {
        if primary || isVeto { return CivicTheme.accent }
        return CivicTheme.surface
    }

    private func buttonInk(primary: Bool) -> Color {
        if primary || isVeto { return .white }
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
                        .foregroundStyle(CivicTheme.muted)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Line 24")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(CivicTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .frame(minWidth: 88, alignment: .leading)

            Spacer(minLength: 8)

            Button {
                speakOnAppear.toggle()
                AppPreferences.speakOnAppear = speakOnAppear
                if !speakOnAppear {
                    speech.stop()
                }
            } label: {
                Image(systemName: speakOnAppear ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(speakOnAppear ? CivicTheme.success : CivicTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        CivicTheme.secondaryFill,
                        in: RoundedRectangle(cornerRadius: CivicTheme.pillCorner)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.locale == .uk ? "Голос" : "Voice")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .foregroundStyle(CivicTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        CivicTheme.secondaryFill,
                        in: RoundedRectangle(cornerRadius: CivicTheme.pillCorner)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.locale == .uk ? "Налаштування" : "Settings")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(screenBackground)
    }

    private func lastEventCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(summary)
                .font(.headline.weight(.semibold))
                .foregroundStyle(CivicTheme.ink)

            if let line = engine.locationLine, !line.isEmpty {
                Text(line)
                    .font(CivicTheme.helperFont)
                    .foregroundStyle(CivicTheme.muted)
            }

            Button {
                onOpenLastReport?()
            } label: {
                Text(engine.locale == .uk ? "Відкрити звіт" : "Open report")
                    .font(CivicTheme.buttonFont)
                    .foregroundStyle(CivicTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        CivicTheme.secondaryFill,
                        in: RoundedRectangle(cornerRadius: CivicTheme.buttonCorner)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            CivicTheme.secondaryFill,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .contain)
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
        VStack(spacing: 0) {
            if prioritize101 {
                Text(locale == .uk
                     ? "Спочатку 101. 103 — якщо є поранені на безпечній відстані"
                     : "101 first. 103 — if casualties are at a safe distance")
                    .font(CivicTheme.emergencyLabel)
                    .foregroundStyle(CivicTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            if prioritize101, show101 {
                Button {
                    onDial("101")
                } label: {
                    Text(locale == .uk ? "ВИКЛИКАТИ 101 (ДСНС)" : "CALL 101 (rescue)")
                        .font(CivicTheme.emergencyTitle)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(CivicTheme.danger)
                }
                .buttonStyle(.plain)

                Button {
                    onDial("103")
                } label: {
                    Text(locale == .uk ? "Викликати 103" : "Call 103")
                        .font(.body.weight(.bold))
                        .foregroundStyle(CivicTheme.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(CivicTheme.antiBorder)
                                .frame(height: 1)
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
                        .padding(.vertical, emphasizeCall ? 26 : 22)
                        .background(CivicTheme.danger)
                }
                .buttonStyle(.plain)

                if show101 {
                    Button {
                        onDial("101")
                    } label: {
                        Text(locale == .uk ? "Викликати 101 (ДСНС)" : "Call 101 (rescue)")
                            .font(.body.weight(.bold))
                            .foregroundStyle(CivicTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(CivicTheme.secondaryFill)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .safeAreaPadding(.bottom, 8)
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
