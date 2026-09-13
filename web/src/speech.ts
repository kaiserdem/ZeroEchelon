import type { ContentLocale } from "./types";

export function speak(text: string, locale: ContentLocale): void {
  if (typeof window === "undefined" || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const utter = new SpeechSynthesisUtterance(text);
  utter.lang = locale === "uk" ? "uk-UA" : "en-US";
  utter.rate = 1;
  window.speechSynthesis.speak(utter);
}

export function stopSpeaking(): void {
  if (typeof window === "undefined" || !window.speechSynthesis) return;
  window.speechSynthesis.cancel();
}

type SpeechRecognitionLike = {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  start: () => void;
  stop: () => void;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
};

type SpeechRecognitionEventLike = {
  results: ArrayLike<ArrayLike<{ transcript: string }>>;
};

type SpeechRecognitionCtor = new () => SpeechRecognitionLike;

function recognitionCtor(): SpeechRecognitionCtor | null {
  const w = window as Window & {
    SpeechRecognition?: SpeechRecognitionCtor;
    webkitSpeechRecognition?: SpeechRecognitionCtor;
  };
  return w.SpeechRecognition ?? w.webkitSpeechRecognition ?? null;
}

export function canDictate(): boolean {
  return recognitionCtor() !== null;
}

let activeRecognition: SpeechRecognitionLike | null = null;

export function startDictation(
  locale: ContentLocale,
  onPartial: (text: string) => void,
): boolean {
  stopDictation();
  stopSpeaking();
  const Ctor = recognitionCtor();
  if (!Ctor) return false;

  const recognition = new Ctor();
  recognition.lang = locale === "uk" ? "uk-UA" : "en-US";
  recognition.continuous = false;
  recognition.interimResults = true;
  recognition.onresult = (event) => {
    const result = event.results[event.results.length - 1];
    const transcript = result?.[0]?.transcript?.trim();
    if (transcript) onPartial(transcript);
  };
  recognition.onerror = () => {
    activeRecognition = null;
  };
  recognition.onend = () => {
    activeRecognition = null;
  };
  activeRecognition = recognition;
  recognition.start();
  return true;
}

export function stopDictation(): void {
  if (!activeRecognition) return;
  try {
    activeRecognition.stop();
  } catch {
    // already stopped
  }
  activeRecognition = null;
}

export function isDictating(): boolean {
  return activeRecognition !== null;
}
