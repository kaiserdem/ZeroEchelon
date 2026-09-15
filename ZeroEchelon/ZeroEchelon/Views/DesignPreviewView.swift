import SwiftUI

/// Design lab archive. Product UI is locked to `.civic` (`CivicTheme`).
enum DesignProposal: String, CaseIterable, Identifiable {
    case instrument
    case guide
    case civic

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .instrument: "A Прилад"
        case .guide: "B Гід"
        case .civic: "C Сигнал ✓"
        }
    }

    var subtitle: String {
        switch self {
        case .instrument: "Архів · не використовується в продукті"
        case .guide: "Архів · не використовується в продукті"
        case .civic: "Зафіксовано для iOS + web (Line 24 UI kit)"
        }
    }
}

private struct DesignTokens {
    var canvas: Color
    var surface: Color
    var ink: Color
    var muted: Color
    var accent: Color
    var danger: Color
    var warning: Color
    var antiFill: Color
    var barFill: Color
    var voiceFont: Font
    var helperFont: Font
    var buttonFont: Font
    var badgeFont: Font
    var corner: CGFloat
    var buttonCorner: CGFloat
    var buttonFill: Color
    var buttonInk: Color
    var secondaryButtonFill: Color
    var secondaryButtonInk: Color
    var topBarStyle: TopBarStyle
    var emergencyLabel: Font
    var emergencyTitle: Font

    enum TopBarStyle {
        case industrial
        case soft
        case civic
    }

    static func tokens(for proposal: DesignProposal) -> DesignTokens {
        switch proposal {
        case .instrument:
            return DesignTokens(
                canvas: Color(red: 0.93, green: 0.935, blue: 0.94),
                surface: Color(red: 1.0, green: 1.0, blue: 1.0),
                ink: Color(red: 0.06, green: 0.07, blue: 0.09),
                muted: Color(red: 0.35, green: 0.37, blue: 0.40),
                accent: Color(red: 0.08, green: 0.28, blue: 0.55),
                danger: Color(red: 0.86, green: 0.10, blue: 0.12),
                warning: Color(red: 0.92, green: 0.45, blue: 0.05),
                antiFill: Color(red: 1.0, green: 0.92, blue: 0.90),
                barFill: Color(red: 0.88, green: 0.89, blue: 0.90),
                voiceFont: .system(size: 34, weight: .heavy, design: .default),
                helperFont: .system(size: 16, weight: .medium, design: .default),
                buttonFont: .system(size: 20, weight: .bold, design: .default),
                badgeFont: .system(size: 12, weight: .bold, design: .monospaced),
                corner: 4,
                buttonCorner: 6,
                buttonFill: Color(red: 0.08, green: 0.28, blue: 0.55),
                buttonInk: .white,
                secondaryButtonFill: Color(red: 0.18, green: 0.20, blue: 0.23),
                secondaryButtonInk: .white,
                topBarStyle: .industrial,
                emergencyLabel: .system(size: 11, weight: .semibold, design: .monospaced),
                emergencyTitle: .system(size: 22, weight: .heavy, design: .default)
            )
        case .guide:
            return DesignTokens(
                canvas: Color(red: 0.97, green: 0.95, blue: 0.91),
                surface: Color(red: 0.99, green: 0.98, blue: 0.95),
                ink: Color(red: 0.18, green: 0.16, blue: 0.14),
                muted: Color(red: 0.45, green: 0.40, blue: 0.35),
                accent: Color(red: 0.22, green: 0.42, blue: 0.38),
                danger: Color(red: 0.72, green: 0.22, blue: 0.18),
                warning: Color(red: 0.78, green: 0.48, blue: 0.18),
                antiFill: Color(red: 0.96, green: 0.90, blue: 0.86),
                barFill: Color(red: 0.94, green: 0.91, blue: 0.86),
                voiceFont: .system(size: 32, weight: .semibold, design: .serif),
                helperFont: .system(size: 16, weight: .regular, design: .serif),
                buttonFont: .system(size: 19, weight: .semibold, design: .rounded),
                badgeFont: .system(size: 12, weight: .semibold, design: .rounded),
                corner: 16,
                buttonCorner: 18,
                buttonFill: Color(red: 0.22, green: 0.42, blue: 0.38),
                buttonInk: .white,
                secondaryButtonFill: Color(red: 0.90, green: 0.86, blue: 0.80),
                secondaryButtonInk: Color(red: 0.18, green: 0.16, blue: 0.14),
                topBarStyle: .soft,
                emergencyLabel: .system(size: 12, weight: .medium, design: .rounded),
                emergencyTitle: .system(size: 21, weight: .bold, design: .rounded)
            )
        case .civic:
            return DesignTokens(
                canvas: Color.white,
                surface: Color.white,
                ink: Color(red: 1 / 255, green: 15 / 255, blue: 23 / 255),
                muted: Color(red: 91 / 255, green: 97 / 255, blue: 127 / 255),
                accent: Color(red: 8 / 255, green: 50 / 255, blue: 74 / 255),
                danger: Color(red: 128 / 255, green: 23 / 255, blue: 23 / 255),
                warning: Color(red: 0.95, green: 0.72, blue: 0.08),
                antiFill: Color(red: 128 / 255, green: 23 / 255, blue: 23 / 255).opacity(0.06),
                barFill: Color.white,
                voiceFont: .system(size: 24, weight: .medium, design: .default),
                helperFont: .system(size: 15, weight: .regular, design: .default),
                buttonFont: .system(size: 15, weight: .semibold, design: .default),
                badgeFont: .system(size: 13, weight: .medium, design: .default),
                corner: 16,
                buttonCorner: 16,
                buttonFill: Color(red: 8 / 255, green: 50 / 255, blue: 74 / 255),
                buttonInk: .white,
                secondaryButtonFill: Color(red: 8 / 255, green: 50 / 255, blue: 74 / 255).opacity(0.06),
                secondaryButtonInk: Color(red: 8 / 255, green: 50 / 255, blue: 74 / 255),
                topBarStyle: .civic,
                emergencyLabel: .system(size: 13, weight: .medium, design: .default),
                emergencyTitle: .system(size: 17, weight: .semibold, design: .default)
            )
        }
    }
}

struct DesignPreviewView: View {
    var onOpenProtocol: () -> Void

    @State private var proposal: DesignProposal = .civic
    @State private var showVetoSample = false

    private var tokens: DesignTokens { .tokens(for: proposal) }

    var body: some View {
        VStack(spacing: 0) {
            labChrome
            MockProtocolScreen(
                tokens: tokens,
                proposal: proposal,
                isVeto: showVetoSample
            )
        }
        .background(tokens.canvas.ignoresSafeArea())
    }

    private var labChrome: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Дизайн-лабораторія")
                    .font(.headline)
                Spacer()
                Button("Протокол") {
                    onOpenProtocol()
                }
                .font(.subheadline.weight(.semibold))
            }

            Picker("Пропозиція", selection: $proposal) {
                ForEach(DesignProposal.allCases) { item in
                    Text(item.shortTitle).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Text(proposal.subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle(isOn: $showVetoSample) {
                Text(showVetoSample ? "Зразок: вето / небезпека" : "Зразок: звичайне питання")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }
}

private struct MockProtocolScreen: View {
    var tokens: DesignTokens
    var proposal: DesignProposal
    var isVeto: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(proposal == .guide ? 0.3 : 0.6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    badge

                    Text(voiceCopy)
                        .font(tokens.voiceFont)
                        .foregroundStyle(tokens.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    Text(helperCopy)
                        .font(tokens.helperFont)
                        .foregroundStyle(tokens.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if isVeto {
                        antiBanner
                    } else if proposal != .guide {
                        // Instrument & civic show a lighter caution chip on normal path too
                        if proposal == .instrument {
                            Label("НЕ зупиняйтесь на дрібних ранах", systemImage: "exclamationmark.square.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(tokens.danger)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(tokens.antiFill, in: RoundedRectangle(cornerRadius: tokens.corner))
                        }
                    }

                    if !isVeto {
                        actionButtons
                    } else {
                        vetoButtons
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }

            emergencyBar
        }
        .background(isVeto ? vetoCanvas : tokens.canvas)
    }

    private var vetoCanvas: Color {
        switch proposal {
        case .instrument: Color(red: 1.0, green: 0.96, blue: 0.92)
        case .guide: Color(red: 0.98, green: 0.94, blue: 0.90)
        case .civic: Color(red: 0.99, green: 0.96, blue: 0.95)
        }
    }

    private var voiceCopy: String {
        isVeto
            ? "Не підходьте. Є загроза. Викличте 101."
            : "Чи є сильна кровотеча?"
    }

    private var helperCopy: String {
        isVeto
            ? "Люди біля загрози — у звіті як недосяжні. Не йдіть допомагати."
            : "Один дотик = відповідь. 103 завжди внизу екрана."
    }

    private var badge: some View {
        HStack(spacing: 8) {
            Text(isVeto ? "S5a · ВЕТО" : "S8 · КРОВОТЕЧА")
                .font(tokens.badgeFont)
                .foregroundStyle(proposal == .civic ? tokens.accent : tokens.muted)
                .tracking(proposal == .instrument ? 1.2 : 0.4)
                .textCase(.uppercase)

            if proposal == .civic {
                Capsule()
                    .fill(tokens.warning)
                    .frame(width: 28, height: 6)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            switch tokens.topBarStyle {
            case .industrial:
                Text("НАЗАД")
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(tokens.ink)
                Spacer()
                Text("UA | EN")
                    .font(.caption.weight(.bold).monospaced())
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body.weight(.bold))
            case .soft:
                Label("Назад", systemImage: "chevron.backward")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tokens.muted)
                Spacer()
                Text("UA  ·  EN")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tokens.ink)
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(tokens.accent)
            case .civic:
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.bold))
                    .foregroundStyle(tokens.accent)
                Text("Назад")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tokens.accent)
                Spacer()
                HStack(spacing: 0) {
                    Text("UA")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tokens.accent, in: Capsule())
                        .foregroundStyle(.white)
                    Text("EN")
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .foregroundStyle(tokens.accent)
                }
                .background(tokens.secondaryButtonFill, in: Capsule())
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(tokens.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(tokens.canvas)
    }

    private var antiBanner: some View {
        Label("НЕ заходьте в небезпечну зону", systemImage: "exclamationmark.triangle.fill")
            .font(.title3.weight(.bold))
            .foregroundStyle(tokens.danger)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tokens.antiFill, in: RoundedRectangle(cornerRadius: tokens.corner))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            mockButton("Так", fill: tokens.buttonFill, ink: tokens.buttonInk)
            mockButton("Ні", fill: tokens.secondaryButtonFill, ink: tokens.secondaryButtonInk)
        }
        .padding(.top, 4)
    }

    private var vetoButtons: some View {
        VStack(spacing: 10) {
            mockButton("Відкрити звіт", fill: tokens.warning, ink: proposal == .civic ? tokens.ink : .white)
            mockButton("Далі без підходу", fill: tokens.secondaryButtonFill, ink: tokens.secondaryButtonInk)
        }
        .padding(.top, 4)
    }

    private func mockButton(_ title: String, fill: Color, ink: Color) -> some View {
        Text(title)
            .font(tokens.buttonFont)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, proposal == .instrument ? 18 : 16)
            .background(fill, in: RoundedRectangle(cornerRadius: tokens.buttonCorner))
            .overlay {
                if proposal == .instrument {
                    RoundedRectangle(cornerRadius: tokens.buttonCorner)
                        .stroke(tokens.ink.opacity(0.15), lineWidth: 1)
                }
            }
    }

    private var emergencyBar: some View {
        VStack(spacing: 8) {
            Text(isVeto
                 ? "Спочатку 101. 103 — якщо є поранені на безпечній відстані"
                 : "Екстрений виклик — завжди на екрані")
                .font(tokens.emergencyLabel)
                .foregroundStyle(tokens.muted)
                .multilineTextAlignment(.center)

            if isVeto {
                Text(proposal == .guide ? "Викликати 101 (ДСНС)" : "ВИКЛИКАТИ 101 (ДСНС)")
                    .font(tokens.emergencyTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(tokens.warning, in: RoundedRectangle(cornerRadius: tokens.buttonCorner))

                Text("Викликати 103")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tokens.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: tokens.buttonCorner)
                            .stroke(tokens.danger, lineWidth: 2)
                    }
            } else {
                Text(proposal == .guide ? "Викликати 103" : "ВИКЛИКАТИ 103")
                    .font(tokens.emergencyTitle)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, proposal == .instrument ? 20 : 17)
                    .background(tokens.danger, in: RoundedRectangle(cornerRadius: tokens.buttonCorner))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(tokens.barFill)
    }
}

#Preview("Design Lab") {
    DesignPreviewView(onOpenProtocol: {})
}
