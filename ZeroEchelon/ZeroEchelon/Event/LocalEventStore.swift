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
    var tourniquetOn: Date?
    var saltRedCount: Int
    var saltYellowCount: Int
    var saltGreenCount: Int

    static let maxRetentionAfterStart: TimeInterval = 48 * 60 * 60

    enum CodingKeys: String, CodingKey {
        case eventId, startedAt, reachedFormAt, sessionRole, incidentType
        case locationLine, locationLevel, steps, waveRemindersScheduled
        case tourniquetOn, saltRedCount, saltYellowCount, saltGreenCount
    }

    init(
        eventId: UUID,
        startedAt: Date,
        reachedFormAt: Date?,
        sessionRole: String?,
        incidentType: String?,
        locationLine: String?,
        locationLevel: Int?,
        steps: [ProtocolLogStep],
        waveRemindersScheduled: Bool,
        tourniquetOn: Date? = nil,
        saltRedCount: Int = 0,
        saltYellowCount: Int = 0,
        saltGreenCount: Int = 0
    ) {
        self.eventId = eventId
        self.startedAt = startedAt
        self.reachedFormAt = reachedFormAt
        self.sessionRole = sessionRole
        self.incidentType = incidentType
        self.locationLine = locationLine
        self.locationLevel = locationLevel
        self.steps = steps
        self.waveRemindersScheduled = waveRemindersScheduled
        self.tourniquetOn = tourniquetOn
        self.saltRedCount = saltRedCount
        self.saltYellowCount = saltYellowCount
        self.saltGreenCount = saltGreenCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        eventId = try c.decode(UUID.self, forKey: .eventId)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        reachedFormAt = try c.decodeIfPresent(Date.self, forKey: .reachedFormAt)
        sessionRole = try c.decodeIfPresent(String.self, forKey: .sessionRole)
        incidentType = try c.decodeIfPresent(String.self, forKey: .incidentType)
        locationLine = try c.decodeIfPresent(String.self, forKey: .locationLine)
        locationLevel = try c.decodeIfPresent(Int.self, forKey: .locationLevel)
        steps = try c.decodeIfPresent([ProtocolLogStep].self, forKey: .steps) ?? []
        waveRemindersScheduled = try c.decodeIfPresent(Bool.self, forKey: .waveRemindersScheduled) ?? false
        tourniquetOn = try c.decodeIfPresent(Date.self, forKey: .tourniquetOn)
        saltRedCount = try c.decodeIfPresent(Int.self, forKey: .saltRedCount) ?? 0
        saltYellowCount = try c.decodeIfPresent(Int.self, forKey: .saltYellowCount) ?? 0
        saltGreenCount = try c.decodeIfPresent(Int.self, forKey: .saltGreenCount) ?? 0
    }

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
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let record = try? decoder.decode(LocalEventRecord.self, from: data) else {
            // Fallback for records written with the default Date encoding.
            guard let legacy = try? JSONDecoder().decode(LocalEventRecord.self, from: data) else {
                clear()
                return nil
            }
            if legacy.isExpired(now: now) {
                clear()
                return nil
            }
            save(legacy)
            return legacy
        }
        if record.isExpired(now: now) {
            clear()
            return nil
        }
        return record
    }

    static func save(_ record: LocalEventRecord) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(record)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("LocalEventStore.save failed: \(error)")
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Test helper — write/read against an explicit URL.
    static func save(_ record: LocalEventRecord, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(record)
        try data.write(to: url, options: [.atomic])
    }

    static func load(from url: URL, now: Date = Date()) throws -> LocalEventRecord? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let record = try decoder.decode(LocalEventRecord.self, from: data)
        if record.isExpired(now: now) { return nil }
        return record
    }
}
