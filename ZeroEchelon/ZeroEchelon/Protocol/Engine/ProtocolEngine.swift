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
}

/// Pure navigation over the protocol graph. Policy remaps come from shared `EngineRules`.
@Observable
final class ProtocolEngine {
    private(set) var graph: ProtocolGraph
    private(set) var rules: EngineRules
    private(set) var currentNode: ProtocolNode
    var locale: ContentLocale
    private(set) var sessionRole: SessionRole?
    private(set) var incidentType: String?
    /// Location line captured from Loc-1 / Loc-2 / Loc-3 for the 103 draft.
    private(set) var locationLine: String?
    private(set) var locationLevel: Int?
    /// Draft text for the current Loc-3 field (bound to the text field).
    var manualLocationDraft: String = ""
    /// Index into `manualLocationFieldKeys` while on Loc-3.
    private(set) var manualLocationFieldIndex: Int = 0
    private var manualLocationValues: [String: String] = [:]
    private(set) var steps: [ProtocolLogStep]
    private(set) var unreachableMarked: Bool
    private(set) var lastVetoNodeId: String?
    /// True after Count→many/unknown (SALT multi-casualty context).
    private(set) var multipleCasualties: Bool

    /// Seconds between scene re-checks while in care branches (overridable in tests).
    var sceneRecheckInterval: TimeInterval
    /// Clock injection for tests.
    var now: () -> Date = { Date() }
    private(set) var lastSceneCheckAt: Date?

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
    var helperText: String? { nil }

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
        case "Call", "CALL-read", "Read", "Give", "Form":
            return dispatcherDraft
        default:
            if currentNode.ui?.showDispatcherDraft == true {
                return dispatcherDraft
            }
            return nil
        }
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
            if lastVetoNodeId != nil {
                let backWhen: String
                switch lastVetoNodeId {
                case "Cont": backWhen = "back-cont"
                case "Out-trapped": backWhen = "back-trapped"
                default: backWhen = "back-out"
                }
                buttons = buttons.filter { $0.when == backWhen || $0.when == "erase" }
            } else {
                buttons = buttons.filter { ["read", "give", "wave", "erase"].contains($0.when) }
            }
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

        return buttons
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
        let place = locationLine
            ?? (locale == .uk ? "місце ще не вказано" : "place not set")
        let type = localizedIncidentTypeLabel()
        let role: String = {
            switch sessionRole {
            case .witness: locale == .uk ? "цивільний свідок" : "civilian bystander"
            case .casualty: locale == .uk ? "постраждалий" : "casualty"
            case nil: locale == .uk ? "роль ще не обрана" : "role not set"
            }
        }()
        if locale == .uk {
            return "\(type). \(place). Потрібна допомога. Я \(role)."
        }
        return "\(type). \(place). Help needed. I am \(role)."
    }

    /// Human label from Type (S2) buttons — never the raw edge id (`explosion` → «Вибух»).
    private func localizedIncidentTypeLabel() -> String {
        guard let incidentType else {
            return locale == .uk ? "тип ще не обрано" : "type not set"
        }
        if let button = graph.node(id: "Type")?.ui?.buttons?.first(where: { $0.when == incidentType }) {
            return button.title(for: locale)
        }
        return incidentType
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

        var cleared = false
        if edgeWhen == "erase" {
            steps.removeAll()
            cleared = true
        }
        if currentNode.id == "Erase", edgeWhen == "next" {
            steps.removeAll()
            cleared = true
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
                return EdgeSelectionResult(didNavigate: false, externalURL: url, clearedLog: cleared)
            }
            let result = try navigate(to: to, edgeWhen: edgeWhen, pushReturn: false, recordHistory: true)
            return EdgeSelectionResult(
                didNavigate: result.didNavigate,
                externalURL: nil,
                clearedLog: cleared
            )
        }

        steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
        return EdgeSelectionResult(
            didNavigate: false,
            externalURL: externalURL(for: currentNode),
            clearedLog: cleared
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
        steps = []
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
