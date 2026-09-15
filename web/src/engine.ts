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
import { type EngineRules, safetyQueue } from "./rules";
import type { LocalEventRecord } from "./eventStore";

function newStep(nodeId: string, edge: string | null): ProtocolLogStep {
  return {
    id: crypto.randomUUID(),
    nodeId,
    edge,
    at: new Date().toISOString(),
  };
}

/** Pure navigation over the protocol graph. Policy remaps from shared EngineRules. */
export class ProtocolEngine {
  graph: ProtocolGraph;
  rules: EngineRules;
  currentNode: ProtocolNode;
  locale: ContentLocale;
  sessionRole: SessionRole | null = null;
  incidentType: string | null = null;
  locationLine: string | null = null;
  locationLevel: number | null = null;
  /** Draft text for the current Loc-3 field. */
  manualLocationDraft = "";
  /** Index into manual location field keys while on Loc-3. */
  manualLocationFieldIndex = 0;
  private manualLocationValues: Record<string, string> = {};
  steps: ProtocolLogStep[] = [];
  unreachableMarked = false;
  lastVetoNodeId: string | null = null;
  multipleCasualties = false;

  eventId: string | null = null;
  eventStartedAt: string | null = null;
  reachedFormAt: string | null = null;
  waveRemindersScheduled = false;
  tourniquetOn: string | null = null;
  saltRedCount = 0;
  saltYellowCount = 0;
  saltGreenCount = 0;

  /** Seconds between scene re-checks (overridable in tests). */
  sceneRecheckInterval: number;
  lastSceneCheckAt: number | null = null;
  now: () => number = () => Date.now();

  private returnStack: string[] = [];
  private history: string[] = [];
  private pendingRecheckEdge: string | null = null;
  private suppressSceneRecheck = false;

  private static readonly defaultManualFields = [
    "settlement",
    "street",
    "building",
    "entrance",
  ];

  constructor(
    graph: ProtocolGraph,
    rules: EngineRules,
    locale: ContentLocale = "uk",
  ) {
    if (graph.commercial) {
      throw new Error("commercial must be false");
    }
    const entry = nodeById(graph, graph.entry);
    if (!entry) {
      throw new Error(`Missing entry node: ${graph.entry}`);
    }
    this.graph = graph;
    this.rules = rules;
    this.locale = locale;
    this.sceneRecheckInterval = rules.sceneRecheck.intervalSeconds;
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
      case "Loc-3":
        return this.manualLocationPrompt;
      case "A6":
        return this.a6VoiceForIncidentType();
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

  get isManualLocationEntry(): boolean {
    return this.currentNode.id === "Loc-3";
  }

  get manualLocationFieldKey(): string {
    const keys = this.manualLocationFieldKeys;
    return keys[this.manualLocationFieldIndex] ?? keys[0] ?? "settlement";
  }

  get manualLocationPrompt(): string {
    switch (this.manualLocationFieldKey) {
      case "settlement":
        return this.locale === "uk"
          ? "Назвіть населений пункт."
          : "Name the town or city.";
      case "street":
        return this.locale === "uk" ? "Вулиця." : "Street.";
      case "building":
        return this.locale === "uk" ? "Номер будинку." : "Building number.";
      case "entrance":
        return this.locale === "uk"
          ? "Підʼїзд, поверх чи орієнтир."
          : "Entrance, floor, or landmark.";
      default:
        return textFor(this.currentNode.voice, this.locale);
    }
  }

  get manualLocationPlaceholder(): string {
    switch (this.manualLocationFieldKey) {
      case "settlement":
        return this.locale === "uk" ? "наприклад, Бровари" : "e.g. Brovary";
      case "street":
        return this.locale === "uk"
          ? "наприклад, вул. Київська"
          : "e.g. Kyivska St.";
      case "building":
        return this.locale === "uk" ? "наприклад, 12" : "e.g. 12";
      case "entrance":
        return this.locale === "uk"
          ? "підʼїзд 3, поверх 2"
          : "entrance 3, floor 2";
      default:
        return "";
    }
  }

  get manualLocationSummary(): string | null {
    if (!this.isManualLocationEntry) return null;
    const parts = this.manualLocationFieldKeys
      .map((key) => this.manualLocationValues[key]?.trim())
      .filter((value): value is string => Boolean(value));
    return parts.length > 0 ? parts.join(", ") : null;
  }

  private get manualLocationFieldKeys(): string[] {
    const fromGraph = this.graph.nodes.find((n) => n.id === "Loc-3")?.ui
      ?.fields;
    return fromGraph && fromGraph.length > 0
      ? fromGraph
      : ProtocolEngine.defaultManualFields;
  }

  private a6VoiceForIncidentType(): string {
    switch (this.incidentType) {
      case "traffic":
        return this.locale === "uk"
          ? "Не стійте на проїзджій частині. Увімкніть аварійку. Не чіпайте проводи."
          : "Do not stand in the roadway. Turn on hazard lights. Do not touch wires.";
      case "fire":
        return this.locale === "uk"
          ? "Не заходьте в дим і полумʼя. Тримайтеся з навітряного боку. Не відкривайте гарячі двері."
          : "Do not enter smoke or flames. Stay upwind. Do not open hot doors.";
      case "chemical":
        return this.locale === "uk"
          ? "Не чіпайте рідину і плями. Не нюхайте. Відійдіть проти вітру, якщо можете."
          : "Do not touch liquid or stains. Do not smell it. Move upwind if you can.";
      case "household":
        return this.locale === "uk"
          ? "Вимкніть джерело небезпеки, якщо це безпечно. Не ризикуйте зайвий раз."
          : "Turn off the hazard source if it is safe. Do not take extra risks.";
      case "collapse":
      case "explosion":
      case "train":
      case "shooting":
        return this.locale === "uk"
          ? "Не заходьте всередину завалу. Не рухайте уламки."
          : "Do not enter the collapse. Do not move rubble.";
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
    if (this.currentNode.id !== "Disclaimer") return null;
    return this.locale === "uk"
      ? "Цей застосунок лише підказує кроки — рішення ваші. Закон сам по собі вас за допомогу не захищає."
      : "This app only suggests steps — the decisions are yours. The law alone does not protect you for helping.";
  }

  get showsHandoverQR(): boolean {
    return this.currentNode.id === "Give";
  }

  /** Payload encoded into the handover QR (same text medic sees / dispatcher hears). */
  get handoverQRPayload(): string {
    return this.dispatcherDraft;
  }

  get detailBlock(): string | null {
    switch (this.currentNode.id) {
      case "Loc-1":
        return this.demoAddressLine();
      case "Loc-2":
        return this.demoCoordinatesDisplay;
      case "Loc-3":
        return this.manualLocationSummary;
      case "Call":
      case "CALL-read":
      case "Read":
        return this.dispatcherDraft;
      case "Form":
      case "Give":
        return null;
      default:
        if (this.currentNode.ui?.showDispatcherDraft) {
          return this.dispatcherDraft;
        }
        return null;
    }
  }

  get showsBrigadeReportCard(): boolean {
    return this.currentNode.id === "Form";
  }

  get brigadeReportTitle(): string {
    return this.locale === "uk"
      ? "Чернетка для бригади"
      : "Draft for responders";
  }

  get brigadeReportFields(): { id: string; label: string; value: string }[] {
    const dash = "—";
    const typeValue = this.localizedIncidentTypeLabel() ?? dash;
    const placeValue = this.locationLine ?? dash;
    let roleValue = dash;
    if (this.sessionRole === "witness") {
      roleValue = this.locale === "uk" ? "Свідок" : "Witness";
    } else if (this.sessionRole === "casualty") {
      roleValue = this.locale === "uk" ? "Постраждалий" : "Casualty";
    }
    const casualtiesValue = this.saltCasualtiesShort() ?? dash;
    const tourniquetValue = this.tourniquetOn
      ? this.tourniquetClock(this.tourniquetOn)
      : this.locale === "uk"
        ? "Не накладено"
        : "Not applied";
    const facts = this.keyFactLines();
    const keyValue = facts.length === 0 ? dash : facts.join("; ");

    if (this.locale === "uk") {
      return [
        { id: "type", label: "Тип події", value: typeValue },
        { id: "place", label: "Місце", value: placeValue },
        { id: "role", label: "Роль", value: roleValue },
        { id: "casualties", label: "Постраждалі", value: casualtiesValue },
        { id: "tourniquet", label: "Час джгута", value: tourniquetValue },
        { id: "key", label: "Ключове", value: keyValue },
      ];
    }
    return [
      { id: "type", label: "Event type", value: typeValue },
      { id: "place", label: "Location", value: placeValue },
      { id: "role", label: "Role", value: roleValue },
      { id: "casualties", label: "Casualties", value: casualtiesValue },
      { id: "tourniquet", label: "Tourniquet time", value: tourniquetValue },
      { id: "key", label: "Key info", value: keyValue },
    ];
  }

  private saltCasualtiesShort(): string | null {
    const red = this.saltRedCount;
    const yellow = this.saltYellowCount;
    const green = this.saltGreenCount;
    const unreachable = this.unreachableMarked ? 1 : 0;
    const total = red + yellow + green + unreachable;
    if (total === 0) return null;
    if (this.locale === "uk") {
      if (total === 1) return "Один";
      const parts: string[] = [];
      if (red > 0) parts.push(`червоних ${red}`);
      if (yellow > 0) parts.push(`жовтих ${yellow}`);
      if (green > 0) parts.push(`зелених ${green}`);
      if (unreachable > 0) parts.push(`недосяжних ${unreachable}`);
      return parts.length === 0 ? "Кілька" : parts.join(", ");
    }
    if (total === 1) return "One";
    const parts: string[] = [];
    if (red > 0) parts.push(`red ${red}`);
    if (yellow > 0) parts.push(`yellow ${yellow}`);
    if (green > 0) parts.push(`green ${green}`);
    if (unreachable > 0) parts.push(`unreachable ${unreachable}`);
    return parts.length === 0 ? "Several" : parts.join(", ");
  }

  private tourniquetClock(iso: string): string {
    return new Intl.DateTimeFormat(
      this.locale === "uk" ? "uk-UA" : "en-GB",
      { hour: "2-digit", minute: "2-digit" },
    ).format(new Date(iso));
  }

  private demoAddressLine(): string {
    return this.locale === "uk"
      ? "Київська обл., м. Бровари, вул. Демо 12, підʼїзд 3"
      : "Kyiv region, Brovary, Demo St. 12, entrance 3";
  }

  private get demoCoordinatesDisplay(): string {
    return "50.51120° N\n30.79090° E";
  }

  private get demoCoordinatesDraft(): string {
    return "50.51120° N, 30.79090° E";
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
      // Top bar «Назад» covers history; never duplicate back-* here.
      // Always keep QR (give) — including after veto path Out/Cont/Out-trapped.
      buttons = buttons.filter((b) =>
        ["give", "handed", "wave", "erase"].includes(b.when),
      );
    }

    if (this.currentNode.id === "Loc-3") {
      const isLast =
        this.manualLocationFieldIndex >=
        this.manualLocationFieldKeys.length - 1;
      buttons = buttons.map((button) => {
        if (button.when !== "next") return button;
        return isLast
          ? { when: "next", ua: "Далі", en: "Next" }
          : { when: "next", ua: "Наступне поле", en: "Next field" };
      });
    }

    // Top bar already has «Назад» — never duplicate content Back buttons.
    if (this.canGoBack) {
      buttons = buttons.filter((button) => {
        if (button.when.startsWith("back-")) return false;
        const title = buttonTitle(button, this.locale);
        return title !== "Назад" && title !== "Back";
      });
    }

    return buttons;
  }

  /** Three or more peer choices — all secondary. Home/Form keep first button primary. */
  get usesEqualChoiceButtons(): boolean {
    if (this.currentNode.veto) return false;
    if (this.currentNode.id === "Home" || this.currentNode.id === "Form") {
      return false;
    }
    return this.visibleButtons.length >= 3;
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
      this.currentNode.id === this.rules.sceneRecheck.nodeId
    );
  }

  get dispatcherDraft(): string {
    const lines: string[] = [];
    const typeLabel = this.localizedIncidentTypeLabel();
    if (typeLabel) lines.push(`${typeLabel}.`);
    if (this.locationLine) lines.push(this.locationLine);
    const roleLabel = this.localizedRoleLabel();
    if (roleLabel) {
      lines.push(
        this.locale === "uk" ? `Я ${roleLabel}.` : `I am ${roleLabel}.`,
      );
    }
    const casualties = this.saltCasualtiesLine();
    if (casualties) lines.push(casualties);
    if (this.tourniquetOn) {
      lines.push(this.tourniquetLine(this.tourniquetOn));
    }
    const facts = this.keyFactLines();
    if (facts.length > 0) {
      const joined = facts.join("; ");
      lines.push(
        this.locale === "uk" ? `Зроблено: ${joined}.` : `Done: ${joined}.`,
      );
    }
    lines.push(
      this.locale === "uk" ? "Потрібна допомога." : "Help needed.",
    );
    return lines.join("\n");
  }

  private localizedIncidentTypeLabel(): string | null {
    if (!this.incidentType) return null;
    const typeNode = nodeById(this.graph, "Type");
    const button = typeNode?.ui?.buttons?.find(
      (b) => b.when === this.incidentType,
    );
    if (button) return buttonTitle(button, this.locale);
    return this.incidentType;
  }

  private localizedRoleLabel(): string | null {
    if (this.sessionRole === "witness") {
      return this.locale === "uk" ? "цивільний свідок" : "civilian bystander";
    }
    if (this.sessionRole === "casualty") {
      return this.locale === "uk" ? "постраждалий" : "casualty";
    }
    return null;
  }

  private saltCasualtiesLine(): string | null {
    const red = this.saltRedCount;
    const yellow = this.saltYellowCount;
    const green = this.saltGreenCount;
    const unreachable = this.unreachableMarked ? 1 : 0;
    if (red + yellow + green + unreachable === 0) return null;
    if (this.locale === "uk") {
      const parts: string[] = [];
      if (red > 0) parts.push(`червоних ${red}`);
      if (yellow > 0) parts.push(`жовтих ${yellow}`);
      if (green > 0) parts.push(`зелених ${green}`);
      if (unreachable > 0) parts.push(`недосяжних ${unreachable}`);
      return `Постраждалі: ${parts.join(", ")}.`;
    }
    const parts: string[] = [];
    if (red > 0) parts.push(`red ${red}`);
    if (yellow > 0) parts.push(`yellow ${yellow}`);
    if (green > 0) parts.push(`green ${green}`);
    if (unreachable > 0) parts.push(`unreachable ${unreachable}`);
    return `Casualties: ${parts.join(", ")}.`;
  }

  private tourniquetLine(iso: string): string {
    const time = new Intl.DateTimeFormat(
      this.locale === "uk" ? "uk-UA" : "en-GB",
      { timeStyle: "short" },
    ).format(new Date(iso));
    return this.locale === "uk"
      ? `Джгут накладено о ${time}.`
      : `Tourniquet applied at ${time}.`;
  }

  private keyFactLines(): string[] {
    const labels =
      this.locale === "uk"
        ? ({
            C0: "масивна кровотеча",
            C1: "тиск на рану",
            Hold: "триває тиск",
            Pack: "тампонада",
            Tq: "джгут",
            "Tq-time": "час джгута",
            Tq2: "другий джгут",
            Still: "кровотеча після джгута",
            Open: "відкрита рана грудей",
            Burp: "клапан / «відрижка» плівки",
            Crush: "завал / не звільняти",
            NoCpr: "без СЛР",
            NoResp: "не дихає",
            Deleg: "делеговано тиск",
          } as Record<string, string>)
        : ({
            C0: "massive bleeding",
            C1: "direct pressure",
            Hold: "holding pressure",
            Pack: "wound packing",
            Tq: "tourniquet",
            "Tq-time": "tourniquet time",
            Tq2: "second tourniquet",
            Still: "bleeding after tourniquet",
            Open: "open chest wound",
            Burp: "burp the seal",
            Crush: "crush — do not release",
            NoCpr: "no CPR",
            NoResp: "not breathing",
            Deleg: "pressure handed off",
          } as Record<string, string>);
    const seen = new Set<string>();
    const facts: string[] = [];
    for (let i = this.steps.length - 1; i >= 0; i -= 1) {
      const step = this.steps[i];
      const label = labels[step.nodeId];
      if (!label || seen.has(step.nodeId)) continue;
      seen.add(step.nodeId);
      facts.push(label);
      if (facts.length === 3) break;
    }
    return facts.reverse();
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
      return this.navigate(this.rules.sceneRecheck.nodeId, "recheck", true, true);
    }

    if (this.currentNode.id === this.rules.sceneRecheck.nodeId) {
      return this.handleSceneRecheck(edgeWhen);
    }

    if (this.currentNode.id === "Loc-3" && edgeWhen === "next") {
      return this.handleManualLocationNext();
    }

    const edge = this.currentNode.edges.find((e) => e.when === edgeWhen);
    if (!edge) {
      throw new Error(
        `Missing edge ${edgeWhen} on ${this.currentNode.id}`,
      );
    }

    this.captureSideEffects(edgeWhen);

    if (this.currentNode.id === "Home" && edgeWhen === "incident") {
      this.beginEventIfNeeded();
    }

    // Confirm on Erase → next only (do not wipe when opening the confirm screen).
    if (this.currentNode.id === "Erase" && edgeWhen === "next") {
      this.clearEventFields();
      return {
        didNavigate: false,
        externalURL: null,
        clearedLog: true,
      };
    }
    if (this.currentNode.id === "Handed" && edgeWhen === "erase") {
      this.clearEventFields();
      return {
        didNavigate: false,
        externalURL: null,
        clearedLog: true,
      };
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
          return { didNavigate: false, externalURL: url, clearedLog: false };
        }
      }
      const fromHandedKeep =
        this.currentNode.id === "Handed" && edgeWhen === "keep";
      const result = this.navigate(edge.to, edgeWhen, false, true);
      if (fromHandedKeep) {
        this.history = [];
        this.returnStack = [];
      }
      let shouldScheduleWaveReminders = false;
      if (
        this.currentNode.id === "Form" &&
        this.reachedFormAt == null &&
        this.eventStartedAt != null
      ) {
        this.reachedFormAt = new Date(this.now()).toISOString();
        if (!this.waveRemindersScheduled) {
          shouldScheduleWaveReminders = true;
        }
      }
      return {
        didNavigate: result.didNavigate,
        externalURL: null,
        clearedLog: false,
        shouldScheduleWaveReminders,
      };
    }

    this.steps.push(newStep(this.currentNode.id, edgeWhen));
    return {
      didNavigate: false,
      externalURL: this.externalURL(this.currentNode),
      clearedLog: false,
    };
  }

  private get shouldInterceptForSceneRecheck(): boolean {
    if (this.suppressSceneRecheck) {
      this.suppressSceneRecheck = false;
      return false;
    }
    const recheck = this.rules.sceneRecheck;
    if (this.currentNode.id === recheck.nodeId) return false;
    if (!recheck.careBranches.includes(this.currentNode.branch)) return false;
    if (this.lastSceneCheckAt == null) return false;
    return (
      (this.now() - this.lastSceneCheckAt) / 1000 >= this.sceneRecheckInterval
    );
  }

  private handleSceneRecheck(edgeWhen: string): EdgeSelectionResult {
    const recheck = this.rules.sceneRecheck;
    if (!this.currentNode.edges.some((e) => e.when === edgeWhen)) {
      throw new Error(`Missing edge ${edgeWhen} on ${recheck.nodeId}`);
    }
    if (edgeWhen === recheck.safeEdge) {
      this.lastSceneCheckAt = this.now();
      const pending = this.pendingRecheckEdge;
      this.pendingRecheckEdge = null;
      this.steps.push(newStep(recheck.nodeId, recheck.safeEdge));
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
    if (edgeWhen === recheck.threatEdge) {
      this.pendingRecheckEdge = null;
      this.lastSceneCheckAt = this.now();
      return this.navigate(
        recheck.threatTarget,
        recheck.threatEdge,
        false,
        true,
      );
    }
    throw new Error(`Missing edge ${edgeWhen} on ${recheck.nodeId}`);
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
    this.locationLine = null;
    this.locationLevel = null;
    this.resetManualLocationWizard();
    this.clearEventFields();
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

  get hasPersistableEvent(): boolean {
    return this.eventStartedAt != null;
  }

  get lastEventSummaryLine(): string | null {
    if (!this.eventStartedAt) return null;
    const started = new Date(this.eventStartedAt);
    const now = new Date();
    const startDay = new Date(started.getFullYear(), started.getMonth(), started.getDate());
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const diffDays = Math.round(
      (today.getTime() - startDay.getTime()) / (24 * 60 * 60 * 1000),
    );
    let day: string;
    if (diffDays === 0) {
      day = this.locale === "uk" ? "сьогодні" : "today";
    } else if (diffDays === 1) {
      day = this.locale === "uk" ? "вчора" : "yesterday";
    } else {
      day = new Intl.DateTimeFormat(
        this.locale === "uk" ? "uk-UA" : "en-GB",
        { dateStyle: "medium" },
      ).format(started);
    }
    const time = new Intl.DateTimeFormat(
      this.locale === "uk" ? "uk-UA" : "en-GB",
      { hour: "2-digit", minute: "2-digit" },
    ).format(started);
    return this.locale === "uk"
      ? `Остання подія · ${time}, ${day}`
      : `Last event · ${time}, ${day}`;
  }

  makeEventSnapshot(): LocalEventRecord | null {
    if (!this.eventId || !this.eventStartedAt) return null;
    return {
      eventId: this.eventId,
      startedAt: this.eventStartedAt,
      reachedFormAt: this.reachedFormAt,
      sessionRole: this.sessionRole,
      incidentType: this.incidentType,
      locationLine: this.locationLine,
      locationLevel: this.locationLevel,
      steps: this.steps,
      waveRemindersScheduled: this.waveRemindersScheduled,
      tourniquetOn: this.tourniquetOn,
      saltRedCount: this.saltRedCount,
      saltYellowCount: this.saltYellowCount,
      saltGreenCount: this.saltGreenCount,
    };
  }

  hydrate(record: LocalEventRecord): void {
    this.eventId = record.eventId;
    this.eventStartedAt = record.startedAt;
    this.reachedFormAt = record.reachedFormAt;
    this.sessionRole = record.sessionRole;
    this.incidentType = record.incidentType;
    this.locationLine = record.locationLine;
    this.locationLevel = record.locationLevel;
    this.steps = record.steps;
    this.waveRemindersScheduled = record.waveRemindersScheduled;
    this.tourniquetOn = record.tourniquetOn ?? null;
    this.saltRedCount = record.saltRedCount ?? 0;
    this.saltYellowCount = record.saltYellowCount ?? 0;
    this.saltGreenCount = record.saltGreenCount ?? 0;
  }

  markWaveRemindersScheduled(): void {
    this.waveRemindersScheduled = true;
  }

  openWaveChecklist(): void {
    const node = nodeById(this.graph, "I0");
    if (!node) throw new Error("Missing node I0");
    this.history = [];
    this.returnStack = [];
    this.currentNode = node;
  }

  openLastReport(): void {
    if (!this.hasPersistableEvent) return;
    const node = nodeById(this.graph, "Form");
    if (!node) throw new Error("Missing node Form");
    this.history = [];
    this.returnStack = [];
    this.currentNode = node;
  }

  private beginEventIfNeeded(): void {
    if (this.eventStartedAt != null) return;
    this.eventId = crypto.randomUUID();
    this.eventStartedAt = new Date(this.now()).toISOString();
    this.waveRemindersScheduled = false;
    this.reachedFormAt = null;
  }

  private clearEventFields(): void {
    this.eventId = null;
    this.eventStartedAt = null;
    this.reachedFormAt = null;
    this.waveRemindersScheduled = false;
    this.tourniquetOn = null;
    this.saltRedCount = 0;
    this.saltYellowCount = 0;
    this.saltGreenCount = 0;
    this.steps = [];
    this.locationLine = null;
    this.locationLevel = null;
    this.incidentType = null;
    this.sessionRole = null;
    this.unreachableMarked = false;
    this.lastVetoNodeId = null;
    this.multipleCasualties = false;
    this.resetManualLocationWizard();
  }

  private handleManualLocationNext(): EdgeSelectionResult {
    const trimmed = this.manualLocationDraft.trim();
    if (this.manualLocationFieldIndex === 0 && trimmed.length === 0) {
      return { didNavigate: false, externalURL: null, clearedLog: false };
    }
    const key = this.manualLocationFieldKey;
    if (trimmed.length === 0) {
      delete this.manualLocationValues[key];
    } else {
      this.manualLocationValues[key] = trimmed;
    }

    const keys = this.manualLocationFieldKeys;
    if (this.manualLocationFieldIndex + 1 < keys.length) {
      this.manualLocationFieldIndex += 1;
      const nextKey = keys[this.manualLocationFieldIndex];
      this.manualLocationDraft = this.manualLocationValues[nextKey] ?? "";
      return { didNavigate: false, externalURL: null, clearedLog: false };
    }

    const line = this.composeManualLocationLine();
    if (!line) {
      return { didNavigate: false, externalURL: null, clearedLog: false };
    }
    this.locationLevel = 3;
    this.locationLine = line;
    return this.navigate("Type", "next", false, true);
  }

  private composeManualLocationLine(): string {
    return this.manualLocationFieldKeys
      .map((key) => this.manualLocationValues[key]?.trim())
      .filter((value): value is string => Boolean(value))
      .join(", ");
  }

  private resetManualLocationWizard(): void {
    this.manualLocationFieldIndex = 0;
    this.manualLocationValues = {};
    this.manualLocationDraft = "";
  }

  private navigate(
    id: string,
    edgeWhen: string,
    pushReturn: boolean,
    recordHistory: boolean,
  ): EdgeSelectionResult {
    let targetId = this.remapSafetyTarget(id, edgeWhen);
    if (this.sessionRole === "casualty") {
      targetId = this.remapCasualtyTarget(targetId);
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
    this.captureLocationIfNeeded(next.id);
    this.captureReportArrival(next.id, leavingId, edgeWhen);
    if (leavingId === this.rules.sceneRecheck.armAfterLeavingNodeId) {
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

  private captureLocationIfNeeded(id: string): void {
    switch (id) {
      case "Loc-1":
        this.locationLevel = 1;
        this.locationLine = this.demoAddressLine();
        break;
      case "Loc-2":
        this.locationLevel = 2;
        this.locationLine = this.demoCoordinatesDraft;
        break;
      case "Loc-3":
        this.locationLevel = 3;
        this.resetManualLocationWizard();
        break;
      default:
        break;
    }
  }

  private captureReportArrival(
    arrivedAt: string,
    leavingId: string,
    edgeWhen: string,
  ): void {
    switch (arrivedAt) {
      case "Red":
        this.saltRedCount += 1;
        break;
      case "Yellow":
        this.saltYellowCount += 1;
        break;
      case "Green":
      case "Green2":
        this.saltGreenCount += 1;
        break;
      case "Tq-time":
        if (!this.tourniquetOn) {
          this.tourniquetOn = new Date(this.now()).toISOString();
        }
        break;
      default:
        break;
    }
    if (leavingId === "Tq" && edgeWhen === "next" && !this.tourniquetOn) {
      this.tourniquetOn = new Date(this.now()).toISOString();
    }
  }

  private remapCasualtyTarget(targetId: string): string {
    const c = this.rules.casualty;
    if (c.redirectNodeIds.includes(targetId)) return c.redirectTo;
    const branch = nodeById(this.graph, targetId)?.branch;
    if (branch && c.redirectBranches.includes(branch)) return c.redirectTo;
    return c.targetRemaps[targetId] ?? targetId;
  }

  private remapSafetyTarget(targetId: string, edgeWhen: string): string {
    const queue = safetyQueue(this.rules, this.incidentType);
    const safety = this.rules.safety;

    if (
      targetId === safety.entryTarget &&
      safety.roleEntryNodeIds.includes(this.currentNode.id)
    ) {
      return queue[0] ?? safety.entryTarget;
    }

    if (
      safety.threatIds.includes(this.currentNode.id) &&
      safety.advanceOnEdges.includes(edgeWhen)
    ) {
      const idx = queue.indexOf(this.currentNode.id);
      if (idx >= 0 && idx + 1 < queue.length) {
        return queue[idx + 1]!;
      }
      return safety.fallbackNext;
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
