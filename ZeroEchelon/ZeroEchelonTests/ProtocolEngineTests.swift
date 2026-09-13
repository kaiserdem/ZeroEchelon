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

    /// Witness, one casualty, no bleed, breathing OK, stay → Neck → E0.
    private func reachE0(engine: ProtocolEngine) throws {
        try reachCare(engine: engine, role: "witness")
        for edge in ["next", "one", "no", "yes", "yes", "next", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "E0")
    }

    @Test func graphContainsS6S12Core() throws {
        let graph = try loadGraph()
        for id in [
            "Count", "Casualty-menu", "C0", "D0", "E0", "Anti", "E2", "Vent", "E3", "Burp", "Watch",
            "F0", "Form", "I0", "J0", "CanLeave", "A7",
            "B2", "B3", "Second", "Br", "Kid", "Four", "Red", "Yellow", "Green2", "NoResp",
            "G2", "G3", "Flags", "Organic", "Ground", "Slow", "Ban",
        ] {
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
        // calm PFA path: G0→G1→G2→G3 no→Ground→Slow→Ban→Form
        for edge in ["next", "next", "next", "no", "next", "next", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
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

    @Test func chestWoundWithoutSealGoesOpenThenF0() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachE0(engine: engine)
        for edge in ["yes", "next", "next", "no", "next"] {
            // E0→E1→Anti→E2 no→Open→F0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "F0")
    }

    @Test func chestWoundWithSealBurpsThenF0() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachE0(engine: engine)
        for edge in ["yes", "next", "next", "yes", "next", "yes", "next"] {
            // E0→E1→Anti→E2 yes→Vent→E3 yes→Burp→F0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "F0")
    }

    @Test func sceneRecheckSafeResumesPendingEdge() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count (sets lastSceneCheck via A6→Call earlier)
        _ = try engine.select(edgeWhen: "one") // C0
        #expect(engine.currentNode.id == "C0")
        #expect(engine.lastSceneCheckAt != nil)

        engine.sceneRecheckInterval = 0
        engine.setLastSceneCheckAtForTesting(Date(timeIntervalSinceNow: -1))

        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "A7")

        _ = try engine.select(edgeWhen: "safe")
        #expect(engine.currentNode.id == "D0")
    }

    @Test func sceneRecheckThreatGoesToCanLeave() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next")
        _ = try engine.select(edgeWhen: "one")
        #expect(engine.currentNode.id == "C0")

        engine.sceneRecheckInterval = 0
        engine.setLastSceneCheckAtForTesting(Date(timeIntervalSinceNow: -1))

        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "A7")

        _ = try engine.select(edgeWhen: "threat")
        #expect(engine.currentNode.id == "CanLeave")
    }

    /// Count→many through B0… to First (individual assessment entry).
    private func reachFirstStill(engine: ProtocolEngine) throws {
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "many") // B0
        _ = try engine.select(edgeWhen: "next") // B1
        _ = try engine.select(edgeWhen: "no") // B2
        _ = try engine.select(edgeWhen: "next") // B3
        _ = try engine.select(edgeWhen: "no") // First
        #expect(engine.currentNode.id == "First")
    }

    @Test func saltFourSignsBadGoesRedThenC0() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstStill(engine: engine)
        for edge in ["next", "yes", "bad", "next"] {
            // First→Br yes→Four bad→Red→C0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "C0")
    }

    @Test func saltNoBreathAdultGoesNoRespThenHelpC0() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstStill(engine: engine)
        for edge in ["next", "no", "no", "next", "no", "help"] {
            // First→Br no→Kid no→One→Again no→NoResp→help→C0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "C0")
    }

    @Test func saltFourSignsGoodYellowReturnsToB2() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstStill(engine: engine)
        for edge in ["next", "yes", "good", "no", "more"] {
            // First→Br yes→Four good→Minor no→Yellow→more→B2
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "B2")
    }

    private func reachG0(engine: ProtocolEngine) throws {
        try reachCare(engine: engine, role: "witness")
        for edge in ["next", "one", "no", "yes", "yes", "next", "next", "no", "no"] {
            // Count→C0→D0→D2→Sup→Neck→E0→F0→G0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "G0")
    }

    @Test func gCalmPathReachesForm() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachG0(engine: engine)
        for edge in ["next", "next", "next", "no", "next", "next", "next"] {
            // G0→G1→G2→G3 no→Ground→Slow→Ban→Form
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Form")
    }

    @Test func gOrganicFlagsPathReachesBanThenForm() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachG0(engine: engine)
        for edge in ["next", "next", "next", "yes", "yes", "next", "next"] {
            // G0→G1→G2→G3 yes→Flags yes→Organic→Ban→Form
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Form")
    }

    /// Disclaimer → loc → Type(type) → Role witness → first safety node.
    private func reachFirstSafety(engine: ProtocolEngine, type: String) throws {
        for edge in ["next", "agree", "qr", "next", type, "witness", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
    }

    @Test func trafficSafetySkipsUXOStartsAtWires() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstSafety(engine: engine, type: "traffic")
        #expect(engine.currentNode.id == "A4")
        var seen = [engine.currentNode.id]
        while engine.currentNode.id != "Call", seen.count < 10 {
            if engine.currentNode.id == "A6" {
                _ = try engine.select(edgeWhen: "next")
            } else {
                _ = try engine.select(edgeWhen: "no")
            }
            seen.append(engine.currentNode.id)
        }
        #expect(!seen.contains("A1"))
        #expect(seen.contains("A3"))
        #expect(seen.contains("A5"))
        #expect(engine.currentNode.id == "Call")
    }

    @Test func fireSafetyStartsAtSmoke() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstSafety(engine: engine, type: "fire")
        #expect(engine.currentNode.id == "A3")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "A4")
    }

    @Test func explosionSafetyStillStartsAtUXO() throws {
        let engine = try ProtocolEngine(graph: try loadGraph())
        try reachFirstSafety(engine: engine, type: "explosion")
        #expect(engine.currentNode.id == "A1")
    }
}
