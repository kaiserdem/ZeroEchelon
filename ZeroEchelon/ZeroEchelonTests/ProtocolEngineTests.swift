import Foundation
import Testing
@testable import ZeroEchelon

@MainActor
struct ProtocolEngineTests {
    private func loadGraph() throws -> ProtocolGraph {
        if let bundled = Bundle.main.url(forResource: "graph", withExtension: "json") {
            return try GraphLoader.load(from: bundled)
        }
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try GraphLoader.load(
            from: repoRoot.appendingPathComponent("protocol/graphs/zero-echelon-core/graph.json")
        )
    }

    private func reachCare(engine: ProtocolEngine, role: String) throws {
        for edge in ["next", "agree", "qr", "next", "explosion", role, "next", "no", "no", "no", "no", "no", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
        // Call
        #expect(engine.currentNode.id == "Call")
    }

    @Test func graphContainsS6S12Core() throws {
        let graph = try loadGraph()
        for id in ["Count", "Casualty-menu", "C0", "D0", "E0", "F0", "Form", "I0", "J0", "CanLeave"] {
            #expect(graph.node(id: id) != nil, "missing \(id)")
        }
        #expect(graph.node(id: "NEXT-PHASE") == nil)
    }

    @Test func witnessPathReachesBleeding() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Count")
        _ = try engine.select(edgeWhen: "one")
        #expect(engine.currentNode.id == "C0")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "D0")
    }

    @Test func casualtyPathOpensSelfMenu() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "casualty")
        _ = try engine.select(edgeWhen: "next-casualty")
        #expect(engine.currentNode.id == "Casualty-menu")
        _ = try engine.select(edgeWhen: "crush")
        #expect(engine.currentNode.id == "F0")
    }

    @Test func threatCanLeaveTrapped() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        for edge in ["next", "agree", "gnss", "next", "collapse", "witness", "next", "yes", "no"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Out-trapped")
    }

    @Test func noBleedPathReachesFormViaChestCrush() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "one") // C0
        _ = try engine.select(edgeWhen: "no") // D0
        _ = try engine.select(edgeWhen: "yes") // D2
        _ = try engine.select(edgeWhen: "yes") // Sup
        _ = try engine.select(edgeWhen: "next") // Neck
        _ = try engine.select(edgeWhen: "next") // E0
        _ = try engine.select(edgeWhen: "no") // F0
        _ = try engine.select(edgeWhen: "no") // G0
        _ = try engine.select(edgeWhen: "next") // G1
        _ = try engine.select(edgeWhen: "next") // Ban
        _ = try engine.select(edgeWhen: "next") // Form
        #expect(engine.currentNode.id == "Form")
    }

    @Test func dispatcherDraftUsesLocalizedIncidentType() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        #expect(engine.incidentType == "explosion")
        #expect(engine.dispatcherDraft.hasPrefix("Вибух."))
        #expect(!engine.dispatcherDraft.contains("explosion"))
        engine.locale = .en
        #expect(engine.dispatcherDraft.hasPrefix("Explosion."))
    }

    @Test func noCprSingleCasualtyAvoidsNextPersonVoice() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "one")
        #expect(engine.multipleCasualties == false)
        _ = try engine.select(edgeWhen: "no") // D0
        _ = try engine.select(edgeWhen: "yes") // D1 → NoCpr
        #expect(engine.currentNode.id == "NoCpr")
        #expect(!engine.voiceText.lowercased().contains("наступн"))
        #expect(!engine.voiceText.lowercased().contains("next"))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "E0")
    }
}
