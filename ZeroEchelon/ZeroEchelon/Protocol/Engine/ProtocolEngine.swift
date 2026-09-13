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

    private var returnStack: [String]
    private var history: [String]

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
        self.returnStack = []
        self.history = []
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
        case "Out", "Cont":
            return locale == .uk
                ? "Медичних кроків немає: зона небезпечна. Лише відхід і 101."
                : "No medical steps: the area is unsafe. Only leave and call 101."
        case "NEXT-PHASE":
            return locale == .uk
                ? "Вхідний каркас завершено. Медичні кроки — у наступній версії."
                : "Entry scaffold done. Medical steps come in the next version."
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

        if currentNode.id == "Form" {
            let backWhen = lastVetoNodeId == "Cont" ? "back-cont" : "back-out"
            buttons = buttons.filter { $0.when == backWhen || $0.when == "erase" }
        }

        if currentNode.id == "Loc-mode" {
            buttons = [
                ProtocolButton(
                    when: "qr",
                    ua: "З QR на стіні (демо)",
                    en: "From wall QR (demo)"
                ),
                ProtocolButton(
                    when: "gnss",
                    ua: "Мої координати (GPS)",
                    en: "My coordinates (GPS)"
                ),
                ProtocolButton(
                    when: "manual",
                    ua: "Введу адресу сам",
                    en: "I will type the address"
                ),
            ]
        }

        return buttons
    }

    var showsRescue101: Bool {
        currentNode.veto || currentNode.branch == "A" || currentNode.id == "Form"
    }

    var dispatcherDraft: String {
        let place: String = {
            switch locale {
            case .uk: "місце вже на екрані локації"
            case .en: "place already on the location screen"
            }
        }()
        let type = incidentType ?? (locale == .uk ? "тип ще не обрано" : "type not set")
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

    func goBack() {
        guard let previousId = history.popLast(),
              let node = graph.node(id: previousId)
        else { return }
        currentNode = node
    }

    @discardableResult
    func select(edgeWhen: String) throws -> EdgeSelectionResult {
        if currentNode.id == "Form", edgeWhen == "back-out" || edgeWhen == "back-cont" {
            let targetId = edgeWhen == "back-cont" ? "Cont" : "Out"
            return try navigate(to: targetId, edgeWhen: edgeWhen, pushReturn: false, recordHistory: true)
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
        guard let next = graph.node(id: id) else {
            throw ProtocolGraphError.missingNode(id)
        }
        steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
        if pushReturn {
            returnStack.append(currentNode.id)
        }
        if recordHistory {
            history.append(currentNode.id)
        }
        currentNode = next
        if let role = next.ui?.sessionRole {
            sessionRole = SessionRole(rawValue: role) ?? sessionRole
        }
        return EdgeSelectionResult(
            didNavigate: true,
            externalURL: externalURL(for: next),
            clearedLog: false
        )
    }

    private func captureSideEffects(edgeWhen: String) {
        switch currentNode.id {
        case "Type":
            incidentType = edgeWhen
        case "Role":
            sessionRole = SessionRole(rawValue: edgeWhen)
        default:
            break
        }
    }

    private func externalURL(for node: ProtocolNode?) -> URL? {
        guard let raw = node?.ui?.external else { return nil }
        return URL(string: raw)
    }
}
