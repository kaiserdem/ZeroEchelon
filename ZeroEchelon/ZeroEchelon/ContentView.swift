import SwiftUI
import UserNotifications

@Observable
@MainActor
final class AppModel {
    var engine: ProtocolEngine?
    var loadError: String?
    var speech = SpeechController()
    var speakOnAppear = AppPreferences.speakOnAppear

    private let waveScheduler = WaveReminderScheduler()

    func load() {
        do {
            let package = try GraphLoader.loadBundledPackage()
            let engine = try ProtocolEngine(package: package, locale: AppPreferences.locale)
            try engine.skipEntrySplashIfNeeded()

            if let record = LocalEventStore.load() {
                engine.hydrate(from: record)
            } else {
                Task { await waveScheduler.cancelWaveReminders() }
            }

            self.engine = engine
            speakOnAppear = AppPreferences.speakOnAppear
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
            persistAfterSelection(result)
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    func openLastReport() {
        guard let engine else { return }
        do {
            try engine.openLastReport()
        } catch {
            assertionFailure(String(describing: error))
        }
    }

    /// Flush journal before suspension — do not wait on notification permission.
    func persistNow() {
        guard let engine, let snapshot = engine.makeEventSnapshot() else { return }
        LocalEventStore.save(snapshot)
    }

    private func persistAfterSelection(_ result: EdgeSelectionResult) {
        guard let engine else { return }

        if result.clearedLog {
            LocalEventStore.clear()
            Task { await waveScheduler.cancelWaveReminders() }
            try? engine.reset()
            return
        }

        // Save first (sync). Notification permission must not block the journal.
        if let snapshot = engine.makeEventSnapshot() {
            LocalEventStore.save(snapshot)
        }

        guard result.shouldScheduleWaveReminders, let startedAt = engine.eventStartedAt else { return }
        Task {
            await waveScheduler.scheduleWaveReminders(startedAt: startedAt, locale: engine.locale)
            engine.markWaveRemindersScheduled()
            if let snapshot = engine.makeEventSnapshot() {
                LocalEventStore.save(snapshot)
            }
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let engine = model.engine {
                NodeFrameView(
                    engine: engine,
                    speech: model.speech,
                    speakOnAppear: $model.speakOnAppear,
                    onSelect: { model.handleEdge($0) },
                    onOpenLastReport: { model.openLastReport() }
                )
            } else if let loadError = model.loadError {
                ContentUnavailableView(
                    "Граф не завантажився",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadError)
                )
                .foregroundStyle(CivicTheme.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(CivicTheme.canvas)
            } else {
                ProgressView("Завантаження протоколу…")
                    .tint(CivicTheme.accent)
                    .foregroundStyle(CivicTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CivicTheme.canvas)
            }
        }
        .task { model.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                model.persistNow()
            }
        }
    }
}

#Preview {
    ContentView()
}
