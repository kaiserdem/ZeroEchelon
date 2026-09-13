# web/

Клієнт для **QR без встановлення**: статичний веб (Vite). Той самий граф, що й iOS.

## Дизайн

Зафіксовано **Civic Signal (варіант C)** — ті самі токени, що `CivicTheme` в iOS:
accent `#0d449e`, danger `#d91f29`, warning `#f2b814`, canvas `#f5f7fc`.

## Запуск

```bash
cd web
npm install
npm run dev
```

Відкрий URL з терміналу (зазвичай `http://localhost:5173`).

Збірка для Cloudflare Pages:

```bash
npm run build
```

Артефакти в `web/dist`. Build output directory у Pages: `dist`. Root directory: `web`.

## Стек

- Vite + TypeScript
- `ProtocolEngine` у `src/engine.ts` (порт Swift)
- Граф: `@protocol/graphs/zero-echelon-core/graph.json`
- Web Speech API (опційно)

## Чого ще немає

- Service Worker / повний PWA offline
- Справжній QR → адреса (демо-рядки як в iOS)
