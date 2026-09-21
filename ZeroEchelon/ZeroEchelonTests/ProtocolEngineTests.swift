import Foundation
import Testing
@testable import ZeroEchelon

@MainActor
struct ProtocolEngineTests {
    private func protocolRoot() -> URL {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return testsDir
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("protocol/graphs/zero-echelon-core")
    }

    private func loadPackage() throws -> ProtocolPackage {
        if let graphURL = Bundle.main.url(forResource: "graph", withExtension: "json"),
           let rulesURL = Bundle.main.url(forResource: "engine-rules", withExtension: "json")
        {
            return ProtocolPackage(
                graph: try GraphLoader.load(from: graphURL),
                rules: try GraphLoader.loadRules(from: rulesURL)
            )
        }
        let root = protocolRoot()
        return ProtocolPackage(
            graph: try GraphLoader.load(from: root.appendingPathComponent("graph.json")),
            rules: try GraphLoader.loadRules(from: root.appendingPathComponent("engine-rules.json"))
        )
    }

    private func loadGraph() throws -> ProtocolGraph {
        try loadPackage().graph
    }

    private func makeEngine(locale: ContentLocale = .uk) throws -> ProtocolEngine {
        try ProtocolEngine(package: try loadPackage(), locale: locale)
    }

    private func reachCare(engine: ProtocolEngine, role: String) throws {
        for edge in ["next", "incident", "agree", "gnss", "next", "explosion", role, "next", "no", "no", "no", "no", "no", "next"] {
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
            "Home", "Count", "Casualty-menu", "C0", "D0", "E0", "Anti", "E2", "Vent", "E3", "Burp", "Watch",
            "F0", "Form", "I0", "J0", "CanLeave", "A7",
            "B2", "B3", "Second", "Br", "Kid", "Four", "Red", "Yellow", "Green2", "NoResp", "NoCpr-stay",
            "G2", "G3", "Flags", "Organic", "Ground", "Slow", "Ban",
            "Local", "Pos", "Side", "Comf",
        ] {
            #expect(graph.node(id: id) != nil, "missing \(id)")
        }
        #expect(graph.node(id: "NEXT-PHASE") == nil)
        #expect(graph.node(id: "Loc-1") == nil)
    }

    @Test func witnessPathReachesBleeding() throws {
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Count")
        _ = try engine.select(edgeWhen: "one")
        #expect(engine.currentNode.id == "C0")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "D0")
    }

    @Test func casualtyPathOpensSelfMenu() throws {
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "casualty")
        _ = try engine.select(edgeWhen: "next-casualty")
        #expect(engine.currentNode.id == "Casualty-menu")
        _ = try engine.select(edgeWhen: "crush")
        #expect(engine.currentNode.id == "F0")
    }

    @Test func threatCanLeaveTrapped() throws {
        let engine = try makeEngine()
        for edge in ["next", "incident", "agree", "gnss", "next", "collapse", "witness", "next", "yes", "no"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Out-trapped")
    }

    @Test func noBleedPathReachesFormViaChestCrush() throws {
        let engine = try makeEngine()
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
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "witness")
        #expect(engine.incidentType == "explosion")
        #expect(engine.dispatcherDraft.hasPrefix("Вибух."))
        #expect(!engine.dispatcherDraft.contains("explosion"))
        #expect(engine.dispatcherDraft.contains("50.51120"))
        #expect(!engine.dispatcherDraft.contains("місце вже на екрані"))
        engine.locale = .en
        #expect(engine.dispatcherDraft.hasPrefix("Explosion."))
    }

    @Test func homeOffersIncidentDailyAndWave() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        #expect(engine.currentNode.id == "Home")
        let whens = Set(engine.visibleButtons.map(\.when))
        #expect(whens == Set(["incident", "daily", "wave"]))
    }

    @Test func homeDailyGoesToJ0() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "daily")
        #expect(engine.currentNode.id == "J0")
    }

    @Test func dailyAllergyLocalOnlyGoesLocalThenForm() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "daily")
        _ = try engine.select(edgeWhen: "allergy")
        #expect(engine.currentNode.id == "Ana")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "Local")
        #expect(engine.voiceText.contains("Холод"))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Form")
    }

    @Test func dailyStrokePosYesGoesSide() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "daily")
        _ = try engine.select(edgeWhen: "stroke")
        #expect(engine.currentNode.id == "Str")
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Pos")
        _ = try engine.select(edgeWhen: "yes")
        #expect(engine.currentNode.id == "Side")
        #expect(engine.voiceText.contains("бік"))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Form")
    }

    @Test func dailyPoisonPosNoGoesComf() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "daily")
        _ = try engine.select(edgeWhen: "poison")
        #expect(engine.currentNode.id == "Poi")
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Pos")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "Comf")
        #expect(engine.voiceText.contains("Зручно"))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Form")
    }

    @Test func homeWaveGoesToI0() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "wave")
        #expect(engine.currentNode.id == "I0")
    }

    @Test func incidentPathShowsDisclaimerBeforeLoc() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")
        #expect(engine.currentNode.id == "Disclaimer")
        _ = try engine.select(edgeWhen: "agree")
        #expect(engine.currentNode.id == "Loc-mode")
    }

    @Test func locModeOffersGpsAndManualOnly() throws {
        let engine = try makeEngine()
        for edge in ["next", "incident", "agree"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Loc-mode")
        let whens = Set(engine.visibleButtons.map(\.when))
        #expect(whens == Set(["gnss", "manual"]))
        #expect(!whens.contains("qr"))
    }

    @Test func manualAddressFillsDispatcherDraft() throws {
        let engine = try makeEngine()
        for edge in ["next", "incident", "agree", "manual"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Loc-3")
        #expect(engine.voiceText.contains("адресу"))
        engine.manualLocationDraft = "Бровари, вул. Київська 12, підʼїзд 3"
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "Type")
        #expect(engine.locationLine == "Бровари, вул. Київська 12, підʼїзд 3")
        _ = try engine.select(edgeWhen: "fire")
        _ = try engine.select(edgeWhen: "witness")
        _ = try engine.select(edgeWhen: "next")
        while engine.currentNode.id != "Call" {
            if engine.currentNode.id == "A6" {
                _ = try engine.select(edgeWhen: "next")
            } else {
                _ = try engine.select(edgeWhen: "no")
            }
        }
        #expect(engine.dispatcherDraft.contains("Бровари"))
        #expect(engine.dispatcherDraft.contains("підʼїзд 3"))
        #expect(!engine.dispatcherDraft.contains("демо"))
    }

    @Test func readScreenShowsDispatcherDraft() throws {
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "one")
        _ = try engine.select(edgeWhen: "no") // D0
        _ = try engine.select(edgeWhen: "yes") // D2
        _ = try engine.select(edgeWhen: "yes") // Sup
        _ = try engine.select(edgeWhen: "next") // Neck
        _ = try engine.select(edgeWhen: "next") // E0
        _ = try engine.select(edgeWhen: "no") // F0
        _ = try engine.select(edgeWhen: "no") // G0
        for edge in ["next", "next", "next", "no", "next", "next", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Form")
        #expect(engine.showsBrigadeReportCard)
        #expect(engine.brigadeReportFields.contains(where: { $0.value.contains("Вибух") }))
        #expect(engine.dispatcherDraft.contains("Вибух"))
        #expect(!engine.dispatcherDraft.isEmpty)

        _ = try engine.select(edgeWhen: "give")
        #expect(engine.currentNode.id == "Give")
        #expect(engine.showsHandoverQR)
        #expect(engine.handoverQRPayload == engine.dispatcherDraft)
        #expect(!engine.handoverQRPayload.isEmpty)
    }

    @Test func dispatcherDraftUsesCoordinatesAfterGpsPath() throws {
        let engine = try makeEngine()
        for edge in ["next", "incident", "agree", "gnss", "next", "traffic", "witness"] {
            _ = try engine.select(edgeWhen: edge)
        }
        // On Role-witness; location captured on Loc-2
        #expect(engine.locationLine?.contains("50.51120") == true)
        // Finish role → safety → Call
        _ = try engine.select(edgeWhen: "next")
        while engine.currentNode.id != "Call" {
            if engine.currentNode.id == "A6" {
                #expect(engine.voiceText.contains("проїзджій") || engine.voiceText.contains("roadway"))
                _ = try engine.select(edgeWhen: "next")
            } else {
                _ = try engine.select(edgeWhen: "no")
            }
        }
        #expect(engine.dispatcherDraft.contains("50.51120"))
        #expect(engine.dispatcherDraft.hasPrefix("ДТП."))
        #expect(!engine.dispatcherDraft.contains("місце вже на екрані"))
    }

    @Test func trafficA6AvoidsCollapseWording() throws {
        let engine = try makeEngine()
        try reachFirstSafety(engine: engine, type: "traffic")
        while engine.currentNode.id != "A6" {
            _ = try engine.select(edgeWhen: "no")
        }
        #expect(engine.currentNode.id == "A6")
        #expect(engine.voiceText.contains("проїзджій"))
        #expect(!engine.voiceText.contains("завалу"))
    }

    @Test func noCprSingleCasualtyAvoidsNextPersonVoice() throws {
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "one") // C0
        #expect(engine.multipleCasualties == false)
        _ = try engine.select(edgeWhen: "no") // C0 → D0
        _ = try engine.select(edgeWhen: "no") // D0 → D1 (не дихає)
        _ = try engine.select(edgeWhen: "yes") // D1 → NoCpr-stay
        #expect(engine.currentNode.id == "NoCpr-stay")
        #expect(!engine.voiceText.lowercased().contains("наступн"))
        #expect(!engine.voiceText.lowercased().contains("next"))
        #expect(engine.visibleButtons.contains(where: { $0.ua == "Залишаюсь" }))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "E0")
    }

    @Test func noCprSeveralCasualtiesGoesToNextPerson() throws {
        let engine = try makeEngine()
        try reachCare(engine: engine, role: "witness")
        _ = try engine.select(edgeWhen: "next") // Count
        _ = try engine.select(edgeWhen: "many")
        #expect(engine.multipleCasualties == true)
        try engine.setCurrentNodeForTesting("D1")
        _ = try engine.select(edgeWhen: "yes")
        #expect(engine.currentNode.id == "NoCpr")
        #expect(engine.voiceText.contains("наступного"))
        #expect(engine.visibleButtons.contains(where: { $0.ua == "Йду далі" }))
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.currentNode.id == "E0")
    }

    @Test func chestWoundWithoutSealGoesOpenThenF0() throws {
        let engine = try makeEngine()
        try reachE0(engine: engine)
        for edge in ["yes", "next", "next", "no", "next"] {
            // E0→E1→Anti→E2 no→Open→F0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "F0")
    }

    @Test func chestWoundWithSealBurpsThenF0() throws {
        let engine = try makeEngine()
        try reachE0(engine: engine)
        for edge in ["yes", "next", "next", "yes", "next", "yes", "next"] {
            // E0→E1→Anti→E2 yes→Vent→E3 yes→Burp→F0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "F0")
    }

    @Test func sceneRecheckSafeResumesPendingEdge() throws {
        let engine = try makeEngine()
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
        let engine = try makeEngine()
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
        let engine = try makeEngine()
        try reachFirstStill(engine: engine)
        for edge in ["next", "yes", "bad", "next"] {
            // First→Br yes→Four bad→Red→C0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "C0")
    }

    @Test func saltNoBreathAdultGoesNoRespThenHelpC0() throws {
        let engine = try makeEngine()
        try reachFirstStill(engine: engine)
        for edge in ["next", "no", "no", "next", "no", "help"] {
            // First→Br no→Kid no→One→Again no→NoResp→help→C0
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "C0")
    }

    @Test func saltFourSignsGoodYellowReturnsToB2() throws {
        let engine = try makeEngine()
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
        let engine = try makeEngine()
        try reachG0(engine: engine)
        for edge in ["next", "next", "next", "no", "next", "next", "next"] {
            // G0→G1→G2→G3 no→Ground→Slow→Ban→Form
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Form")
    }

    @Test func gOrganicFlagsPathReachesBanThenForm() throws {
        let engine = try makeEngine()
        try reachG0(engine: engine)
        for edge in ["next", "next", "next", "yes", "yes", "next", "next"] {
            // G0→G1→G2→G3 yes→Flags yes→Organic→Ban→Form
            _ = try engine.select(edgeWhen: edge)
        }
        #expect(engine.currentNode.id == "Form")
    }

    /// Disclaimer → loc → Type(type) → Role witness → first safety node.
    private func reachFirstSafety(engine: ProtocolEngine, type: String) throws {
        for edge in ["next", "incident", "agree", "gnss", "next", type, "witness", "next"] {
            _ = try engine.select(edgeWhen: edge)
        }
    }

    @Test func trafficSafetySkipsUXOStartsAtWires() throws {
        let engine = try makeEngine()
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
        let engine = try makeEngine()
        try reachFirstSafety(engine: engine, type: "fire")
        #expect(engine.currentNode.id == "A3")
        _ = try engine.select(edgeWhen: "no")
        #expect(engine.currentNode.id == "A4")
    }

    @Test func explosionSafetyStillStartsAtUXO() throws {
        let engine = try makeEngine()
        try reachFirstSafety(engine: engine, type: "explosion")
        #expect(engine.currentNode.id == "A1")
    }

    @Test func dispatcherDraftIncludesTourniquetAndSalt() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")

        try engine.setCurrentNodeForTesting("Four")
        _ = try engine.select(edgeWhen: "bad")
        #expect(engine.currentNode.id == "Red")
        #expect(engine.saltRedCount == 1)
        #expect(engine.dispatcherDraft.contains("червоних 1"))

        try engine.setCurrentNodeForTesting("Tq")
        _ = try engine.select(edgeWhen: "next")
        #expect(engine.tourniquetOn != nil)
        #expect(engine.currentNode.id == "Tq-time")
        #expect(engine.dispatcherDraft.contains("Джгут накладено"))
        #expect(engine.dispatcherDraft.contains("Зроблено:"))
    }

    @Test func handedKeepReturnsHomeAndKeepsEvent() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")
        try engine.setCurrentNodeForTesting("Form")
        _ = try engine.select(edgeWhen: "handed")
        #expect(engine.currentNode.id == "Handed")
        let keep = try engine.select(edgeWhen: "keep")
        #expect(keep.clearedLog == false)
        #expect(engine.currentNode.id == "Home")
        #expect(engine.hasPersistableEvent)
        #expect(engine.canGoBack == false)
    }

    @Test func handedEraseClearsEvent() throws {
        let engine = try makeEngine()
        try engine.skipEntrySplashIfNeeded()
        _ = try engine.select(edgeWhen: "incident")
        try engine.setCurrentNodeForTesting("Handed")
        let erased = try engine.select(edgeWhen: "erase")
        #expect(erased.clearedLog == true)
        #expect(engine.hasPersistableEvent == false)
    }
}
