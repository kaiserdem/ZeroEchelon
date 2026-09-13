export interface SceneRecheckRules {
  nodeId: string;
  intervalSeconds: number;
  careBranches: string[];
  armAfterLeavingNodeId: string;
  safeEdge: string;
  threatEdge: string;
  threatTarget: string;
}

export interface SafetyRules {
  entryTarget: string;
  roleEntryNodeIds: string[];
  threatIds: string[];
  advanceOnEdges: string[];
  fallbackNext: string;
  queuesByIncidentType: Record<string, string[]>;
}

export interface CasualtyRules {
  redirectNodeIds: string[];
  redirectBranches: string[];
  redirectTo: string;
  targetRemaps: Record<string, string>;
}

export interface EngineRules {
  schemaVersion: string;
  protocolGraphId?: string;
  notes?: string;
  sceneRecheck: SceneRecheckRules;
  safety: SafetyRules;
  casualty: CasualtyRules;
}

export function safetyQueue(
  rules: EngineRules,
  incidentType: string | null,
): string[] {
  const key = incidentType ?? "default";
  return (
    rules.safety.queuesByIncidentType[key] ??
    rules.safety.queuesByIncidentType.default ?? [
      rules.safety.entryTarget,
      rules.safety.fallbackNext,
    ]
  );
}
