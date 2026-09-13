import graphJson from "@protocol/graphs/zero-echelon-core/graph.json";
import { ProtocolEngine } from "./engine";
import { speak, stopSpeaking } from "./speech";
import type { ContentLocale, ProtocolGraph } from "./types";
import { buttonTitle } from "./types";
import "./styles.css";

const graph = graphJson as ProtocolGraph;
const appRoot = document.querySelector<HTMLDivElement>("#app");
if (!appRoot) throw new Error("#app missing");
const root: HTMLDivElement = appRoot;

const engine = new ProtocolEngine(graph, "uk");
engine.skipEntrySplashIfNeeded();

let speakOnAppear = true;

function dial(number: string): void {
  window.location.href = `tel:${number}`;
}

function render(): void {
  const isVeto = engine.currentNode.veto;
  const locale = engine.locale;
  const buttons = engine.visibleButtons;
  const isType = engine.currentNode.id === "Type";
  const prioritize101 = engine.prioritize101;
  const show101 = engine.showsRescue101;
  const emphasizeCall = engine.currentNode.id === "Call";

  const actionsClass = isType ? "actions grid" : "actions";
  const actionHtml = buttons
    .map((button, index) => {
      const primary = index === 0 || isVeto || isType;
      let cls = "action-btn secondary";
      if (isVeto) cls = "action-btn veto";
      else if (primary) cls = "action-btn primary";
      return `<button type="button" class="${cls}" data-when="${escapeAttr(button.when)}">${escapeHtml(buttonTitle(button, locale))}</button>`;
    })
    .join("");

  let emergencyHtml: string;
  if (prioritize101 && show101) {
    emergencyHtml = `
      <p class="emergency-hint">${escapeHtml(hint(locale, true))}</p>
      <button type="button" class="dial-101 primary" data-dial="101">${escapeHtml(locale === "uk" ? "ВИКЛИКАТИ 101 (ДСНС)" : "CALL 101 (rescue)")}</button>
      <button type="button" class="dial-103 outline" data-dial="103">${escapeHtml(locale === "uk" ? "Викликати 103" : "Call 103")}</button>
    `;
  } else {
    emergencyHtml = `
      <p class="emergency-hint">${escapeHtml(hint(locale, false))}</p>
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

  root.innerHTML = `
    <div class="frame${isVeto ? " is-veto" : ""}">
      <p class="demo-banner">${locale === "uk" ? "Веб-демо · не App Store" : "Web demo · not App Store"}</p>
      <header class="top-bar">
        ${
          engine.canGoBack
            ? `<button type="button" class="back-btn" data-back>‹ ${locale === "uk" ? "Назад" : "Back"}</button>`
            : ""
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
        <div class="${actionsClass}">${actionHtml}</div>
      </main>
      <footer class="emergency">${emergencyHtml}</footer>
    </div>
  `;

  bind();
  if (speakOnAppear) speak(engine.voiceText, locale);
}

function hint(locale: ContentLocale, prioritize101: boolean): string {
  if (locale === "uk") {
    return prioritize101
      ? "Спочатку 101. 103 — якщо є поранені на безпечній відстані"
      : "Екстрений виклик — завжди на екрані";
  }
  return prioritize101
    ? "101 first. 103 — if casualties are at a safe distance"
    : "Emergency call — always on screen";
}

function bind(): void {
  root.querySelector("[data-back]")?.addEventListener("click", () => {
    engine.goBack();
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

  root.querySelectorAll<HTMLButtonElement>("[data-when]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const when = btn.dataset.when;
      if (!when) return;
      try {
        const result = engine.select(when);
        if (result.externalURL) {
          window.location.href = result.externalURL;
        }
        render();
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

try {
  render();
} catch (error) {
  root.innerHTML = `<p class="error">${escapeHtml(String(error))}</p>`;
}
