import SwiftUI
import UIKit
import ZeroEchelonKit

struct NodeFrameView: View {
    @Bindable var engine: ProtocolEngine
    var speech: SpeechController
    @Binding var speakOnAppear: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(engine.voiceText)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    if let anti = engine.antiPatternText {
                        Text(anti)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color.red)
                    }

                    if engine.currentNode.ui?.showDispatcherDraft == true
                        || engine.currentNode.id == "Call"
                        || engine.currentNode.id == "CALL-read"
                    {
                        Text(engine.dispatcherDraft)
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                    }

                    if engine.currentNode.ui?.stub == true {
                        Text(engine.locale == .uk
                             ? "Кінець зрізу S0–S5b. Далі — S6 у наступній версії графа."
                             : "End of S0–S5b slice. S6 comes in the next graph version.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }

            VStack(spacing: 12) {
                ForEach(engine.visibleButtons) { button in
                    Button {
                        handle(button.when)
                    } label: {
                        Text(button.title(for: engine.locale))
                            .font(.title2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(engine.currentNode.veto ? .orange : .accentColor)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            EmergencyBar(engine: engine) { id in
                handleAlways(id)
            }
        }
        .background(engine.currentNode.veto ? Color.orange.opacity(0.08) : Color(.systemBackground))
        .onAppear { speakCurrent() }
        .onChange(of: engine.currentNode.id) { _, _ in
            speakCurrent()
        }
    }

    private var topBar: some View {
        HStack {
            Picker("Language", selection: $engine.locale) {
                Text("UA").tag(ContentLocale.uk)
                Text("EN").tag(ContentLocale.en)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            Spacer()

            Toggle(isOn: $speakOnAppear) {
                Image(systemName: speakOnAppear ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .toggleStyle(.button)
            .accessibilityLabel(engine.locale == .uk ? "Голос" : "Voice")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func speakCurrent() {
        guard speakOnAppear else { return }
        speech.speak(engine.voiceText, language: engine.locale.speechLanguageCode)
    }

    private func handle(_ when: String) {
        do {
            let result = try engine.select(edgeWhen: when)
            openExternalIfNeeded(result)
        } catch {
            // Prototype: ignore unknown edges silently after assert in debug
            assertionFailure(String(describing: error))
        }
    }

    private func handleAlways(_ id: String) {
        do {
            let result = try engine.openAlwaysAvailable(id: id)
            openExternalIfNeeded(result)
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    private func openExternalIfNeeded(_ result: EdgeSelectionResult) {
        if let url = result.externalURL {
            UIApplication.shared.open(url)
            // Return to previous node so the call strip is not a dead end.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                engine.finishExternalAndReturn()
            }
        }
    }
}

struct EmergencyBar: View {
    var engine: ProtocolEngine
    var onCall: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button {
                onCall("CALL-103")
            } label: {
                Text(engine.locale == .uk ? "ВИКЛИКАТИ 103" : "CALL 103")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            if engine.currentNode.veto || engine.currentNode.branch == "A" {
                Button {
                    onCall("CALL-101")
                } label: {
                    Text(engine.locale == .uk ? "Викликати 101" : "Call 101")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}
