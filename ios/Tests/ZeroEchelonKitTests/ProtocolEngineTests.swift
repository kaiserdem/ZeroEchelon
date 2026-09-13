import Foundation
import Testing
import ZeroEchelonKit

struct ProtocolEngineTests {
    private func loadGraph() throws -> ProtocolGraph {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let iosDir = testsDir.deletingLastPathComponent().deletingLastPathComponent()
        let url = iosDir
            .deletingLastPathComponent()
            .appendingPathComponent("protocol/graphs/zero-echelon-core/graph.json")
        return try GraphLoader.load(from: url)
    }

    @Test func loadsGraphAndRejectsCommercialTrue() throws {
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

        let titles = engine.visibleButtons.map(\.when)
        #expect(titles.contains("back-out"))
        #expect(titles.contains("erase"))
        #expect(!titles.contains("back-cont"))
    }
}
