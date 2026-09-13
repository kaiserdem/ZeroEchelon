import Foundation

enum ContentLocale: String, Codable, Sendable, CaseIterable {
    case uk
    case en

    var speechLanguageCode: String {
        switch self {
        case .uk: "uk-UA"
        case .en: "en-US"
        }
    }
}

enum SessionRole: String, Codable, Sendable {
    case witness
    case casualty
}

enum NodeType: String, Codable, Sendable {
    case question
    case action
    case timer
    case report
    case handover
    case antipattern
}

struct LocalizedText: Codable, Hashable, Sendable {
    var ua: String
    var en: String

    func text(for locale: ContentLocale) -> String {
        switch locale {
        case .uk: ua
        case .en: en
        }
    }
}

struct ProtocolEdge: Codable, Hashable, Sendable {
    var when: String
    var to: String?
}

struct ProtocolButton: Codable, Hashable, Sendable, Identifiable {
    var when: String
    var ua: String
    var en: String

    var id: String { when }

    func title(for locale: ContentLocale) -> String {
        switch locale {
        case .uk: ua
        case .en: en
        }
    }
}

struct ProtocolNodeUI: Codable, Hashable, Sendable {
    var screenId: String?
    var template: String?
    var buttons: [ProtocolButton]?
    var external: String?
    var showDispatcherDraft: Bool?
    var stub: Bool?
    var markUnreachable: Bool?
    var clearsLocalLog: Bool?
    var layout: String?
    var locationLevel: Int?
    var sessionRole: String?
    var note: String?
    /// Ordered address fields for Loc-3 (settlement → street → …).
    var fields: [String]?
}

struct ProtocolNode: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var type: NodeType
    var branch: String
    var roles: [SessionRole]
    var precedence: Int
    var registry: [String]
    var conflict: [String]
    var veto: Bool
    var handsBusy: Bool
    var delegationRequired: Bool
    var voice: LocalizedText
    var antiPattern: LocalizedText?
    var edges: [ProtocolEdge]
    var ui: ProtocolNodeUI?

    func primaryButtons(locale: ContentLocale) -> [ProtocolButton] {
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

struct ProtocolGraph: Codable, Hashable, Sendable {
    var schemaVersion: String
    var protocolGraphId: String
    var graphVersion: String?
    var locale: [String]
    var commercial: Bool
    var entry: String
    var alwaysAvailable: [String]
    var invariants: [String]
    var nodes: [ProtocolNode]

    func node(id: String) -> ProtocolNode? {
        nodes.first { $0.id == id }
    }

    var entryNode: ProtocolNode {
        get throws {
            guard let node = node(id: entry) else {
                throw ProtocolGraphError.missingEntry(entry)
            }
            return node
        }
    }
}

enum ProtocolGraphError: Error, LocalizedError, Sendable {
    case missingEntry(String)
    case missingNode(String)
    case missingEdge(node: String, when: String)
    case commercialInvariant
    case invalidData

    var errorDescription: String? {
        switch self {
        case .missingEntry(let id): "Missing entry node: \(id)"
        case .missingNode(let id): "Missing node: \(id)"
        case .missingEdge(let node, let when): "Missing edge \(when) on \(node)"
        case .commercialInvariant: "commercial must be false"
        case .invalidData: "Invalid protocol graph data"
        }
    }
}
