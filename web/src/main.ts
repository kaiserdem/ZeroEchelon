import graphJson from "@protocol/graphs/zero-echelon-core/graph.json";
import rulesJson from "@protocol/graphs/zero-echelon-core/engine-rules.json";
import { ProtocolEngine } from "./engine";
import {
  clearLocalEvent,
  loadLocalEvent,
  saveLocalEvent,
  scheduleWaveNotifications,
} from "./eventStore";
import {
  canDictate,
  isDictating,
  speak,
  startDictation,
  stopDictation,
  stopSpeaking,
} from "./speech";
import type { EngineRules } from "./rules";
import type { ContentLocale, EdgeSelectionResult, ProtocolGraph } from "./types";
import { buttonTitle } from "./types";
import "./styles.css";

const graph = graphJson as ProtocolGraph;
const rules = rulesJson as EngineRules;
const appRoot = document.querySelector<HTMLDivElement>("#app");
if (!appRoot) throw new Error("#app missing");
const root: HTMLDivElement = appRoot;

const engine = new ProtocolEngine(graph, rules, "uk");
engine.skipEntrySplashIfNeeded();

const stored = loadLocalEvent();
if (stored) {
  engine.hydrate(stored);
}

let speakOnAppear = true;
let lastSpokenKey = "";

function dial(number: string): void {
  window.location.href = `tel:${number}`;
}

function persistNow(): void {
  const snapshot = engine.makeEventSnapshot();
  if (snapshot) saveLocalEvent(snapshot);
}

function applyPersistence(result: EdgeSelectionResult): void {
  if (result.clearedLog) {
    clearLocalEvent();
    engine.reset();
    return;
  }

  persistNow();

  if (result.shouldScheduleWaveReminders && engine.eventStartedAt) {
    void scheduleWaveNotifications(engine.eventStartedAt, engine.locale).then(
      (ok) => {
        if (!ok) return;
        engine.markWaveRemindersScheduled();
        persistNow();
      },
    );
  }
}

function handleSelect(when: string): void {
  stopDictation();
  const result = engine.select(when);
  if (result.externalURL) {
    window.location.href = result.externalURL;
  }
  applyPersistence(result);
  render({ keepFocus: engine.isManualLocationEntry });
}

function render(options?: { keepFocus?: boolean }): void {
  const isVeto = engine.currentNode.veto;
  const locale = engine.locale;
  const buttons = engine.visibleButtons;
  const isType = engine.currentNode.id === "Type";
  const prioritize101 = engine.prioritize101;
  const show101 = engine.showsRescue101;
  const emphasizeCall = engine.currentNode.id === "Call";
  const listening = isDictating();

  const actionsClass = isType ? "actions type-grid" : "actions";
  const actionHtml = buttons
    .map((button, index) => {
      if (isType) {
        const title = buttonTitle(button, locale);
        const src = `type-icons/type_${encodeURIComponent(button.when)}.png`;
        return `<button type="button" class="type-icon-btn" data-when="${escapeAttr(button.when)}" aria-label="${escapeAttr(title)}"><img src="${src}" alt="" width="56" height="56" decoding="async" /><span>${escapeHtml(title)}</span></button>`;
      }
      const primary = index === 0 || isVeto;
      let cls = "action-btn secondary";
      if (isVeto) cls = "action-btn veto";
      else if (primary) cls = "action-btn primary";
      return `<button type="button" class="${cls}" data-when="${escapeAttr(button.when)}">${escapeHtml(buttonTitle(button, locale))}</button>`;
    })
    .join("");

  let emergencyHtml: string;
  if (prioritize101 && show101) {
    emergencyHtml = `
      <p class="emergency-hint">${escapeHtml(priorityHint(locale))}</p>
      <button type="button" class="dial-101 primary" data-dial="101">${escapeHtml(locale === "uk" ? "ВИКЛИКАТИ 101 (ДСНС)" : "CALL 101 (rescue)")}</button>
      <button type="button" class="dial-103 outline" data-dial="103">${escapeHtml(locale === "uk" ? "Викликати 103" : "Call 103")}</button>
    `;
  } else {
    emergencyHtml = `
      <button type="button" class="dial-103${emphasizeCall ? " emphasis" : ""}" data-dial="103">${escapeHtml(locale === "uk" ? "ВИКЛИКАТИ 103" : "CALL 103")}</button>
      ${
        show101
          ? `<button type="button" class="dial-101" data-dial="101">${escapeHtml(locale === "uk" ? "Викликати 101 (ДСНС)" : "Call 101 (rescue)")}</button>`
          : ""
      }
    `;
  }

  const anti = engine.antiPatternText;
  const detail = engine.detailBlock;
  const helper = engine.helperText;
  const lastEvent =
    engine.currentNode.id === "Home" && engine.lastEventSummaryLine
      ? `
      <div class="last-event">
        <p class="last-event-title">${escapeHtml(engine.lastEventSummaryLine)}</p>
        ${
          engine.locationLine
            ? `<p class="last-event-loc">${escapeHtml(engine.locationLine)}</p>`
            : ""
        }
        <button type="button" class="last-event-btn" data-open-report>${escapeHtml(locale === "uk" ? "Відкрити звіт" : "Open report")}</button>
      </div>
    `
      : "";
  const manual = engine.isManualLocationEntry
    ? `
      <div class="loc-input-row">
        <input
          type="text"
          class="loc-input"
          data-loc-input
          autocomplete="street-address"
          enterkeyhint="next"
          placeholder="${escapeAttr(engine.manualLocationPlaceholder)}"
          value="${escapeAttr(engine.manualLocationDraft)}"
        />
        ${
          canDictate()
            ? `<button type="button" class="mic-btn${listening ? " listening" : ""}" data-mic aria-label="${locale === "uk" ? "Диктовка" : "Dictate"}">${listening ? "⏹" : "🎤"}</button>`
            : ""
        }
      </div>
    `
    : "";

  root.innerHTML = `
    <div class="frame${isVeto ? " is-veto" : ""}">
      <p class="demo-banner">${locale === "uk" ? "Веб-демо · не App Store" : "Web demo · not App Store"}</p>
      <header class="top-bar">
        ${
          engine.canGoBack
            ? `<button type="button" class="back-btn" data-back>‹ ${locale === "uk" ? "Назад" : "Back"}</button>`
            : `<span class="top-brand" aria-label="Line 24">Line 24</span>`
        }
        <span class="top-spacer"></span>
        <div class="locale" role="group" aria-label="Language">
          <button type="button" data-locale="uk" class="${locale === "uk" ? "active" : ""}">UA</button>
          <button type="button" data-locale="en" class="${locale === "en" ? "active" : ""}">EN</button>
        </div>
        <button type="button" class="voice-toggle" data-voice aria-label="${locale === "uk" ? "Голос" : "Voice"}">${speakOnAppear ? "🔊" : "🔇"}</button>
      </header>
      <div class="divider"></div>
      <main class="content">
        <div class="badge-row">
          <span class="badge">${escapeHtml(engine.screenBadge)}</span>
          <span class="badge-mark" aria-hidden="true"></span>
        </div>
        <h1 class="voice">${escapeHtml(engine.voiceText)}</h1>
        ${helper ? `<p class="helper">${escapeHtml(helper)}</p>` : ""}
        ${
          anti
            ? `<div class="anti" role="alert">⚠ ${escapeHtml(anti)}</div>`
            : ""
        }
        ${
          detail
            ? `<div class="detail${engine.currentNode.id === "Loc-2" ? " coords" : ""}">${escapeHtml(detail)}</div>`
            : ""
        }
        ${manual}
        <div class="${actionsClass}">${actionHtml}</div>
        ${lastEvent}
      </main>
      <footer class="emergency">${emergencyHtml}</footer>
    </div>
  `;

  bind();
  if (options?.keepFocus) {
    const input = root.querySelector<HTMLInputElement>("[data-loc-input]");
    input?.focus();
    const len = input?.value.length ?? 0;
    input?.setSelectionRange(len, len);
  }

  const spokenKey = `${engine.currentNode.id}:${engine.manualLocationFieldIndex}:${engine.voiceText}`;
  if (speakOnAppear && spokenKey !== lastSpokenKey) {
    lastSpokenKey = spokenKey;
    speak(engine.voiceText, locale);
  }
}

function priorityHint(locale: ContentLocale): string {
  return locale === "uk"
    ? "Спочатку 101. 103 — якщо є поранені на безпечній відстані"
    : "101 first. 103 — if casualties are at a safe distance";
}

function bind(): void {
  root.querySelector("[data-back]")?.addEventListener("click", () => {
    stopDictation();
    engine.goBack();
    render();
  });

  root.querySelector("[data-open-report]")?.addEventListener("click", () => {
    engine.openLastReport();
    render();
  });

  root.querySelectorAll<HTMLButtonElement>("[data-locale]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const value = btn.dataset.locale;
      if (value === "uk" || value === "en") {
        engine.locale = value;
        render();
      }
    });
  });

  root.querySelector("[data-voice]")?.addEventListener("click", () => {
    speakOnAppear = !speakOnAppear;
    if (!speakOnAppear) stopSpeaking();
    render();
  });

  const locInput = root.querySelector<HTMLInputElement>("[data-loc-input]");
  locInput?.addEventListener("input", () => {
    engine.manualLocationDraft = locInput.value;
  });
  locInput?.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      event.preventDefault();
      handleSelect("next");
    }
  });

  root.querySelector("[data-mic]")?.addEventListener("click", () => {
    if (isDictating()) {
      stopDictation();
      render({ keepFocus: true });
      return;
    }
    const started = startDictation(engine.locale, (text) => {
      engine.manualLocationDraft = text;
      render({ keepFocus: true });
    });
    if (started) render({ keepFocus: true });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-when]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const when = btn.dataset.when;
      if (!when) return;
      try {
        handleSelect(when);
      } catch (error) {
        console.error(error);
      }
    });
  });

  root.querySelectorAll<HTMLButtonElement>("[data-dial]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const number = btn.dataset.dial;
      if (number) dial(number);
    });
  });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function escapeAttr(value: string): string {
  return escapeHtml(value).replaceAll("'", "&#39;");
}

window.addEventListener("pagehide", () => persistNow());
window.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "hidden") persistNow();
});
window.addEventListener("line24-open-wave", () => {
  try {
    engine.openWaveChecklist();
    render();
  } catch (error) {
    console.error(error);
  }
});

try {
  render();
} catch (error) {
  root.innerHTML = `<p class="error">${escapeHtml(String(error))}</p>`;
}
