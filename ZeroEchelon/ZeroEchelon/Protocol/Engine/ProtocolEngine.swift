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

/// Pure navigation over the protocol graph. No clinical branching outside edges.
@Observable
final class ProtocolEngine {
    private(set) var graph: ProtocolGraph
    private(set) var currentNode: ProtocolNode
    var locale: ContentLocale
    private(set) var sessionRole: SessionRole?
    private(set) var incidentType: String?
    private(set) var steps: [ProtocolLogStep]
    private(set) var unreachableMarked: Bool
    private(set) var lastVetoNodeId: String?
    /// True after Count→many/unknown (SALT multi-casualty context).
    private(set) var multipleCasualties: Bool

    /// Seconds between scene re-checks while in care branches B–G (default 3 min).
    var sceneRecheckInterval: TimeInterval = 180
    /// Clock injection for tests.
    var now: () -> Date = { Date() }
    private(set) var lastSceneCheckAt: Date?

    private var returnStack: [String]
    private var history: [String]
    private var pendingRecheckEdge: String?
    private var suppressSceneRecheck = false

    private static let careBranches: Set<String> = ["B", "C", "D", "E", "F", "G"]

    init(graph: ProtocolGraph, locale: ContentLocale = .uk) throws {
        guard graph.commercial == false else {
            throw ProtocolGraphError.commercialInvariant
        }
        self.graph = graph
        self.locale = locale
        self.currentNode = try graph.entryNode
        self.sessionRole = nil
        self.incidentType = nil
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

    /// Test helper: mark the last scene check at an absolute time.
    func setLastSceneCheckAtForTesting(_ date: Date?) {
        lastSceneCheckAt = date
    }

    /// Skip the silent Start splash — land on Disclaimer.
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
        case "NoCpr" where sessionRole == .casualty || !multipleCasualties:
            // P0 from audit: do not order "go to the next person" when there is no next / cannot leave
            return locale == .uk
                ? "Реанімація тут не допоможе. Залишайтесь. Натисніть 103 внизу."
                : "CPR will not help here. Stay. Tap 103 below."
        default:
            return currentNode.voice.text(for: locale)
        }
    }

    var antiPatternText: String? {
        currentNode.antiPattern?.text(for: locale)
    }

    /// Extra line under the main phrase — explains the step without changing protocol voice.
    var helperText: String? {
        switch currentNode.id {
        case "Disclaimer":
            return locale == .uk
                ? "Далі — короткі кроки допомоги. 103 завжди внизу екрана."
                : "Next — short help steps. 103 stays at the bottom."
        case "Loc-mode":
            return locale == .uk
                ? "Поки немає справжнього QR: оберіть, як показати місце для демо."
                : "No real QR yet: pick how to show the place for the demo."
        case "Loc-1":
            return locale == .uk
                ? "У фіналі адреса прийде з QR на підʼїзді / у вагоні. Нижче — демо-рядок."
                : "In production this comes from a QR on site. Below — a demo line."
        case "Loc-2":
            return locale == .uk
                ? "Зачитайте цифри диспетчеру. Інтернет не потрібен."
                : "Read the digits to the dispatcher. No internet needed."
        case "Loc-3":
            return locale == .uk
                ? "Одне поле за разом: місто, вулиця, будинок…"
                : "One field at a time: city, street, building…"
        case "Type":
            return locale == .uk
                ? "Один дотик = вибір. Це поле для звіту службам."
                : "One tap = choice. This fills the report for responders."
        case "Call":
            return locale == .uk
                ? "Червона кнопка внизу набирає 103. Тут — текст, який зачитати."
                : "The red button below dials 103. Here — the text to read aloud."
        case "CanLeave":
            return locale == .uk
                ? "Люди біля загрози — у звіті як недосяжні. Не підходьте допомагати."
                : "People near the threat go in the report as unreachable. Do not go help them."
        case "Out", "Cont":
            return locale == .uk
                ? "Медичних кроків немає. Головне — 101 внизу. У звіті зазначте недосяжних."
                : "No medical steps. Primary is 101 below. Mark unreachable people in the report."
        case "Out-trapped":
            return locale == .uk
                ? "Ви не зобовʼязані йти 300 м, якщо не можете. Не чіпайте. Кличте 101."
                : "You are not ordered to walk 300 m if you cannot. Do not touch. Call 101."
        case "A7":
            return locale == .uk
                ? "Якщо знову небезпечно — відхід / 101, не медичні кроки."
                : "If danger returns — withdraw / 101, no medical steps."
        case "Four":
            return locale == .uk
                ? "Не рахуйте пульс — лише чи відчуваєте. Сумнів — як червоний."
                : "Do not count the pulse — only whether you feel it. Unsure — treat as red."
        case "Organic":
            return locale == .uk
                ? "103 внизу. Не робіть дихальних вправ."
                : "103 below. Do not do breathing exercises."
        case "NEXT-PHASE":
            return locale == .uk
                ? "Далі — кроки за вашою роллю (свідок або постраждалий)."
                : "Next — steps for your role (witness or casualty)."
        default:
            return nil
        }
    }

    var detailBlock: String? {
        switch currentNode.id {
        case "Loc-1":
            return locale == .uk
                ? "Київська обл., м. Бровари, вул. Демо 12, підʼїзд 3"
                : "Kyiv region, Brovary, Demo St. 12, entrance 3"
        case "Loc-2":
            return "50.51120° N\n30.79090° E"
        case "Call", "CALL-read":
            return dispatcherDraft
        default:
            if currentNode.ui?.showDispatcherDraft == true {
                return dispatcherDraft
            }
            return nil
        }
    }

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
                buttons = buttons.filter { ["read", "give", "erase"].contains($0.when) }
            }
        }

        // Casualty: hide witness-only delegation question labels already in graph via roles filter in primaryButtons? edges still show Hands for both if roles include both — Hands is witness-only in roles
        if currentNode.id == "Loc-mode" {
            buttons = [
                ProtocolButton(when: "qr", ua: "З QR на стіні (демо)", en: "From wall QR (demo)"),
                ProtocolButton(when: "gnss", ua: "Мої координати (GPS)", en: "My coordinates (GPS)"),
                ProtocolButton(when: "manual", ua: "Введу адресу сам", en: "I will type the address"),
            ]
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
        currentNode.veto || currentNode.id == "CanLeave" || currentNode.id == "A7"
    }

    var dispatcherDraft: String {
        let place: String = {
            switch locale {
            case .uk: "місце вже на екрані локації"
            case .en: "place already on the location screen"
            }
        }()
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

        // A7 interrupt: pause care tap, show scene re-check, then resume or CanLeave.
        if shouldInterceptForSceneRecheck {
            pendingRecheckEdge = edgeWhen
            return try navigate(to: "A7", edgeWhen: "recheck", pushReturn: true, recordHistory: true)
        }

        if currentNode.id == "A7" {
            return try handleA7(edgeWhen: edgeWhen)
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
        guard currentNode.id != "A7" else { return false }
        guard Self.careBranches.contains(currentNode.branch) else { return false }
        guard let last = lastSceneCheckAt else { return false }
        return now().timeIntervalSince(last) >= sceneRecheckInterval
    }

    private func handleA7(edgeWhen: String) throws -> EdgeSelectionResult {
        guard currentNode.edges.contains(where: { $0.when == edgeWhen }) else {
            throw ProtocolGraphError.missingEdge(node: "A7", when: edgeWhen)
        }
        switch edgeWhen {
        case "safe":
            lastSceneCheckAt = now()
            let pending = pendingRecheckEdge
            pendingRecheckEdge = nil
            steps.append(ProtocolLogStep(nodeId: "A7", edge: "safe"))
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
        case "threat":
            pendingRecheckEdge = nil
            lastSceneCheckAt = now()
            return try navigate(to: "CanLeave", edgeWhen: "threat", pushReturn: false, recordHistory: true)
        default:
            throw ProtocolGraphError.missingEdge(node: "A7", when: edgeWhen)
        }
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

    private func navigate(
        to id: String,
        edgeWhen: String,
        pushReturn: Bool,
        recordHistory: Bool
    ) throws -> EdgeSelectionResult {
        var targetId = remapSafetyTarget(id, edgeWhen: edgeWhen)
        // Role-aware remaps (same class as CanLeave: avoid absurd orders)
        if sessionRole == .casualty {
            // Entire SALT branch B is witness-only
            if targetId == "Count" || nextIsBranchB(targetId) {
                targetId = "Casualty-menu"
            } else {
                switch targetId {
                case "Hands": targetId = "Hold"
                case "D2": targetId = "Sup"
                case "NoCpr": targetId = "E0"
                default: break
                }
            }
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
        if leavingId == "A6" {
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

    private func nextIsBranchB(_ id: String) -> Bool {
        graph.node(id: id)?.branch == "B"
    }

    /// Threat checks A1–A5 relevant to `incidentType` (docs/01 A0). A6 always last.
    private static let safetyThreatIds: Set<String> = ["A1", "A2", "A3", "A4", "A5"]

    private func safetyThreatQueue(for type: String?) -> [String] {
        switch type {
        case "explosion", "shooting", "train":
            ["A1", "A2", "A3", "A4", "A5", "A6"]
        case "collapse":
            ["A2", "A1", "A3", "A4", "A5", "A6"]
        case "fire":
            ["A3", "A4", "A5", "A2", "A6"]
        case "traffic":
            ["A4", "A3", "A5", "A6"]
        case "chemical":
            ["A5", "A3", "A4", "A6"]
        case "household":
            ["A3", "A4", "A5", "A6"]
        default:
            // other / unknown — full chain
            ["A1", "A2", "A3", "A4", "A5", "A6"]
        }
    }

    /// Remap graph A1→A2… chain onto the type-specific queue.
    private func remapSafetyTarget(_ targetId: String, edgeWhen: String) -> String {
        let queue = safetyThreatQueue(for: incidentType)

        // Role → A1 in graph: land on first relevant threat instead.
        if targetId == "A1",
           currentNode.id == "Role-witness" || currentNode.id == "Role-casualty"
        {
            return queue.first ?? "A1"
        }

        // «Ні» / «Не бачу» on a threat → next in this type's queue (may skip A*).
        if Self.safetyThreatIds.contains(currentNode.id),
           edgeWhen == "no" || edgeWhen == "cannot"
        {
            if let idx = queue.firstIndex(of: currentNode.id), idx + 1 < queue.count {
                return queue[idx + 1]
            }
            return "A6"
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
