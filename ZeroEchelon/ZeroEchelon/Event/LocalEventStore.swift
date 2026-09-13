import Foundation

/// Single offline event slot — not a multi-incident history (docs/06, docs/12).
struct LocalEventRecord: Codable, Equatable, Sendable {
    var eventId: UUID
    var startedAt: Date
    var reachedFormAt: Date?
    var sessionRole: String?
    var incidentType: String?
    var locationLine: String?
    var locationLevel: Int?
    var steps: [ProtocolLogStep]
    var waveRemindersScheduled: Bool

    static let maxRetentionAfterStart: TimeInterval = 48 * 60 * 60

    func isExpired(now: Date = Date()) -> Bool {
        now.timeIntervalSince(startedAt) > Self.maxRetentionAfterStart
    }
}

enum LocalEventStore {
    private static let fileName = "local-event.json"

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = dir.appendingPathComponent("Line24", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent(fileName)
    }

    static func load(now: Date = Date()) -> LocalEventRecord? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let record = try? JSONDecoder().decode(LocalEventRecord.self, from: data) else {
            clear()
            return nil
        }
        if record.isExpired(now: now) {
            clear()
            return nil
        }
        return record
    }

    static func save(_ record: LocalEventRecord) {
        guard let data = try? JSONEncoder().encode(record) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test helper — write/read against an explicit URL.
    static func save(_ record: LocalEventRecord, to url: URL) throws {
        let data = try JSONEncoder().encode(record)
        try data.write(to: url, options: [.atomic])
    }

    static func load(from url: URL, now: Date = Date()) throws -> LocalEventRecord? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let record = try JSONDecoder().decode(LocalEventRecord.self, from: data)
        if record.isExpired(now: now) { return nil }
        return record
    }
}
