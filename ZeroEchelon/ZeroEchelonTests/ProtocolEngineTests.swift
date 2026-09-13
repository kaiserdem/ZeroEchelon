import Foundation
import Testing
@testable import ZeroEchelon

@MainActor
struct ProtocolEngineTests {
    private func loadGraph() throws -> ProtocolGraph {
        if let bundled = Bundle.main.url(forResource: "graph", withExtension: "json") {
            return try GraphLoader.load(from: bundled)
        }
        // Fallback: repo protocol/ when tests run without host resources
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repoRoot = testsDir
            .deletingLastPathComponent() // ZeroEchelon/
            .deletingLastPathComponent() // repo
        let url = repoRoot.appendingPathComponent("protocol/graphs/zero-echelon-core/graph.json")
        return try GraphLoader.load(from: url)
    }

    @Test func loadsGraph() throws {
        let graph = try loadGraph()
        #expect(graph.commercial == false)
        #expect(graph.entry == "Start")
        #expect(graph.node(id: "Call") != nil)
    }

    @Test func happyPathReachesNextPhase() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        let path: [(String, String)] = [
            ("Start", "next"),
            ("Disclaimer", "agree"),
            ("Loc-mode", "qr"),
            ("Loc-1", "next"),
            ("Type", "explosion"),
            ("Role", "witness"),
            ("Role-witness", "next"),
            ("A1", "no"),
            ("A2", "no"),
            ("A3", "no"),
            ("A4", "no"),
            ("A5", "no"),
            ("A6", "next"),
            ("Call", "next"),
        ]

        for (expectedId, edge) in path {
            #expect(engine.currentNode.id == expectedId)
            _ = try engine.select(edgeWhen: edge)
        }

        #expect(engine.currentNode.id == "NEXT-PHASE")
        #expect(engine.sessionRole == .witness)
        #expect(engine.incidentType == "explosion")
        #expect(engine.steps.count == path.count)
    }

    @Test func vetoPathOpensForm() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        for edge in ["next", "agree", "gnss", "next", "collapse", "casualty", "next", "yes"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Out")
        #expect(engine.currentNode.veto == true)

        _ = try engine.select(edgeWhen: "report")
        #expect(engine.currentNode.id == "Form")
        #expect(engine.unreachableMarked == true)

        let whens = engine.visibleButtons.map(\.when)
        #expect(whens.contains("back-out"))
        #expect(whens.contains("erase"))
        #expect(!whens.contains("back-cont"))
    }

    @Test func goBackRestoresPreviousNode() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try engine.skipEntrySplashIfNeeded()
        #expect(engine.currentNode.id == "Disclaimer")
        #expect(engine.canGoBack == false)

        _ = try engine.select(edgeWhen: "agree")
        #expect(engine.currentNode.id == "Loc-mode")
        #expect(engine.canGoBack == true)

        engine.goBack()
        #expect(engine.currentNode.id == "Disclaimer")
    }
}
