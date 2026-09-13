import Foundation

struct EngineRules: Codable, Hashable, Sendable {
    var schemaVersion: String
    var protocolGraphId: String?
    var notes: String?
    var sceneRecheck: SceneRecheckRules
    var safety: SafetyRules
    var casualty: CasualtyRules
}

struct SceneRecheckRules: Codable, Hashable, Sendable {
    var nodeId: String
    var intervalSeconds: Double
    var careBranches: [String]
    var armAfterLeavingNodeId: String
    var safeEdge: String
    var threatEdge: String
    var threatTarget: String
}

struct SafetyRules: Codable, Hashable, Sendable {
    var entryTarget: String
    var roleEntryNodeIds: [String]
    var threatIds: [String]
    var advanceOnEdges: [String]
    var fallbackNext: String
    var queuesByIncidentType: [String: [String]]
}

struct CasualtyRules: Codable, Hashable, Sendable {
    var redirectNodeIds: [String]
    var redirectBranches: [String]
    var redirectTo: String
    var targetRemaps: [String: String]
}

extension EngineRules {
    var careBranchSet: Set<String> { Set(sceneRecheck.careBranches) }
    var threatIdSet: Set<String> { Set(safety.threatIds) }
    var roleEntrySet: Set<String> { Set(safety.roleEntryNodeIds) }
    var advanceEdgeSet: Set<String> { Set(safety.advanceOnEdges) }
    var casualtyRedirectNodeSet: Set<String> { Set(casualty.redirectNodeIds) }
    var casualtyRedirectBranchSet: Set<String> { Set(casualty.redirectBranches) }

    func safetyQueue(for incidentType: String?) -> [String] {
        let key = incidentType ?? "default"
        return safety.queuesByIncidentType[key]
            ?? safety.queuesByIncidentType["default"]
            ?? [safety.entryTarget, safety.fallbackNext]
    }
}
