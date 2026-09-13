# Web Clickable Demo (PWA entry)

## Description

Мінімальний веб-клієнт у `web/`: той самий `protocol/graphs/zero-echelon-core/graph.json`, один екран вузла. Посилання для замовника без TestFlight / App Store.

## Design

- [x] Візуальна система **Civic Signal (C)** — спільна з iOS `CivicTheme`

## Requirements

- [x] Vite + TypeScript, імпорт канонічного `graph.json` з `protocol/`
- [x] Порт `ProtocolEngine`: вузол, edges, роль, veto UX, журнал, назад
- [x] UI: badge, voice, helper, anti-pattern, detail, кнопки, UA|EN
- [x] Нижня смуга `tel:103` / `tel:101` (без dial у контенті)
- [x] Опційний Web Speech API
- [x] `npm run dev` відкриває демо локально; `npm run build` для статики

## Acceptance Criteria

- Замовник відкриває URL і може пройти Disclaimer → локація → тип → роль → Call і далі по графу
- Медична логіка лише з edges графа (окремого веб-алгоритму немає)
- Internal demo banner: «веб-демо, не App Store»

## Notes

Повний Service Worker / precache — пізніше. Канон iOS лишається в `ZeroEchelon/`.
