export type ContentLocale = "uk" | "en";
export type SessionRole = "witness" | "casualty";

export interface LocalizedText {
  ua: string;
  en: string;
}

export interface ProtocolEdge {
  when: string;
  to?: string | null;
}

export interface ProtocolButton {
  when: string;
  ua: string;
  en: string;
}

export interface ProtocolNodeUI {
  screenId?: string;
  template?: string;
  buttons?: ProtocolButton[];
  external?: string;
  showDispatcherDraft?: boolean;
  stub?: boolean;
  markUnreachable?: boolean;
  clearsLocalLog?: boolean;
  layout?: string;
  locationLevel?: number;
  sessionRole?: string;
  note?: string;
  /** Ordered address fields for Loc-3 (settlement → street → …). */
  fields?: string[];
}

export interface ProtocolNode {
  id: string;
  type: string;
  branch: string;
  roles: SessionRole[];
  precedence: number;
  registry: string[];
  conflict: string[];
  veto: boolean;
  handsBusy: boolean;
  delegationRequired: boolean;
  voice: LocalizedText;
  antiPattern?: LocalizedText | null;
  edges: ProtocolEdge[];
  ui?: ProtocolNodeUI | null;
}

export interface ProtocolGraph {
  schemaVersion: string;
  protocolGraphId: string;
  graphVersion?: string;
  locale: string[];
  commercial: boolean;
  entry: string;
  alwaysAvailable: string[];
  invariants: string[];
  nodes: ProtocolNode[];
}

export interface ProtocolLogStep {
  id: string;
  nodeId: string;
  edge: string | null;
  at: string;
}

export interface EdgeSelectionResult {
  didNavigate: boolean;
  externalURL: string | null;
  clearedLog: boolean;
  shouldScheduleWaveReminders?: boolean;
}

export function textFor(text: LocalizedText, locale: ContentLocale): string {
  return locale === "uk" ? text.ua : text.en;
}

export function buttonTitle(button: ProtocolButton, locale: ContentLocale): string {
  return locale === "uk" ? button.ua : button.en;
}

const DEFAULT_LABELS: Record<ContentLocale, Record<string, string>> = {
  uk: {
    yes: "Так",
    no: "Ні",
    cannot: "Не можу",
    next: "Далі",
    agree: "Погоджуюсь",
    dial: "Набрати",
    read: "Зачитати",
    edit: "Виправити",
    report: "Звіт",
    erase: "Стерти",
    "dial-101": "Викликати 101",
    "back-out": "Назад",
    "back-cont": "Назад",
    "back-trapped": "Назад",
  },
  en: {
    yes: "Yes",
    no: "No",
    cannot: "Cannot",
    next: "Next",
    agree: "I agree",
    dial: "Dial",
    read: "Read aloud",
    edit: "Correct",
    report: "Report",
    erase: "Erase",
    "dial-101": "Call 101",
    "back-out": "Back",
    "back-cont": "Back",
    "back-trapped": "Back",
  },
};

export function primaryButtons(node: ProtocolNode): ProtocolButton[] {
  const fromUi = node.ui?.buttons;
  if (fromUi && fromUi.length > 0) {
    return fromUi.filter((button) =>
      node.edges.some((edge) => edge.when === button.when),
    );
  }
  return node.edges.map((edge) => ({
    when: edge.when,
    ua: DEFAULT_LABELS.uk[edge.when] ?? edge.when,
    en: DEFAULT_LABELS.en[edge.when] ?? edge.when,
  }));
}

export function nodeById(graph: ProtocolGraph, id: string): ProtocolNode | undefined {
  return graph.nodes.find((node) => node.id === id);
}
