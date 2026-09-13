import Foundation

public enum ContentLocale: String, Codable, Sendable, CaseIterable {
    case uk
    case en

    public var speechLanguageCode: String {
        switch self {
        case .uk: "uk-UA"
        case .en: "en-US"
        }
    }
}

public enum SessionRole: String, Codable, Sendable {
    case witness
    case casualty
}

public enum NodeType: String, Codable, Sendable {
    case question
    case action
    case timer
    case report
    case handover
    case antipattern
}

public struct LocalizedText: Codable, Hashable, Sendable {
    public var ua: String
    public var en: String

    public func text(for locale: ContentLocale) -> String {
        switch locale {
        case .uk: ua
        case .en: en
        }
    }
}

public struct ProtocolEdge: Codable, Hashable, Sendable {
    public var when: String
    public var to: String?
}

public struct ProtocolButton: Codable, Hashable, Sendable, Identifiable {
    public var when: String
    public var ua: String
    public var en: String

    public var id: String { when }

    public func title(for locale: ContentLocale) -> String {
        switch locale {
        case .uk: ua
        case .en: en
        }
    }
}

public struct ProtocolNodeUI: Codable, Hashable, Sendable {
    public var screenId: String?
    public var template: String?
    public var buttons: [ProtocolButton]?
    public var external: String?
    public var showDispatcherDraft: Bool?
    public var stub: Bool?
    public var markUnreachable: Bool?
    public var clearsLocalLog: Bool?
    public var layout: String?
    public var locationLevel: Int?
    public var sessionRole: String?
    public var note: String?
}

public struct ProtocolNode: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var type: NodeType
    public var branch: String
    public var roles: [SessionRole]
    public var precedence: Int
    public var registry: [String]
    public var conflict: [String]
    public var veto: Bool
    public var handsBusy: Bool
    public var delegationRequired: Bool
    public var voice: LocalizedText
    public var antiPattern: LocalizedText?
    public var edges: [ProtocolEdge]
    public var ui: ProtocolNodeUI?

    public func primaryButtons(locale: ContentLocale) -> [ProtocolButton] {
        if let buttons = ui?.buttons, !buttons.isEmpty {
            return buttons.filter { button in
                edges.contains(where: { $0.when == button.when })
            }
        }
        return edges.map { edge in
            ProtocolButton(
                when: edge.when,
                ua: Self.defaultLabel(when: edge.when, locale: .uk),
                en: Self.defaultLabel(when: edge.when, locale: .en)
            )
        }
    }

    private static func defaultLabel(when: String, locale: ContentLocale) -> String {
        let uk: [String: String] = [
            "yes": "Так",
            "no": "Ні",
            "cannot": "Не можу",
            "next": "Далі",
            "agree": "Погоджуюсь",
            "dial": "Набрати",
            "read": "Зачитати",
            "edit": "Виправити",
            "report": "Звіт",
            "erase": "Стерти",
            "dial-101": "Викликати 101",
            "back-out": "Назад",
            "back-cont": "Назад",
        ]
        let en: [String: String] = [
            "yes": "Yes",
            "no": "No",
            "cannot": "Cannot",
            "next": "Next",
            "agree": "I agree",
            "dial": "Dial",
            "read": "Read aloud",
            "edit": "Correct",
            "report": "Report",
            "erase": "Erase",
            "dial-101": "Call 101",
            "back-out": "Back",
            "back-cont": "Back",
        ]
        switch locale {
        case .uk: return uk[when] ?? when
        case .en: return en[when] ?? when
        }
    }
}

public struct ProtocolGraph: Codable, Hashable, Sendable {
    public var schemaVersion: String
    public var protocolGraphId: String
    public var graphVersion: String?
    public var locale: [String]
    public var commercial: Bool
    public var entry: String
    public var alwaysAvailable: [String]
    public var invariants: [String]
    public var nodes: [ProtocolNode]

    public func node(id: String) -> ProtocolNode? {
        nodes.first { $0.id == id }
    }

    public var entryNode: ProtocolNode {
        get throws {
            guard let node = node(id: entry) else {
                throw ProtocolGraphError.missingEntry(entry)
            }
            return node
        }
    }
}

public enum ProtocolGraphError: Error, LocalizedError, Sendable {
    case missingEntry(String)
    case missingNode(String)
    case missingEdge(node: String, when: String)
    case commercialInvariant
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .missingEntry(let id): "Missing entry node: \(id)"
        case .missingNode(let id): "Missing node: \(id)"
        case .missingEdge(let node, let when): "Missing edge \(when) on \(node)"
        case .commercialInvariant: "commercial must be false"
        case .invalidData: "Invalid protocol graph data"
        }
    }
}
