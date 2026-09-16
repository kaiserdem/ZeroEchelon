import Combine
import Foundation

struct ProtocolLogStep: Codable, Hashable, Sendable, Identifiable {
    var id: UUID
    var nodeId: String
    var edge: String?
    var at: Date

    init(id: UUID = UUID(), nodeId: String, edge: String?, at: Date = Date()) {
        self.id = id
        self.nodeId = nodeId
        self.edge = edge
        self.at = at
    }
}

struct EdgeSelectionResult: Sendable {
    var didNavigate: Bool
    var externalURL: URL?
    var clearedLog: Bool
    var shouldScheduleWaveReminders: Bool

    init(
        didNavigate: Bool,
        externalURL: URL? = nil,
        clearedLog: Bool = false,
        shouldScheduleWaveReminders: Bool = false
    ) {
        self.didNavigate = didNavigate
        self.externalURL = externalURL
        self.clearedLog = clearedLog
        self.shouldScheduleWaveReminders = shouldScheduleWaveReminders
    }
}

/// Pure navigation over the protocol graph. Policy remaps come from shared `EngineRules`.
final class ProtocolEngine: ObservableObject {
    private(set) var graph: ProtocolGraph
    private(set) var rules: EngineRules
    @Published private(set) var currentNode: ProtocolNode
    @Published var locale: ContentLocale
    @Published private(set) var sessionRole: SessionRole?
    @Published private(set) var incidentType: String?
    /// Location line captured from Loc-1 / Loc-2 / Loc-3 for the 103 draft.
    @Published private(set) var locationLine: String?
    @Published private(set) var locationLevel: Int?
    /// Draft text for the current Loc-3 field (bound to the text field).
    @Published var manualLocationDraft: String = ""
    /// Index into `manualLocationFieldKeys` while on Loc-3.
    @Published private(set) var manualLocationFieldIndex: Int = 0
    private var manualLocationValues: [String: String] = [:]
    @Published private(set) var steps: [ProtocolLogStep]
    @Published private(set) var unreachableMarked: Bool
    @Published private(set) var lastVetoNodeId: String?
    /// True after Count→many/unknown (SALT multi-casualty context).
    @Published private(set) var multipleCasualties: Bool

    /// Single offline event (docs/06). Nil until Home → incident.
    @Published private(set) var eventId: UUID?
    @Published private(set) var eventStartedAt: Date?
    @Published private(set) var reachedFormAt: Date?
    @Published private(set) var waveRemindersScheduled: Bool
    /// First confirmed tourniquet application (Tq → Tq-time).
    @Published private(set) var tourniquetOn: Date?
    @Published private(set) var saltRedCount: Int
    @Published private(set) var saltYellowCount: Int
    @Published private(set) var saltGreenCount: Int

    /// Seconds between scene re-checks while in care branches (overridable in tests).
    var sceneRecheckInterval: TimeInterval
    /// Clock injection for tests.
    var now: () -> Date = { Date() }
    @Published private(set) var lastSceneCheckAt: Date?

    private var returnStack: [String]
    private var history: [String]
    private var pendingRecheckEdge: String?
    private var suppressSceneRecheck = false

    private static let defaultManualFields = ["settlement", "street", "building", "entrance"]

    init(graph: ProtocolGraph, rules: EngineRules, locale: ContentLocale = .uk) throws {
        guard graph.commercial == false else {
            throw ProtocolGraphError.commercialInvariant
        }
        self.graph = graph
        self.rules = rules
        self.locale = locale
        self.sceneRecheckInterval = rules.sceneRecheck.intervalSeconds
        self.currentNode = try graph.entryNode
        self.sessionRole = nil
        self.incidentType = nil
        self.locationLine = nil
        self.locationLevel = nil
        self.manualLocationDraft = ""
        self.manualLocationFieldIndex = 0
        self.manualLocationValues = [:]
        self.steps = []
        self.unreachableMarked = false
        self.lastVetoNodeId = nil
        self.multipleCasualties = false
        self.eventId = nil
        self.eventStartedAt = nil
        self.reachedFormAt = nil
        self.waveRemindersScheduled = false
        self.tourniquetOn = nil
        self.saltRedCount = 0
        self.saltYellowCount = 0
        self.saltGreenCount = 0
        self.lastSceneCheckAt = nil
        self.pendingRecheckEdge = nil
        self.suppressSceneRecheck = false
        self.returnStack = []
        self.history = []
    }

    convenience init(package: ProtocolPackage, locale: ContentLocale = .uk) throws {
        try self.init(graph: package.graph, rules: package.rules, locale: locale)
    }

    /// Test helper: mark the last scene check at an absolute time.
    func setLastSceneCheckAtForTesting(_ date: Date?) {
        lastSceneCheckAt = date
    }

    /// Test helper: move the cursor without recording a step.
    func setCurrentNodeForTesting(_ id: String) throws {
        guard let node = graph.node(id: id) else {
            throw ProtocolGraphError.missingNode(id)
        }
        currentNode = node
    }

    /// Skip the silent Start splash — land on Home.
    func skipEntrySplashIfNeeded() throws {
        guard currentNode.id == "Start" else { return }
        _ = try select(edgeWhen: "next")
        history.removeAll()
        steps.removeAll()
    }

    var voiceText: String {
        switch currentNode.id {
        case "Loc-1":
            return locale == .uk
                ? "Місце з QR-коду на стіні:"
                : "Location from the wall QR code:"
        case "Loc-3":
            return manualLocationPrompt
        case "A6":
            return a6VoiceForIncidentType()
        case "NoCpr" where sessionRole == .casualty || !multipleCasualties:
            // P0 from audit: do not order "go to the next person" when there is no next / cannot leave
            return locale == .uk
                ? "Реанімація тут не допоможе. Залишайтесь. Натисніть 103 внизу."
                : "CPR will not help here. Stay. Tap 103 below."
        default:
            return currentNode.voice.text(for: locale)
        }
    }

    var isManualLocationEntry: Bool { currentNode.id == "Loc-3" }

    var manualLocationFieldKey: String {
        let keys = manualLocationFieldKeys
        guard keys.indices.contains(manualLocationFieldIndex) else {
            return keys.first ?? "settlement"
        }
        return keys[manualLocationFieldIndex]
    }

    var manualLocationPrompt: String {
        switch manualLocationFieldKey {
        case "settlement":
            return locale == .uk ? "Назвіть населений пункт." : "Name the town or city."
        case "street":
            return locale == .uk ? "Вулиця." : "Street."
        case "building":
            return locale == .uk ? "Номер будинку." : "Building number."
        case "entrance":
            return locale == .uk ? "Підʼїзд, поверх чи орієнтир." : "Entrance, floor, or landmark."
        default:
            return currentNode.voice.text(for: locale)
        }
    }

    var manualLocationPlaceholder: String {
        switch manualLocationFieldKey {
        case "settlement":
            return locale == .uk ? "наприклад, Бровари" : "e.g. Brovary"
        case "street":
            return locale == .uk ? "наприклад, вул. Київська" : "e.g. Kyivska St."
        case "building":
            return locale == .uk ? "наприклад, 12" : "e.g. 12"
        case "entrance":
            return locale == .uk ? "підʼїзд 3, поверх 2" : "entrance 3, floor 2"
        default:
            return ""
        }
    }

    /// Already confirmed fields, shown under the input on Loc-3.
    var manualLocationSummary: String? {
        guard isManualLocationEntry else { return nil }
        let parts = manualLocationFieldKeys.compactMap { key -> String? in
            guard let value = manualLocationValues[key], !value.isEmpty else { return nil }
            return value
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }

    private var manualLocationFieldKeys: [String] {
        let fromGraph = graph.node(id: "Loc-3")?.ui?.fields ?? []
        return fromGraph.isEmpty ? Self.defaultManualFields : fromGraph
    }

    /// Closing safety order before Call — wording depends on incident type.
    private func a6VoiceForIncidentType() -> String {
        switch incidentType {
        case "traffic":
            return locale == .uk
                ? "Не стійте на проїзджій частині. Увімкніть аварійку. Не чіпайте проводи."
                : "Do not stand in the roadway. Turn on hazard lights. Do not touch wires."
        case "fire":
            return locale == .uk
                ? "Не заходьте в дим і полумʼя. Тримайтеся з навітряного боку. Не відкривайте гарячі двері."
                : "Do not enter smoke or flames. Stay upwind. Do not open hot doors."
        case "chemical":
            return locale == .uk
                ? "Не чіпайте рідину і плями. Не нюхайте. Відійдіть проти вітру, якщо можете."
                : "Do not touch liquid or stains. Do not smell it. Move upwind if you can."
        case "household":
            return locale == .uk
                ? "Вимкніть джерело небезпеки, якщо це безпечно. Не ризикуйте зайвий раз."
                : "Turn off the hazard source if it is safe. Do not take extra risks."
        case "collapse", "explosion", "train", "shooting":
            return locale == .uk
                ? "Не заходьте всередину завалу. Не рухайте уламки."
                : "Do not enter the collapse. Do not move rubble."
        default:
            return currentNode.voice.text(for: locale)
        }
    }

    var antiPatternText: String? {
        currentNode.antiPattern?.text(for: locale)
    }

    /// Extra UI tips under the voice line — disabled (noise on emergency screens).
    var helperText: String? {
        guard currentNode.id == "Disclaimer" else { return nil }
        return locale == .uk
            ? "Цей застосунок лише підказує кроки — рішення ваші. Закон сам по собі вас за допомогу не захищає."
            : "This app only suggests steps — the decisions are yours. The law alone does not protect you for helping."
    }

    /// True on the medic handover screen — show an offline QR of the draft.
    var showsHandoverQR: Bool { currentNode.id == "Give" }

    /// Payload encoded into the handover QR (same text the medic sees / dispatcher hears).
    var handoverQRPayload: String { dispatcherDraft }

    var detailBlock: String? {
        switch currentNode.id {
        case "Loc-1":
            return demoAddressLine(for: locale)
        case "Loc-2":
            return demoCoordinatesDisplay
        case "Loc-3":
            return manualLocationSummary
        case "Call", "CALL-read", "Read":
            return dispatcherDraft
        case "Form", "Give":
            return nil
        default:
            if currentNode.ui?.showDispatcherDraft == true {
                return dispatcherDraft
            }
            return nil
        }
    }

    /// Structured brigade draft card on Form (Figma: «Чернетка для бригади»).
    var showsBrigadeReportCard: Bool { currentNode.id == "Form" }

    var brigadeReportTitle: String {
        locale == .uk ? "Чернетка для бригади" : "Draft for responders"
    }

    var brigadeReportFields: [(id: String, label: String, value: String)] {
        let dash = "—"
        let typeValue = localizedIncidentTypeLabel() ?? dash
        let placeValue = locationLine ?? dash
        let roleValue: String = {
            switch sessionRole {
            case .witness: locale == .uk ? "Свідок" : "Witness"
            case .casualty: locale == .uk ? "Постраждалий" : "Casualty"
            case nil: dash
            }
        }()
        let casualtiesValue = saltCasualtiesShort() ?? dash
        let tourniquetValue: String = {
            if let tq = tourniquetOn {
                return Self.clockFormatter(locale: locale).string(from: tq)
            }
            return locale == .uk ? "Не накладено" : "Not applied"
        }()
        let facts = keyFactLines()
        let keyValue = facts.isEmpty
            ? dash
            : facts.joined(separator: locale == .uk ? "; " : "; ")

        if locale == .uk {
            return [
                ("type", "Тип події", typeValue),
                ("place", "Місце", placeValue),
                ("role", "Роль", roleValue),
                ("casualties", "Постраждалі", casualtiesValue),
                ("tourniquet", "Час джгута", tourniquetValue),
                ("key", "Ключове", keyValue),
            ]
        }
        return [
            ("type", "Event type", typeValue),
            ("place", "Location", placeValue),
            ("role", "Role", roleValue),
            ("casualties", "Casualties", casualtiesValue),
            ("tourniquet", "Tourniquet time", tourniquetValue),
            ("key", "Key info", keyValue),
        ]
    }

    private func saltCasualtiesShort() -> String? {
        let red = saltRedCount
        let yellow = saltYellowCount
        let green = saltGreenCount
        let unreachable = unreachableMarked ? 1 : 0
        let total = red + yellow + green + unreachable
        guard total > 0 else { return nil }
        if locale == .uk {
            if total == 1 { return "Один" }
            var parts: [String] = []
            if red > 0 { parts.append("червоних \(red)") }
            if yellow > 0 { parts.append("жовтих \(yellow)") }
            if green > 0 { parts.append("зелених \(green)") }
            if unreachable > 0 { parts.append("недосяжних \(unreachable)") }
            return parts.isEmpty ? "Кілька" : parts.joined(separator: ", ")
        }
        if total == 1 { return "One" }
        var parts: [String] = []
        if red > 0 { parts.append("red \(red)") }
        if yellow > 0 { parts.append("yellow \(yellow)") }
        if green > 0 { parts.append("green \(green)") }
        if unreachable > 0 { parts.append("unreachable \(unreachable)") }
        return parts.isEmpty ? "Several" : parts.joined(separator: ", ")
    }

    private func demoAddressLine(for locale: ContentLocale) -> String {
        switch locale {
        case .uk: "Київська обл., м. Бровари, вул. Демо 12, підʼїзд 3"
        case .en: "Kyiv region, Brovary, Demo St. 12, entrance 3"
        }
    }

    private var demoCoordinatesDisplay: String { "50.51120° N\n30.79090° E" }
    private var demoCoordinatesDraft: String { "50.51120° N, 30.79090° E" }

    var screenBadge: String {
        currentNode.ui?.screenId ?? currentNode.id
    }

    var canGoBack: Bool {
        !history.isEmpty
    }

    /// Content actions only. Dial 103/101 live exclusively in the bottom emergency bar.
    var visibleButtons: [ProtocolButton] {
        var buttons = currentNode.primaryButtons(locale: locale)
            .filter { !["dial", "dial-101"].contains($0.when) }

        if currentNode.id == "Call" {
            switch sessionRole {
            case .casualty:
                buttons = buttons.filter { $0.when != "next" }
                // Rename sole continue button
                buttons = buttons.map { b in
                    guard b.when == "next-casualty" else { return b }
                    return ProtocolButton(when: b.when, ua: "Далі", en: "Next")
                }
            case .witness, nil:
                buttons = buttons.filter { $0.when != "next-casualty" }
                buttons = buttons.map { b in
                    guard b.when == "next" else { return b }
                    return ProtocolButton(when: b.when, ua: "Далі", en: "Next")
                }
            }
        }

        if currentNode.id == "Form" {
            // Top bar «Назад» covers history; never duplicate back-* here.
            // Always keep QR (give) — including after veto path Out/Cont/Out-trapped.
            buttons = buttons.filter { ["give", "handed", "wave", "erase"].contains($0.when) }
        }

        if currentNode.id == "Loc-3" {
            let isLast = manualLocationFieldIndex >= manualLocationFieldKeys.count - 1
            buttons = buttons.map { button in
                guard button.when == "next" else { return button }
                if isLast {
                    return ProtocolButton(when: "next", ua: "Далі", en: "Next")
                }
                return ProtocolButton(when: "next", ua: "Наступне поле", en: "Next field")
            }
        }

        // Top bar already has «Назад» — never duplicate content Back buttons.
        if canGoBack {
            buttons = buttons.filter { button in
                if button.when.hasPrefix("back-") { return false }
                let title = button.title(for: locale)
                return title != "Назад" && title != "Back"
            }
        }

        return buttons
    }

    /// Three or more peer choices (e.g. stroke / poison / bite) — all secondary (white).
    /// Home and Form keep the first action primary.
    var usesEqualChoiceButtons: Bool {
        guard !currentNode.veto else { return false }
        switch currentNode.id {
        case "Home", "Form":
            return false
        default:
            return visibleButtons.count >= 3
        }
    }

    var showsRescue101: Bool {
        currentNode.veto
            || currentNode.id == "CanLeave"
            || currentNode.branch == "A"
            || currentNode.id == "Form"
    }

    /// On veto screens, 101 is the primary emergency action.
    var prioritize101: Bool {
        currentNode.veto
            || currentNode.id == "CanLeave"
            || currentNode.id == rules.sceneRecheck.nodeId
    }

    var dispatcherDraft: String {
        var lines: [String] = []
        if let typeLabel = localizedIncidentTypeLabel() {
            lines.append(typeLabel + ".")
        }
        if let locationLine {
            lines.append(locationLine)
        }
        if let roleLabel = localizedRoleLabel() {
            lines.append(locale == .uk ? "Я \(roleLabel)." : "I am \(roleLabel).")
        }

        if let casualties = saltCasualtiesLine() {
            lines.append(casualties)
        }
        if let tq = tourniquetOn {
            lines.append(tourniquetLine(tq))
        }
        let facts = keyFactLines()
        if !facts.isEmpty {
            let joined = facts.joined(separator: "; ")
            lines.append(locale == .uk ? "Зроблено: \(joined)." : "Done: \(joined).")
        }
        lines.append(locale == .uk ? "Потрібна допомога." : "Help needed.")
        return lines.joined(separator: "\n")
    }

    /// Human label from Type (S2) buttons — never the raw edge id (`explosion` → «Вибух»).
    private func localizedIncidentTypeLabel() -> String? {
        guard let incidentType else { return nil }
        if let button = graph.node(id: "Type")?.ui?.buttons?.first(where: { $0.when == incidentType }) {
            return button.title(for: locale)
        }
        return incidentType
    }

    private func localizedRoleLabel() -> String? {
        switch sessionRole {
        case .witness: locale == .uk ? "цивільний свідок" : "civilian bystander"
        case .casualty: locale == .uk ? "постраждалий" : "casualty"
        case nil: nil
        }
    }

    private func saltCasualtiesLine() -> String? {
        let red = saltRedCount
        let yellow = saltYellowCount
        let green = saltGreenCount
        let unreachable = unreachableMarked ? 1 : 0
        guard red + yellow + green + unreachable > 0 else { return nil }
        if locale == .uk {
            var parts: [String] = []
            if red > 0 { parts.append("червоних \(red)") }
            if yellow > 0 { parts.append("жовтих \(yellow)") }
            if green > 0 { parts.append("зелених \(green)") }
            if unreachable > 0 { parts.append("недосяжних \(unreachable)") }
            return "Постраждалі: \(parts.joined(separator: ", "))."
        }
        var parts: [String] = []
        if red > 0 { parts.append("red \(red)") }
        if yellow > 0 { parts.append("yellow \(yellow)") }
        if green > 0 { parts.append("green \(green)") }
        if unreachable > 0 { parts.append("unreachable \(unreachable)") }
        return "Casualties: \(parts.joined(separator: ", "))."
    }

    private func tourniquetLine(_ date: Date) -> String {
        let time = Self.clockFormatter(locale: locale).string(from: date)
        return locale == .uk
            ? "Джгут накладено о \(time)."
            : "Tourniquet applied at \(time)."
    }

    private static func clockFormatter(locale: ContentLocale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale == .uk ? "uk_UA" : "en_GB")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    /// Short care facts from recent steps (max 3), not a full button log.
    private func keyFactLines() -> [String] {
        let labels = Self.keyFactLabels(locale: locale)
        var seen = Set<String>()
        var facts: [String] = []
        for step in steps.reversed() {
            guard let label = labels[step.nodeId], !seen.contains(step.nodeId) else { continue }
            seen.insert(step.nodeId)
            facts.append(label)
            if facts.count == 3 { break }
        }
        return facts.reversed()
    }

    private static func keyFactLabels(locale: ContentLocale) -> [String: String] {
        if locale == .uk {
            return [
                "C0": "масивна кровотеча",
                "C1": "тиск на рану",
                "Hold": "триває тиск",
                "Pack": "тампонада",
                "Tq": "джгут",
                "Tq-time": "час джгута",
                "Tq2": "другий джгут",
                "Still": "кровотеча після джгута",
                "Open": "відкрита рана грудей",
                "Burp": "клапан / «відрижка» плівки",
                "Crush": "завал / не звільняти",
                "NoCpr": "без СЛР",
                "NoResp": "не дихає",
                "Deleg": "делеговано тиск",
            ]
        }
        return [
            "C0": "massive bleeding",
            "C1": "direct pressure",
            "Hold": "holding pressure",
            "Pack": "wound packing",
            "Tq": "tourniquet",
            "Tq-time": "tourniquet time",
            "Tq2": "second tourniquet",
            "Still": "bleeding after tourniquet",
            "Open": "open chest wound",
            "Burp": "burp the seal",
            "Crush": "crush — do not release",
            "NoCpr": "no CPR",
            "NoResp": "not breathing",
            "Deleg": "pressure handed off",
        ]
    }

    func goBack() {
        guard let previousId = history.popLast(),
              let node = graph.node(id: previousId)
        else { return }
        currentNode = node
    }

    @discardableResult
    func select(edgeWhen: String) throws -> EdgeSelectionResult {
        if currentNode.id == "Form",
           edgeWhen == "back-out" || edgeWhen == "back-cont" || edgeWhen == "back-trapped"
        {
            let targetId: String
            switch edgeWhen {
            case "back-cont": targetId = "Cont"
            case "back-trapped": targetId = "Out-trapped"
            default: targetId = "Out"
            }
            return try navigate(to: targetId, edgeWhen: edgeWhen, pushReturn: false, recordHistory: true)
        }

        // Scene re-check interrupt (node id from shared engine-rules).
        if shouldInterceptForSceneRecheck {
            pendingRecheckEdge = edgeWhen
            return try navigate(
                to: rules.sceneRecheck.nodeId,
                edgeWhen: "recheck",
                pushReturn: true,
                recordHistory: true
            )
        }

        if currentNode.id == rules.sceneRecheck.nodeId {
            return try handleSceneRecheck(edgeWhen: edgeWhen)
        }

        if currentNode.id == "Loc-3", edgeWhen == "next" {
            return try handleManualLocationNext()
        }

        guard let edge = currentNode.edges.first(where: { $0.when == edgeWhen }) else {
            throw ProtocolGraphError.missingEdge(node: currentNode.id, when: edgeWhen)
        }

        captureSideEffects(edgeWhen: edgeWhen)

        if currentNode.id == "Home", edgeWhen == "incident" {
            beginEventIfNeeded()
        }

        var scheduleWave = false
        // Confirm on Erase → next only (do not wipe when opening the confirm screen).
        if currentNode.id == "Erase", edgeWhen == "next" {
            clearEventFields()
            return EdgeSelectionResult(didNavigate: false, clearedLog: true)
        }
        // Handed → erase: clear event and let client reset to Home.
        if currentNode.id == "Handed", edgeWhen == "erase" {
            clearEventFields()
            return EdgeSelectionResult(didNavigate: false, clearedLog: true)
        }
        if edgeWhen == "report" {
            unreachableMarked = true
            lastVetoNodeId = currentNode.id
        }

        if let to = edge.to {
            let isCall = graph.alwaysAvailable.contains(to) || to.hasPrefix("CALL")
            // Prefer opening tel from the bar; if an edge still points at CALL-*, open URL without trapping UI.
            if isCall, let url = externalURL(for: graph.node(id: to)) {
                steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
                return EdgeSelectionResult(didNavigate: false, externalURL: url)
            }
            let fromHandedKeep = currentNode.id == "Handed" && edgeWhen == "keep"
            let result = try navigate(to: to, edgeWhen: edgeWhen, pushReturn: false, recordHistory: true)
            if fromHandedKeep {
                history.removeAll()
                returnStack.removeAll()
            }
            if currentNode.id == "Form",
               reachedFormAt == nil,
               eventStartedAt != nil
            {
                reachedFormAt = now()
                if !waveRemindersScheduled {
                    scheduleWave = true
                }
            }
            return EdgeSelectionResult(
                didNavigate: result.didNavigate,
                externalURL: nil,
                clearedLog: false,
                shouldScheduleWaveReminders: scheduleWave
            )
        }

        steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
        return EdgeSelectionResult(
            didNavigate: false,
            externalURL: externalURL(for: currentNode),
            clearedLog: false
        )
    }

    private var shouldInterceptForSceneRecheck: Bool {
        if suppressSceneRecheck {
            suppressSceneRecheck = false
            return false
        }
        let recheck = rules.sceneRecheck
        guard currentNode.id != recheck.nodeId else { return false }
        guard rules.careBranchSet.contains(currentNode.branch) else { return false }
        guard let last = lastSceneCheckAt else { return false }
        return now().timeIntervalSince(last) >= sceneRecheckInterval
    }

    private func handleSceneRecheck(edgeWhen: String) throws -> EdgeSelectionResult {
        let recheck = rules.sceneRecheck
        guard currentNode.edges.contains(where: { $0.when == edgeWhen }) else {
            throw ProtocolGraphError.missingEdge(node: recheck.nodeId, when: edgeWhen)
        }
        if edgeWhen == recheck.safeEdge {
            lastSceneCheckAt = now()
            let pending = pendingRecheckEdge
            pendingRecheckEdge = nil
            steps.append(ProtocolLogStep(nodeId: recheck.nodeId, edge: recheck.safeEdge))
            if let resumeId = returnStack.popLast(),
               let resumeNode = graph.node(id: resumeId)
            {
                currentNode = resumeNode
            }
            suppressSceneRecheck = true
            if let pending {
                return try select(edgeWhen: pending)
            }
            return EdgeSelectionResult(didNavigate: true, externalURL: nil, clearedLog: false)
        }
        if edgeWhen == recheck.threatEdge {
            pendingRecheckEdge = nil
            lastSceneCheckAt = now()
            return try navigate(
                to: recheck.threatTarget,
                edgeWhen: recheck.threatEdge,
                pushReturn: false,
                recordHistory: true
            )
        }
        throw ProtocolGraphError.missingEdge(node: recheck.nodeId, when: edgeWhen)
    }

    func finishExternalAndReturn() {
        guard let previous = returnStack.popLast(),
              let node = graph.node(id: previous)
        else { return }
        currentNode = node
    }

    func reset() throws {
        currentNode = try graph.entryNode
        sessionRole = nil
        incidentType = nil
        locationLine = nil
        locationLevel = nil
        resetManualLocationWizard()
        clearEventFields()
        unreachableMarked = false
        lastVetoNodeId = nil
        multipleCasualties = false
        lastSceneCheckAt = nil
        pendingRecheckEdge = nil
        suppressSceneRecheck = false
        returnStack = []
        history = []
        try skipEntrySplashIfNeeded()
    }

    var hasPersistableEvent: Bool {
        eventStartedAt != nil
    }

    func makeEventSnapshot() -> LocalEventRecord? {
        guard let eventId, let eventStartedAt else { return nil }
        return LocalEventRecord(
            eventId: eventId,
            startedAt: eventStartedAt,
            reachedFormAt: reachedFormAt,
            sessionRole: sessionRole?.rawValue,
            incidentType: incidentType,
            locationLine: locationLine,
            locationLevel: locationLevel,
            steps: steps,
            waveRemindersScheduled: waveRemindersScheduled,
            tourniquetOn: tourniquetOn,
            saltRedCount: saltRedCount,
            saltYellowCount: saltYellowCount,
            saltGreenCount: saltGreenCount
        )
    }

    func hydrate(from record: LocalEventRecord) {
        eventId = record.eventId
        eventStartedAt = record.startedAt
        reachedFormAt = record.reachedFormAt
        sessionRole = record.sessionRole.flatMap(SessionRole.init(rawValue:))
        incidentType = record.incidentType
        locationLine = record.locationLine
        locationLevel = record.locationLevel
        steps = record.steps
        waveRemindersScheduled = record.waveRemindersScheduled
        tourniquetOn = record.tourniquetOn
        saltRedCount = record.saltRedCount
        saltYellowCount = record.saltYellowCount
        saltGreenCount = record.saltGreenCount
    }

    func markWaveRemindersScheduled() {
        waveRemindersScheduled = true
    }

    func openWaveChecklist() throws {
        guard let node = graph.node(id: "I0") else {
            throw ProtocolGraphError.missingNode("I0")
        }
        history.removeAll()
        returnStack.removeAll()
        currentNode = node
    }

    /// Resume the handover screen for the persisted single event (Home → last report).
    func openLastReport() throws {
        guard hasPersistableEvent else { return }
        guard let node = graph.node(id: "Form") else {
            throw ProtocolGraphError.missingNode("Form")
        }
        history.removeAll()
        returnStack.removeAll()
        currentNode = node
    }

    /// Short line for Home: when the last event started.
    var lastEventSummaryLine: String? {
        guard let eventStartedAt else { return nil }
        let day: String
        if Calendar.current.isDateInToday(eventStartedAt) {
            day = locale == .uk ? "сьогодні" : "today"
        } else if Calendar.current.isDateInYesterday(eventStartedAt) {
            day = locale == .uk ? "вчора" : "yesterday"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: locale == .uk ? "uk_UA" : "en_GB")
            dayFormatter.dateStyle = .medium
            dayFormatter.timeStyle = .none
            day = dayFormatter.string(from: eventStartedAt)
        }
        let time = Self.clockFormatter(locale: locale).string(from: eventStartedAt)
        return locale == .uk
            ? "Остання подія · \(time), \(day)"
            : "Last event · \(time), \(day)"
    }

    private func beginEventIfNeeded() {
        guard eventStartedAt == nil else { return }
        eventId = UUID()
        eventStartedAt = now()
        waveRemindersScheduled = false
        reachedFormAt = nil
    }

    private func clearEventFields() {
        eventId = nil
        eventStartedAt = nil
        reachedFormAt = nil
        waveRemindersScheduled = false
        tourniquetOn = nil
        saltRedCount = 0
        saltYellowCount = 0
        saltGreenCount = 0
        steps = []
        locationLine = nil
        locationLevel = nil
        incidentType = nil
        sessionRole = nil
        unreachableMarked = false
        lastVetoNodeId = nil
        multipleCasualties = false
        resetManualLocationWizard()
    }

    private func handleManualLocationNext() throws -> EdgeSelectionResult {
        let trimmed = manualLocationDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if manualLocationFieldIndex == 0, trimmed.isEmpty {
            return EdgeSelectionResult(didNavigate: false, externalURL: nil, clearedLog: false)
        }
        let key = manualLocationFieldKey
        if trimmed.isEmpty {
            manualLocationValues.removeValue(forKey: key)
        } else {
            manualLocationValues[key] = trimmed
        }

        let keys = manualLocationFieldKeys
        if manualLocationFieldIndex + 1 < keys.count {
            manualLocationFieldIndex += 1
            let nextKey = keys[manualLocationFieldIndex]
            manualLocationDraft = manualLocationValues[nextKey] ?? ""
            return EdgeSelectionResult(didNavigate: false, externalURL: nil, clearedLog: false)
        }

        let line = composeManualLocationLine()
        guard !line.isEmpty else {
            return EdgeSelectionResult(didNavigate: false, externalURL: nil, clearedLog: false)
        }
        locationLevel = 3
        locationLine = line
        return try navigate(to: "Type", edgeWhen: "next", pushReturn: false, recordHistory: true)
    }

    private func composeManualLocationLine() -> String {
        manualLocationFieldKeys.compactMap { key in
            let value = manualLocationValues[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }

    private func resetManualLocationWizard() {
        manualLocationFieldIndex = 0
        manualLocationValues = [:]
        manualLocationDraft = ""
    }

    private func navigate(
        to id: String,
        edgeWhen: String,
        pushReturn: Bool,
        recordHistory: Bool
    ) throws -> EdgeSelectionResult {
        var targetId = remapSafetyTarget(id, edgeWhen: edgeWhen)
        if sessionRole == .casualty {
            targetId = remapCasualtyTarget(targetId)
        }

        guard let next = graph.node(id: targetId) else {
            throw ProtocolGraphError.missingNode(targetId)
        }
        let leavingId = currentNode.id
        steps.append(ProtocolLogStep(nodeId: leavingId, edge: edgeWhen))
        if pushReturn {
            returnStack.append(leavingId)
        }
        if recordHistory {
            history.append(leavingId)
        }
        currentNode = next
        captureLocationIfNeeded(arrivedAt: next.id)
        captureReportArrival(arrivedAt: next.id, leavingId: leavingId, edgeWhen: edgeWhen)
        if leavingId == rules.sceneRecheck.armAfterLeavingNodeId {
            lastSceneCheckAt = now()
        }
        if let role = next.ui?.sessionRole {
            sessionRole = SessionRole(rawValue: role) ?? sessionRole
        }
        return EdgeSelectionResult(
            didNavigate: true,
            externalURL: externalURL(for: next),
            clearedLog: false
        )
    }

    private func captureLocationIfNeeded(arrivedAt id: String) {
        switch id {
        case "Loc-1":
            locationLevel = 1
            locationLine = demoAddressLine(for: locale)
        case "Loc-2":
            locationLevel = 2
            locationLine = demoCoordinatesDraft
        case "Loc-3":
            locationLevel = 3
            resetManualLocationWizard()
        default:
            break
        }
    }

    private func captureReportArrival(arrivedAt id: String, leavingId: String, edgeWhen: String) {
        switch id {
        case "Red":
            saltRedCount += 1
        case "Yellow":
            saltYellowCount += 1
        case "Green", "Green2":
            saltGreenCount += 1
        case "Tq-time":
            if tourniquetOn == nil {
                tourniquetOn = now()
            }
        default:
            break
        }
        // Timer on Tq starts when user confirms («Наклав»).
        if leavingId == "Tq", edgeWhen == "next", tourniquetOn == nil {
            tourniquetOn = now()
        }
    }

    private func remapCasualtyTarget(_ targetId: String) -> String {
        if rules.casualtyRedirectNodeSet.contains(targetId) {
            return rules.casualty.redirectTo
        }
        if let branch = graph.node(id: targetId)?.branch,
           rules.casualtyRedirectBranchSet.contains(branch)
        {
            return rules.casualty.redirectTo
        }
        return rules.casualty.targetRemaps[targetId] ?? targetId
    }

    /// Remap graph safety chain onto the type-specific queue from shared rules.
    private func remapSafetyTarget(_ targetId: String, edgeWhen: String) -> String {
        let queue = rules.safetyQueue(for: incidentType)
        let safety = rules.safety

        if targetId == safety.entryTarget,
           rules.roleEntrySet.contains(currentNode.id)
        {
            return queue.first ?? safety.entryTarget
        }

        if rules.threatIdSet.contains(currentNode.id),
           rules.advanceEdgeSet.contains(edgeWhen)
        {
            if let idx = queue.firstIndex(of: currentNode.id), idx + 1 < queue.count {
                return queue[idx + 1]
            }
            return safety.fallbackNext
        }

        return targetId
    }

    private func captureSideEffects(edgeWhen: String) {
        switch currentNode.id {
        case "Type":
            incidentType = edgeWhen
        case "Role":
            sessionRole = SessionRole(rawValue: edgeWhen)
        case "Count":
            multipleCasualties = (edgeWhen == "many" || edgeWhen == "unknown")
        default:
            break
        }
    }

    private func externalURL(for node: ProtocolNode?) -> URL? {
        guard let raw = node?.ui?.external else { return nil }
        return URL(string: raw)
    }
}
