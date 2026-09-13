import {
  type ContentLocale,
  type EdgeSelectionResult,
  type ProtocolButton,
  type ProtocolGraph,
  type ProtocolLogStep,
  type ProtocolNode,
  type SessionRole,
  buttonTitle,
  nodeById,
  primaryButtons,
  textFor,
} from "./types";

function newStep(nodeId: string, edge: string | null): ProtocolLogStep {
  return {
    id: crypto.randomUUID(),
    nodeId,
    edge,
    at: new Date().toISOString(),
  };
}

const CARE_BRANCHES = new Set(["B", "C", "D", "E", "F", "G"]);

/** Pure navigation over the protocol graph. No clinical branching outside edges. */
export class ProtocolEngine {
  graph: ProtocolGraph;
  currentNode: ProtocolNode;
  locale: ContentLocale;
  sessionRole: SessionRole | null = null;
  incidentType: string | null = null;
  steps: ProtocolLogStep[] = [];
  unreachableMarked = false;
  lastVetoNodeId: string | null = null;
  multipleCasualties = false;

  /** Seconds between scene re-checks while in care branches B–G (default 3 min). */
  sceneRecheckInterval = 180;
  lastSceneCheckAt: number | null = null;
  now: () => number = () => Date.now();

  private returnStack: string[] = [];
  private history: string[] = [];
  private pendingRecheckEdge: string | null = null;
  private suppressSceneRecheck = false;

  constructor(graph: ProtocolGraph, locale: ContentLocale = "uk") {
    if (graph.commercial) {
      throw new Error("commercial must be false");
    }
    const entry = nodeById(graph, graph.entry);
    if (!entry) {
      throw new Error(`Missing entry node: ${graph.entry}`);
    }
    this.graph = graph;
    this.locale = locale;
    this.currentNode = entry;
  }

  skipEntrySplashIfNeeded(): void {
    if (this.currentNode.id !== "Start") return;
    this.select("next");
    this.history = [];
    this.steps = [];
  }

  get voiceText(): string {
    switch (this.currentNode.id) {
      case "Loc-1":
        return this.locale === "uk"
          ? "Місце з QR-коду на стіні:"
          : "Location from the wall QR code:";
      case "NoCpr":
        if (this.sessionRole === "casualty" || !this.multipleCasualties) {
          return this.locale === "uk"
            ? "Реанімація тут не допоможе. Залишайтесь. Натисніть 103 внизу."
            : "CPR will not help here. Stay. Tap 103 below.";
        }
        return textFor(this.currentNode.voice, this.locale);
      default:
        return textFor(this.currentNode.voice, this.locale);
    }
  }

  get antiPatternText(): string | null {
    return this.currentNode.antiPattern
      ? textFor(this.currentNode.antiPattern, this.locale)
      : null;
  }

  get helperText(): string | null {
    return null;
  }

  get detailBlock(): string | null {
    switch (this.currentNode.id) {
      case "Loc-1":
        return this.locale === "uk"
          ? "Київська обл., м. Бровари, вул. Демо 12, підʼїзд 3"
          : "Kyiv region, Brovary, Demo St. 12, entrance 3";
      case "Loc-2":
        return "50.51120° N\n30.79090° E";
      case "Call":
      case "CALL-read":
        return this.dispatcherDraft;
      default:
        if (this.currentNode.ui?.showDispatcherDraft) {
          return this.dispatcherDraft;
        }
        return null;
    }
  }

  get screenBadge(): string {
    return this.currentNode.ui?.screenId ?? this.currentNode.id;
  }

  get canGoBack(): boolean {
    return this.history.length > 0;
  }

  get visibleButtons(): ProtocolButton[] {
    let buttons = primaryButtons(this.currentNode).filter(
      (b) => b.when !== "dial" && b.when !== "dial-101",
    );

    if (this.currentNode.id === "Call") {
      if (this.sessionRole === "casualty") {
        buttons = buttons
          .filter((b) => b.when !== "next")
          .map((b) =>
            b.when === "next-casualty"
              ? { when: b.when, ua: "Далі", en: "Next" }
              : b,
          );
      } else {
        buttons = buttons
          .filter((b) => b.when !== "next-casualty")
          .map((b) =>
            b.when === "next" ? { when: b.when, ua: "Далі", en: "Next" } : b,
          );
      }
    }

    if (this.currentNode.id === "Form") {
      if (this.lastVetoNodeId) {
        let backWhen = "back-out";
        if (this.lastVetoNodeId === "Cont") backWhen = "back-cont";
        if (this.lastVetoNodeId === "Out-trapped") backWhen = "back-trapped";
        buttons = buttons.filter(
          (b) => b.when === backWhen || b.when === "erase",
        );
      } else {
        buttons = buttons.filter((b) =>
          ["read", "give", "erase"].includes(b.when),
        );
      }
    }

    if (this.currentNode.id === "Loc-mode") {
      buttons = [
        {
          when: "qr",
          ua: "З QR на стіні (демо)",
          en: "From wall QR (demo)",
        },
        {
          when: "gnss",
          ua: "Мої координати (GPS)",
          en: "My coordinates (GPS)",
        },
        {
          when: "manual",
          ua: "Введу адресу сам",
          en: "I will type the address",
        },
      ];
    }

    return buttons;
  }

  get showsRescue101(): boolean {
    return (
      this.currentNode.veto ||
      this.currentNode.id === "CanLeave" ||
      this.currentNode.branch === "A" ||
      this.currentNode.id === "Form"
    );
  }

  get prioritize101(): boolean {
    return (
      this.currentNode.veto ||
      this.currentNode.id === "CanLeave" ||
      this.currentNode.id === "A7"
    );
  }

  get dispatcherDraft(): string {
    const place =
      this.locale === "uk"
        ? "місце вже на екрані локації"
        : "place already on the location screen";
    const type = this.localizedIncidentTypeLabel();
    let role: string;
    if (this.sessionRole === "witness") {
      role = this.locale === "uk" ? "цивільний свідок" : "civilian bystander";
    } else if (this.sessionRole === "casualty") {
      role = this.locale === "uk" ? "постраждалий" : "casualty";
    } else {
      role = this.locale === "uk" ? "роль ще не обрана" : "role not set";
    }
    if (this.locale === "uk") {
      return `${type}. ${place}. Потрібна допомога. Я ${role}.`;
    }
    return `${type}. ${place}. Help needed. I am ${role}.`;
  }

  private localizedIncidentTypeLabel(): string {
    if (!this.incidentType) {
      return this.locale === "uk" ? "тип ще не обрано" : "type not set";
    }
    const typeNode = nodeById(this.graph, "Type");
    const button = typeNode?.ui?.buttons?.find(
      (b) => b.when === this.incidentType,
    );
    if (button) return buttonTitle(button, this.locale);
    return this.incidentType;
  }

  goBack(): void {
    const previousId = this.history.pop();
    if (!previousId) return;
    const node = nodeById(this.graph, previousId);
    if (!node) return;
    this.currentNode = node;
  }

  select(edgeWhen: string): EdgeSelectionResult {
    if (
      this.currentNode.id === "Form" &&
      (edgeWhen === "back-out" ||
        edgeWhen === "back-cont" ||
        edgeWhen === "back-trapped")
    ) {
      let targetId = "Out";
      if (edgeWhen === "back-cont") targetId = "Cont";
      if (edgeWhen === "back-trapped") targetId = "Out-trapped";
      return this.navigate(targetId, edgeWhen, false, true);
    }

    if (this.shouldInterceptForSceneRecheck) {
      this.pendingRecheckEdge = edgeWhen;
      return this.navigate("A7", "recheck", true, true);
    }

    if (this.currentNode.id === "A7") {
      return this.handleA7(edgeWhen);
    }

    const edge = this.currentNode.edges.find((e) => e.when === edgeWhen);
    if (!edge) {
      throw new Error(
        `Missing edge ${edgeWhen} on ${this.currentNode.id}`,
      );
    }

    this.captureSideEffects(edgeWhen);

    let cleared = false;
    if (edgeWhen === "erase") {
      this.steps = [];
      cleared = true;
    }
    if (this.currentNode.id === "Erase" && edgeWhen === "next") {
      this.steps = [];
      cleared = true;
    }
    if (edgeWhen === "report") {
      this.unreachableMarked = true;
      this.lastVetoNodeId = this.currentNode.id;
    }

    if (edge.to) {
      const isCall =
        this.graph.alwaysAvailable.includes(edge.to) ||
        edge.to.startsWith("CALL");
      if (isCall) {
        const url = this.externalURL(nodeById(this.graph, edge.to));
        if (url) {
          this.steps.push(newStep(this.currentNode.id, edgeWhen));
          return { didNavigate: false, externalURL: url, clearedLog: cleared };
        }
      }
      const result = this.navigate(edge.to, edgeWhen, false, true);
      return {
        didNavigate: result.didNavigate,
        externalURL: null,
        clearedLog: cleared,
      };
    }

    this.steps.push(newStep(this.currentNode.id, edgeWhen));
    return {
      didNavigate: false,
      externalURL: this.externalURL(this.currentNode),
      clearedLog: cleared,
    };
  }

  private get shouldInterceptForSceneRecheck(): boolean {
    if (this.suppressSceneRecheck) {
      this.suppressSceneRecheck = false;
      return false;
    }
    if (this.currentNode.id === "A7") return false;
    if (!CARE_BRANCHES.has(this.currentNode.branch)) return false;
    if (this.lastSceneCheckAt == null) return false;
    return (
      (this.now() - this.lastSceneCheckAt) / 1000 >= this.sceneRecheckInterval
    );
  }

  private handleA7(edgeWhen: string): EdgeSelectionResult {
    if (!this.currentNode.edges.some((e) => e.when === edgeWhen)) {
      throw new Error(`Missing edge ${edgeWhen} on A7`);
    }
    switch (edgeWhen) {
      case "safe": {
        this.lastSceneCheckAt = this.now();
        const pending = this.pendingRecheckEdge;
        this.pendingRecheckEdge = null;
        this.steps.push(newStep("A7", "safe"));
        const resumeId = this.returnStack.pop();
        if (resumeId) {
          const resumeNode = nodeById(this.graph, resumeId);
          if (resumeNode) this.currentNode = resumeNode;
        }
        this.suppressSceneRecheck = true;
        if (pending) {
          return this.select(pending);
        }
        return { didNavigate: true, externalURL: null, clearedLog: false };
      }
      case "threat":
        this.pendingRecheckEdge = null;
        this.lastSceneCheckAt = this.now();
        return this.navigate("CanLeave", "threat", false, true);
      default:
        throw new Error(`Missing edge ${edgeWhen} on A7`);
    }
  }

  finishExternalAndReturn(): void {
    const previous = this.returnStack.pop();
    if (!previous) return;
    const node = nodeById(this.graph, previous);
    if (!node) return;
    this.currentNode = node;
  }

  reset(): void {
    const entry = nodeById(this.graph, this.graph.entry);
    if (!entry) throw new Error(`Missing entry node: ${this.graph.entry}`);
    this.currentNode = entry;
    this.sessionRole = null;
    this.incidentType = null;
    this.steps = [];
    this.unreachableMarked = false;
    this.lastVetoNodeId = null;
    this.multipleCasualties = false;
    this.lastSceneCheckAt = null;
    this.pendingRecheckEdge = null;
    this.suppressSceneRecheck = false;
    this.returnStack = [];
    this.history = [];
    this.skipEntrySplashIfNeeded();
  }

  private navigate(
    id: string,
    edgeWhen: string,
    pushReturn: boolean,
    recordHistory: boolean,
  ): EdgeSelectionResult {
    let targetId = this.remapSafetyTarget(id, edgeWhen);
    if (this.sessionRole === "casualty") {
      if (targetId === "Count" || this.nextIsBranchB(targetId)) {
        targetId = "Casualty-menu";
      } else {
        switch (targetId) {
          case "Hands":
            targetId = "Hold";
            break;
          case "D2":
            targetId = "Sup";
            break;
          case "NoCpr":
            targetId = "E0";
            break;
          default:
            break;
        }
      }
    }

    const next = nodeById(this.graph, targetId);
    if (!next) {
      throw new Error(`Missing node: ${targetId}`);
    }
    const leavingId = this.currentNode.id;
    this.steps.push(newStep(leavingId, edgeWhen));
    if (pushReturn) this.returnStack.push(leavingId);
    if (recordHistory) this.history.push(leavingId);
    this.currentNode = next;
    if (leavingId === "A6") {
      this.lastSceneCheckAt = this.now();
    }
    const role = next.ui?.sessionRole;
    if (role === "witness" || role === "casualty") {
      this.sessionRole = role;
    }
    return {
      didNavigate: true,
      externalURL: this.externalURL(next),
      clearedLog: false,
    };
  }

  private nextIsBranchB(id: string): boolean {
    return nodeById(this.graph, id)?.branch === "B";
  }

  private static readonly safetyThreatIds = new Set([
    "A1",
    "A2",
    "A3",
    "A4",
    "A5",
  ]);

  /** Threat checks A1–A5 relevant to incidentType (docs/01 A0). A6 always last. */
  private safetyThreatQueue(type: string | null): string[] {
    switch (type) {
      case "explosion":
      case "shooting":
      case "train":
        return ["A1", "A2", "A3", "A4", "A5", "A6"];
      case "collapse":
        return ["A2", "A1", "A3", "A4", "A5", "A6"];
      case "fire":
        return ["A3", "A4", "A5", "A2", "A6"];
      case "traffic":
        return ["A4", "A3", "A5", "A6"];
      case "chemical":
        return ["A5", "A3", "A4", "A6"];
      case "household":
        return ["A3", "A4", "A5", "A6"];
      default:
        return ["A1", "A2", "A3", "A4", "A5", "A6"];
    }
  }

  private remapSafetyTarget(targetId: string, edgeWhen: string): string {
    const queue = this.safetyThreatQueue(this.incidentType);

    if (
      targetId === "A1" &&
      (this.currentNode.id === "Role-witness" ||
        this.currentNode.id === "Role-casualty")
    ) {
      return queue[0] ?? "A1";
    }

    if (
      ProtocolEngine.safetyThreatIds.has(this.currentNode.id) &&
      (edgeWhen === "no" || edgeWhen === "cannot")
    ) {
      const idx = queue.indexOf(this.currentNode.id);
      if (idx >= 0 && idx + 1 < queue.length) {
        return queue[idx + 1]!;
      }
      return "A6";
    }

    return targetId;
  }

  private captureSideEffects(edgeWhen: string): void {
    switch (this.currentNode.id) {
      case "Type":
        this.incidentType = edgeWhen;
        break;
      case "Role":
        if (edgeWhen === "witness" || edgeWhen === "casualty") {
          this.sessionRole = edgeWhen;
        }
        break;
      case "Count":
        this.multipleCasualties =
          edgeWhen === "many" || edgeWhen === "unknown";
        break;
      default:
        break;
    }
  }

  private externalURL(node: ProtocolNode | undefined): string | null {
    return node?.ui?.external ?? null;
  }
}
