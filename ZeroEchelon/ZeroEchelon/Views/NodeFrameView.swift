import SwiftUI
import UIKit

struct NodeFrameView: View {
    @Bindable var engine: ProtocolEngine
    var speech: SpeechController
    @Binding var speakOnAppear: Bool

    private var isVeto: Bool { engine.currentNode.veto }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(engine.screenBadge)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(engine.voiceText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    if let helper = engine.helperText {
                        Text(helper)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let anti = engine.antiPatternText {
                        Label(anti, systemImage: "exclamationmark.triangle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.red)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let detail = engine.detailBlock {
                        Text(detail)
                            .font(engine.currentNode.id == "Loc-2"
                                  ? .system(size: 36, weight: .bold, design: .rounded)
                                  : .title3.weight(.medium))
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
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
                emphasizeCall: engine.currentNode.id == "Call"
            ) { number in
                dial(number)
            }
        }
        .background(isVeto ? Color.orange.opacity(0.08) : Color(.systemBackground))
        .onAppear { speakCurrent() }
        .onChange(of: engine.currentNode.id) { _, _ in
            speakCurrent()
        }
        .onChange(of: engine.locale) { _, _ in
            speakCurrent()
        }
    }

    @ViewBuilder
    private func actionButton(_ button: ProtocolButton, index: Int) -> some View {
        Button {
            handle(button.when)
        } label: {
            Text(button.title(for: engine.locale))
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(buttonTint(index: index))
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                engine.goBack()
            } label: {
                Label(
                    engine.locale == .uk ? "Назад" : "Back",
                    systemImage: "chevron.backward"
                )
                .font(.body.weight(.semibold))
                .labelStyle(.titleAndIcon)
            }
            .disabled(!engine.canGoBack)
            .opacity(engine.canGoBack ? 1 : 0.35)

            Spacer(minLength: 8)

            Picker("Language", selection: $engine.locale) {
                Text("UA").tag(ContentLocale.uk)
                Text("EN").tag(ContentLocale.en)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 120)

            Toggle(isOn: $speakOnAppear) {
                Image(systemName: speakOnAppear ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toggleStyle(.button)
            .accessibilityLabel(engine.locale == .uk ? "Голос" : "Voice")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func buttonTint(index: Int) -> Color {
        if isVeto { return .orange }
        if engine.currentNode.id == "Type" { return .blue }
        return index == 0 ? Color.accentColor : Color.accentColor.opacity(0.85)
    }

    private func speakCurrent() {
        guard speakOnAppear else { return }
        speech.speak(engine.voiceText, language: engine.locale.speechLanguageCode)
    }

    private func handle(_ when: String) {
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
    var emphasizeCall: Bool
    var onDial: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(locale == .uk
                 ? "Екстрений виклик — завжди на екрані"
                 : "Emergency call — always on screen")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                onDial("103")
            } label: {
                Text(locale == .uk ? "ВИКЛИКАТИ 103" : "CALL 103")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, emphasizeCall ? 20 : 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if show101 {
                Button {
                    onDial("101")
                } label: {
                    Text(locale == .uk ? "Викликати 101 (ДСНС)" : "Call 101 (rescue)")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(.bar)
    }
}
