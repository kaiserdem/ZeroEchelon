import Foundation

public struct ProtocolLogStep: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var nodeId: String
    public var edge: String?
    public var at: Date

    public init(id: UUID = UUID(), nodeId: String, edge: String?, at: Date = Date()) {
        self.id = id
        self.nodeId = nodeId
        self.edge = edge
        self.at = at
    }
}

public struct EdgeSelectionResult: Sendable {
    public var didNavigate: Bool
    public var externalURL: URL?
    public var clearedLog: Bool
}

/// Pure navigation over the protocol graph. No clinical branching outside edges.
@Observable
public final class ProtocolEngine {
    public private(set) var graph: ProtocolGraph
    public private(set) var currentNode: ProtocolNode
    public var locale: ContentLocale
    public private(set) var sessionRole: SessionRole?
    public private(set) var incidentType: String?
    public private(set) var steps: [ProtocolLogStep]
    public private(set) var unreachableMarked: Bool
    public private(set) var lastVetoNodeId: String?

    private var returnStack: [String]

    public init(graph: ProtocolGraph, locale: ContentLocale = .uk) throws {
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
    }

    public var voiceText: String {
        currentNode.voice.text(for: locale)
    }

    public var antiPatternText: String? {
        currentNode.antiPattern?.text(for: locale)
    }

    public var visibleButtons: [ProtocolButton] {
        let buttons = currentNode.primaryButtons(locale: locale)
        guard currentNode.id == "Form" else { return buttons }

        let backWhen = lastVetoNodeId == "Cont" ? "back-cont" : "back-out"
        return buttons.filter { $0.when == backWhen || $0.when == "erase" }
    }

    public var alwaysAvailableNodes: [ProtocolNode] {
        graph.alwaysAvailable.compactMap { graph.node(id: $0) }
    }

    public var dispatcherDraft: String {
        let place = locale == .uk ? "місце з сесії" : "location from session"
        let type = incidentType ?? (locale == .uk ? "тип невідомий" : "type unknown")
        let role: String = {
            switch sessionRole {
            case .witness: locale == .uk ? "цивільний свідок" : "civilian bystander"
            case .casualty: locale == .uk ? "постраждалий" : "casualty"
            case nil: locale == .uk ? "роль не обрана" : "role not set"
            }
        }()
        if locale == .uk {
            return "\(type), \(place). Є потреба в допомозі. Я \(role). Зачитайте також координати або адресу з екрана локації."
        }
        return "\(type), \(place). Help is needed. I am \(role). Also read coordinates or address from the location screen."
    }

    @discardableResult
    public func select(edgeWhen: String) throws -> EdgeSelectionResult {
        if currentNode.id == "Form", edgeWhen == "back-out" || edgeWhen == "back-cont" {
            let targetId = edgeWhen == "back-cont" ? "Cont" : "Out"
            return try navigate(to: targetId, edgeWhen: edgeWhen, pushReturn: false)
        }

        guard let edge = currentNode.edges.first(where: { $0.when == edgeWhen }) else {
            throw ProtocolGraphError.missingEdge(node: currentNode.id, when: edgeWhen)
        }

        captureSideEffects(edgeWhen: edgeWhen)

        if currentNode.ui?.clearsLocalLog == true || edgeWhen == "erase" {
            // Erase node clears on arrival via edge; handle when leaving Erase or selecting erase
        }

        if edgeWhen == "erase" || currentNode.id == "Erase" && edgeWhen == "next" {
            // clearing happens when confirming erase (on Erase node next) or selecting erase from Form
        }

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
            let result = try navigate(to: to, edgeWhen: edgeWhen, pushReturn: isCall)
            return EdgeSelectionResult(
                didNavigate: result.didNavigate,
                externalURL: externalURL(for: graph.node(id: to)),
                clearedLog: cleared
            )
        }

        // External-only edge (to: null) — open tel on current node if present
        steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
        return EdgeSelectionResult(
            didNavigate: false,
            externalURL: externalURL(for: currentNode),
            clearedLog: cleared
        )
    }

    public func openAlwaysAvailable(id: String) throws -> EdgeSelectionResult {
        guard graph.alwaysAvailable.contains(id) else {
            throw ProtocolGraphError.missingNode(id)
        }
        let result = try navigate(to: id, edgeWhen: "always:\(id)", pushReturn: true)
        return EdgeSelectionResult(
            didNavigate: result.didNavigate,
            externalURL: externalURL(for: graph.node(id: id)),
            clearedLog: false
        )
    }

    public func finishExternalAndReturn() {
        guard let previous = returnStack.popLast(),
              let node = graph.node(id: previous)
        else { return }
        currentNode = node
    }

    public func reset() throws {
        currentNode = try graph.entryNode
        sessionRole = nil
        incidentType = nil
        steps = []
        unreachableMarked = false
        lastVetoNodeId = nil
        returnStack = []
    }

    private func navigate(to id: String, edgeWhen: String, pushReturn: Bool) throws -> EdgeSelectionResult {
        guard let next = graph.node(id: id) else {
            throw ProtocolGraphError.missingNode(id)
        }
        steps.append(ProtocolLogStep(nodeId: currentNode.id, edge: edgeWhen))
        if pushReturn {
            returnStack.append(currentNode.id)
        }
        currentNode = next
        if next.ui?.clearsLocalLog == true {
            // no-op until user confirms via edge
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
