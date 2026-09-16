import graphJson from "@protocol/graphs/zero-echelon-core/graph.json";
import rulesJson from "@protocol/graphs/zero-echelon-core/engine-rules.json";
import QRCode from "qrcode";
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
import "@fontsource/inter/400.css";
import "@fontsource/inter/500.css";
import "@fontsource/inter/600.css";
import "./styles.css";

const graph = graphJson as ProtocolGraph;
const rules = rulesJson as EngineRules;
const appRoot = document.querySelector<HTMLDivElement>("#app");
if (!appRoot) throw new Error("#app missing");
const root: HTMLDivElement = appRoot;

const PREFS = {
  locale: "line24.locale",
  speak: "line24.speakOnAppear",
} as const;

const LEGAL = {
  privacy: "https://kaiserdem.github.io/ZeroEchelon/legal/privacy.html",
  support: "https://kaiserdem.github.io/ZeroEchelon/legal/support.html",
  terms: "https://kaiserdem.github.io/ZeroEchelon/legal/terms.html",
} as const;

function loadLocale(): ContentLocale {
  const raw = localStorage.getItem(PREFS.locale);
  return raw === "en" || raw === "uk" ? raw : "uk";
}

function loadSpeak(): boolean {
  const raw = localStorage.getItem(PREFS.speak);
  return raw === null ? true : raw === "true";
}

const engine = new ProtocolEngine(graph, rules, loadLocale());
engine.skipEntrySplashIfNeeded();

const stored = loadLocalEvent();
if (stored) {
  engine.hydrate(stored);
}

let speakOnAppear = loadSpeak();
let settingsPage: null | 'main' | 'language' = null;
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
      const equalChoices = engine.usesEqualChoiceButtons;
      const primary = isVeto || (!equalChoices && index === 0);
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
  const brigadeCard = engine.showsBrigadeReportCard
    ? `
      <div class="report-card">
        <h2 class="report-card-title">${escapeHtml(engine.brigadeReportTitle)}</h2>
        <dl class="report-card-fields">
          ${engine.brigadeReportFields
            .map(
              (field) => `
            <div class="report-card-row">
              <dt>${escapeHtml(field.label)}</dt>
              <dd><span class="report-card-sep">—</span> ${escapeHtml(field.value)}</dd>
            </div>
          `,
            )
            .join("")}
        </dl>
      </div>
    `
    : "";
  const lastEvent =
    engine.currentNode.id === "Home" && engine.lastEventSummaryLine
      ? `
      <div class="last-event">
        <p class="last-event-title">${escapeHtml(engine.lastEventSummaryLine)}</p>
        <button type="button" class="last-event-btn" data-open-report>${escapeHtml(locale === "uk" ? "Відкрити звіт ›" : "Open report ›")}</button>
      </div>
    `
      : "";
  const handoverQR = engine.showsHandoverQR
    ? `
      <div class="qr-block">
        <img class="qr-image" data-qr-image alt="${escapeAttr(locale === "uk" ? "QR-код звіту для медика" : "Report QR code for medic")}" width="280" height="280" />
        <p class="qr-fallback" hidden data-qr-fallback>${escapeHtml(locale === "uk" ? "QR зараз недоступний. Поверніться до звіту." : "QR unavailable. Go back to the report.")}</p>
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

  if (settingsPage === "language") {
    const languages: { id: ContentLocale; name: string }[] = [
      { id: "uk", name: "Українська" },
      { id: "en", name: "English" },
    ];
    root.innerHTML = `
    <div class="frame settings-screen">
      <header class="top-bar">
        <button type="button" class="back-btn" data-settings-back-main>‹ ${locale === "uk" ? "Назад" : "Back"}</button>
        <span class="top-spacer"></span>
        <span class="top-brand settings-title">${escapeHtml(locale === "uk" ? "Мова" : "Language")}</span>
        <span class="top-spacer"></span>
      </header>
      <main class="content settings-content">
        <p class="settings-hint">${escapeHtml(locale === "uk" ? "Оберіть мову додатку" : "Choose app language")}</p>
        <div class="settings-card" role="listbox" aria-label="${escapeAttr(locale === "uk" ? "Мова" : "Language")}">
          ${languages
            .map(
              (item) => `
            <button type="button" class="settings-choice${locale === item.id ? " selected" : ""}" data-locale="${item.id}" role="option" aria-selected="${locale === item.id}">
              <span>${escapeHtml(item.name)}</span>
              ${locale === item.id ? '<span class="settings-check" aria-hidden="true">✓</span>' : ""}
            </button>
          `,
            )
            .join("")}
        </div>
      </main>
    </div>
  `;
    bind();
    return;
  }

  if (settingsPage === "main") {
    const languageName = locale === "uk" ? "Українська" : "English";
    root.innerHTML = `
    <div class="frame settings-screen">
      <header class="top-bar">
        <button type="button" class="back-btn" data-settings-close>‹ ${locale === "uk" ? "Назад" : "Back"}</button>
        <span class="top-spacer"></span>
        <span class="top-brand settings-title">${escapeHtml(locale === "uk" ? "Налаштування" : "Settings")}</span>
        <span class="top-spacer"></span>
      </header>
      <main class="content settings-content">
        <section class="settings-block">
          <h3>${escapeHtml(locale === "uk" ? "Інтерфейс" : "Interface")}</h3>
          <div class="settings-card">
            <button type="button" class="settings-nav-row" data-open-language>
              <span>${escapeHtml(locale === "uk" ? "Мова" : "Language")}</span>
              <span class="settings-nav-value">${escapeHtml(languageName)} ›</span>
            </button>
            <div class="settings-row settings-row-pad">
              <span>${escapeHtml(locale === "uk" ? "Озвучення екранів" : "Speak screens aloud")}</span>
              <button type="button" class="settings-toggle${speakOnAppear ? " on" : ""}" data-voice data-in-settings>
                ${speakOnAppear ? (locale === "uk" ? "Увімк" : "On") : locale === "uk" ? "Вимк" : "Off"}
              </button>
            </div>
          </div>
        </section>
        <section class="settings-block">
          <h3>${escapeHtml(locale === "uk" ? "Про додаток" : "About")}</h3>
          <div class="settings-card">
            <a class="settings-link" href="${LEGAL.privacy}" target="_blank" rel="noopener">${escapeHtml(locale === "uk" ? "Політика конфіденційності" : "Privacy Policy")}</a>
            <a class="settings-link" href="${LEGAL.support}" target="_blank" rel="noopener">${escapeHtml(locale === "uk" ? "Підтримка" : "Support")}</a>
            <a class="settings-link" href="${LEGAL.terms}" target="_blank" rel="noopener">${escapeHtml(locale === "uk" ? "Умови користування" : "Terms of Use")}</a>
          </div>
          <p class="settings-version">Line 24 · web</p>
        </section>
      </main>
    </div>
  `;
    bind();
    return;
  }

  const docksActions = !["Home", "Type", "Form", "Give"].includes(
    engine.currentNode.id,
  );

  root.innerHTML = `
    <div class="frame${isVeto ? " is-veto" : ""}">
      <header class="top-bar">
        ${
          engine.canGoBack
            ? `<button type="button" class="back-btn" data-back>‹ ${locale === "uk" ? "Назад" : "Back"}</button>`
            : `<span class="top-brand" aria-label="Line 24">Line 24</span>`
        }
        <span class="top-spacer"></span>
        <button type="button" class="voice-toggle" data-voice aria-label="${locale === "uk" ? "Голос" : "Voice"}">${speakOnAppear ? "🔊" : "🔇"}</button>
        <button type="button" class="settings-btn" data-settings aria-label="${locale === "uk" ? "Налаштування" : "Settings"}">⚙</button>
      </header>
      <div class="divider"></div>
      <main class="content${docksActions ? " content-dock" : " content-home"}">
        <div class="content-body">
          <h1 class="voice">${escapeHtml(engine.voiceText)}</h1>
          ${helper ? `<p class="helper">${escapeHtml(helper)}</p>` : ""}
          ${
            anti
              ? `<div class="anti" role="alert">⚠ ${escapeHtml(anti)}</div>`
              : ""
          }
          ${brigadeCard}
          ${
            !brigadeCard && detail
              ? `<div class="detail${engine.currentNode.id === "Loc-2" ? " coords" : ""}">${escapeHtml(detail)}</div>`
              : ""
          }
          ${handoverQR}
          ${manual}
          ${
            !docksActions
              ? `<div class="${actionsClass}">${actionHtml}</div>${lastEvent}`
              : ""
          }
        </div>
        ${
          docksActions
            ? `<div class="actions-dock"><div class="${actionsClass}">${actionHtml}</div></div>`
            : ""
        }
      </main>
      <footer class="emergency">${emergencyHtml}</footer>
    </div>
  `;

  bind();
  void fillHandoverQR();
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

async function fillHandoverQR(): Promise<void> {
  const img = root.querySelector<HTMLImageElement>("[data-qr-image]");
  if (!img || !engine.showsHandoverQR) return;

  const fallback = root.querySelector<HTMLElement>("[data-qr-fallback]");
  try {
    const url = await QRCode.toDataURL(engine.handoverQRPayload, {
      errorCorrectionLevel: "M",
      margin: 2,
      width: 280,
      color: { dark: "#0a0f2d", light: "#ffffff" },
    });
    if (!root.contains(img)) return;
    img.src = url;
    img.hidden = false;
    if (fallback) fallback.hidden = true;
  } catch (error) {
    console.error(error);
    if (!root.contains(img)) return;
    img.hidden = true;
    if (fallback) fallback.hidden = false;
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

  root.querySelector("[data-settings]")?.addEventListener("click", () => {
    settingsPage = "main";
    render();
  });

  root.querySelector("[data-settings-close]")?.addEventListener("click", () => {
    settingsPage = null;
    render();
  });

  root.querySelector("[data-settings-back-main]")?.addEventListener("click", () => {
    settingsPage = "main";
    render();
  });

  root.querySelector("[data-open-language]")?.addEventListener("click", () => {
    settingsPage = "language";
    render();
  });

  root.querySelectorAll<HTMLButtonElement>("[data-locale]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const value = btn.dataset.locale;
      if (value === "uk" || value === "en") {
        engine.locale = value;
        localStorage.setItem(PREFS.locale, value);
        lastSpokenKey = "";
        render();
      }
    });
  });

  root.querySelectorAll("[data-voice]").forEach((btn) => {
    btn.addEventListener("click", () => {
      speakOnAppear = !speakOnAppear;
      localStorage.setItem(PREFS.speak, String(speakOnAppear));
      if (!speakOnAppear) stopSpeaking();
      lastSpokenKey = "";
      render();
    });
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
