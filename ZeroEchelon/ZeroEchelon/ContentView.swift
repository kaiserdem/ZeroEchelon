import SwiftUI
import UserNotifications

@Observable
@MainActor
final class AppModel {
    var engine: ProtocolEngine?
    var loadError: String?
    var speech = SpeechController()
    var speakOnAppear = true

    private let waveScheduler = WaveReminderScheduler()

    func load() {
        do {
            let package = try GraphLoader.loadBundledPackage()
            let engine = try ProtocolEngine(package: package, locale: .uk)
            try engine.skipEntrySplashIfNeeded()

            if let record = LocalEventStore.load() {
                engine.hydrate(from: record)
            } else {
                Task { await waveScheduler.cancelWaveReminders() }
            }

            self.engine = engine
            loadError = nil

            waveScheduler.onOpenWaveChecklist = { [weak self] in
                self?.openWaveFromNotification()
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func handleEdge(_ when: String) {
        guard let engine else { return }
        do {
            let result = try engine.select(edgeWhen: when)
            if let url = result.externalURL {
                UIApplication.shared.open(url)
            }
            Task { await applyPersistence(after: result) }
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    private func applyPersistence(after result: EdgeSelectionResult) async {
        guard let engine else { return }

        if result.clearedLog {
            LocalEventStore.clear()
            await waveScheduler.cancelWaveReminders()
            try? engine.reset()
            return
        }

        if result.shouldScheduleWaveReminders, let startedAt = engine.eventStartedAt {
            await waveScheduler.scheduleWaveReminders(startedAt: startedAt, locale: engine.locale)
            engine.markWaveRemindersScheduled()
        }

        if let snapshot = engine.makeEventSnapshot() {
            LocalEventStore.save(snapshot)
        }
    }

    private func openWaveFromNotification() {
        guard let engine else { return }
        do {
            try engine.openWaveChecklist()
        } catch {
            assertionFailure(String(describing: error))
        }
    }
}

struct ContentView: View {
    @State private var model = AppModel()

    var body: some View {
        Group {
            if let engine = model.engine {
                NodeFrameView(
                    engine: engine,
                    speech: model.speech,
                    speakOnAppear: $model.speakOnAppear,
                    onSelect: { model.handleEdge($0) }
                )
            } else if let loadError = model.loadError {
                ContentUnavailableView(
                    "Граф не завантажився",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
            } else {
                ProgressView("Завантаження протоколу…")
                    .tint(CivicTheme.accent)
            }
        }
        .task { model.load() }
    }
}

#Preview {
    ContentView()
}
