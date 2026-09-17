# Web Clickable Demo (PWA entry)

## Description

Мінімальний веб-клієнт у `web/`: той самий `protocol/graphs/zero-echelon-core/graph.json`, один екран вузла. Посилання для замовника без TestFlight / App Store.

## Design

- [x] Візуальна система **Civic Signal (C)** — спільна з iOS `CivicTheme`
- [x] Бренд **Line 24** у top bar (слот Назад)

## Requirements

- [x] Vite + TypeScript, імпорт канонічного `graph.json` з `protocol/`
- [x] Порт `ProtocolEngine`: вузол, edges, роль, veto UX, журнал, назад
- [x] UI: badge, voice, helper, anti-pattern, detail, кнопки, UA|EN
- [x] Нижня смуга `tel:112` / `tel:101` (без dial у контенті)
- [x] Опційний Web Speech API
- [x] Одна локальна подія в `localStorage` (до 48 год): гідратація при старті
- [x] Home: під кнопками (після «Чек-лист…») — «Остання подія» + «Відкрити звіт» → Form
- [x] Erase чистить слот; перший Form планує демо-нагадування 24/48 (`Notification` + setTimeout)
- [x] `npm run dev` відкриває демо локально; `npm run build` для статики

## Acceptance Criteria

- Замовник відкриває URL і може пройти Disclaimer → локація → тип → роль → Call і далі по графу
- Після закриття вкладки й повторного відкриття на Home видно останню подію (якщо не Erase / не >48 год)
- Медична логіка лише з edges графа (окремого веб-алгоритму немає)
- Internal demo banner: «веб-демо, не App Store»

## Notes

Web-нагадування — best-effort демо (вкладка має жити для setTimeout); канон надійних локальних пушів — iOS. Повний Service Worker / precache — пізніше. Канон iOS лишається в `ZeroEchelon/`.
