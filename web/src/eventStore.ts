import type { ContentLocale, ProtocolLogStep, SessionRole } from "./types";

const STORAGE_KEY = "line24.local-event.v1";
export const MAX_RETENTION_MS = 48 * 60 * 60 * 1000;
export const WAVE_24_MS = 24 * 60 * 60 * 1000;
export const WAVE_48_MS = 48 * 60 * 60 * 1000;

export interface LocalEventRecord {
  eventId: string;
  startedAt: string;
  reachedFormAt: string | null;
  sessionRole: SessionRole | null;
  incidentType: string | null;
  locationLine: string | null;
  locationLevel: number | null;
  steps: ProtocolLogStep[];
  waveRemindersScheduled: boolean;
}

export function isExpired(record: LocalEventRecord, now = Date.now()): boolean {
  return now - Date.parse(record.startedAt) > MAX_RETENTION_MS;
}

export function loadLocalEvent(now = Date.now()): LocalEventRecord | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const record = JSON.parse(raw) as LocalEventRecord;
    if (!record?.eventId || !record?.startedAt) {
      clearLocalEvent();
      return null;
    }
    if (isExpired(record, now)) {
      clearLocalEvent();
      return null;
    }
    return record;
  } catch {
    clearLocalEvent();
    return null;
  }
}

export function saveLocalEvent(record: LocalEventRecord): void {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(record));
}

export function clearLocalEvent(): void {
  localStorage.removeItem(STORAGE_KEY);
}

export function formatEventStartedAt(
  iso: string,
  locale: ContentLocale,
): string {
  const date = new Date(iso);
  return new Intl.DateTimeFormat(locale === "uk" ? "uk-UA" : "en-GB", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

/** Best-effort browser notifications (demo). Not equivalent to iOS UNUserNotificationCenter. */
export async function scheduleWaveNotifications(
  startedAtIso: string,
  locale: ContentLocale,
  now = Date.now(),
): Promise<boolean> {
  if (!("Notification" in window)) return false;
  let permission = Notification.permission;
  if (permission === "default") {
    permission = await Notification.requestPermission();
  }
  if (permission !== "granted") return false;

  const started = Date.parse(startedAtIso);
  const fires: { at: number; body: string }[] = [];
  const at24 = started + WAVE_24_MS;
  const at48 = started + WAVE_48_MS;
  if (at24 > now) {
    fires.push({
      at: at24,
      body:
        locale === "uk"
          ? "Минуло 24 години після події. Короткий чек-лист."
          : "24 hours since the event. Short checklist.",
    });
  }
  if (at48 > now) {
    fires.push({
      at: at48,
      body:
        locale === "uk"
          ? "Минуло 48 годин після події. Повторіть чек-лист."
          : "48 hours since the event. Repeat the checklist.",
    });
  }

  for (const fire of fires) {
    const delay = Math.max(1000, fire.at - now);
    window.setTimeout(() => {
      try {
        const n = new Notification("Line 24", { body: fire.body });
        n.onclick = () => {
          window.focus();
          window.dispatchEvent(new CustomEvent("line24-open-wave"));
          n.close();
        };
      } catch {
        /* ignore */
      }
    }, delay);
  }
  return true;
}
