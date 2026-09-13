import Foundation
import Testing
@testable import ZeroEchelon

@MainActor
struct LocalEventAndWaveTests {
    private func protocolRoot() -> URL {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("protocol/graphs/zero-echelon-core")
    }

    private func makeEngine() throws -> ProtocolEngine {
        let root = protocolRoot()
        let package = ProtocolPackage(
            graph: try GraphLoader.load(from: root.appendingPathComponent("graph.json")),
            rules: try GraphLoader.loadRules(from: root.appendingPathComponent("engine-rules.json"))
        )
        return try ProtocolEngine(package: package, locale: .uk)
    }

    @Test func waveTimingSkipsPastWindows() {
        let started = Date(timeIntervalSince1970: 1_000)
        let now = started.addingTimeInterval(30 * 60 * 60)
        let fires = WaveReminderTiming.futureFireDates(startedAt: started, now: now)
        #expect(fires.map(\.id) == [WaveReminderID.hours48])
    }

    @Test func waveTimingBothFuture() {
        let started = Date(timeIntervalSince1970: 1_000)
        let now = started.addingTimeInterval(60)
        let fires = WaveReminderTiming.futureFireDates(startedAt: started, now: now)
        #expect(fires.map(\.id) == [WaveReminderID.hours24, WaveReminderID.hours48])
    }

    @Test func storeRoundTripAndExpiry() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("line24-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let record = LocalEventRecord(
            eventId: UUID(),
            startedAt: Date(),
            reachedFormAt: Date(),
            sessionRole: "witness",
            incidentType: "explosion",
            locationLine: "Kyiv",
            locationLevel: 2,
            steps: [ProtocolLogStep(nodeId: "Home", edge: "incident")],
            waveRemindersScheduled: true
        )
        try LocalEventStore.save(record, to: url)
        let loaded = try LocalEventStore.load(from: url)
        #expect(loaded?.incidentType == "explosion")
        #expect(loaded?.steps.count == 1)

        let expired = LocalEventRecord(
            eventId: UUID(),
            startedAt: Date().addingTimeInterval(-49 * 60 * 60),
            reachedFormAt: nil,
            sessionRole: nil,
            incidentType: nil,
            locationLine: nil,
            locationLevel: nil,
            steps: [],
            waveRemindersScheduled: false
        )
        #expect(expired.isExpired())
        try LocalEventStore.save(expired, to: url)
        let gone = try LocalEventStore.load(from: url)
        #expect(gone == nil)
    }

    @Test func incidentStartsEvent() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        #expect(engine.eventStartedAt == nil)

        _ = try engine.select(edgeWhen: "incident")
        #expect(engine.eventStartedAt != nil)
        #expect(engine.currentNode.id == "Disclaimer")
        #expect(engine.makeEventSnapshot() != nil)
    }

    @Test func firstFormVisitRequestsWaveSchedule() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")
        try engine.setCurrentNodeForTesting("Ban")
        let result = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Form")
        #expect(result.shouldScheduleWaveReminders == true)
        #expect(engine.reachedFormAt != nil)
    }

    @Test func eraseNextClearsEvent() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")
        try engine.setCurrentNodeForTesting("Form")
        let openErase = try engine.select(edgeWhen: "erase")
        #expect(openErase.clearedLog == false)
        #expect(engine.hasPersistableEvent)
        #expect(engine.currentNode.id == "Erase")

        let cleared = try engine.select(edgeWhen: "next")
        #expect(cleared.clearedLog == true)
        #expect(engine.hasPersistableEvent == false)
        #expect(engine.steps.isEmpty)
    }

    @Test func openWaveChecklistLandsOnI0() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        try engine.openWaveChecklist()
        #expect(engine.currentNode.id == "I0")
    }
}
