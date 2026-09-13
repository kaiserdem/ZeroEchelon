# iOS Protocol Engine (SwiftUI)

## Description

SwiftUI-клієнт читає `protocol/graphs/zero-echelon-core/graph.json` і показує будь-який вузол одним каркасом екрана (текст, кнопки, смуга 103). Медична логіка лише в графі.

## Requirements

- [x] Моделі `Codable` відповідають docs/06 і поточному graph.json
- [x] `ProtocolEngine` тримає поточний вузол, роль сесії, журнал кроків
- [x] Перехід лише через `edges` вузла (без клінічних `if`)
- [x] `alwaysAvailable` CALL-103 / CALL-101 доступні з будь-якого екрана
- [x] Один SwiftUI-каркас рендерить question / action / veto / call / handover / report
- [x] Перемикач UA/EN; голос = `voice` вибраної мови
- [x] Опційний системний TTS (дослівно з екрана)
- [x] `tel:103` / `tel:101` для виклику
- [x] Граф у бандлі додатка (`ZeroEchelon/.../Resources/graph.json`)
- [x] Unit-тести happy-path і veto fixtures (`ios/` Package)

## Acceptance Criteria

- Проєкт відкривається в Xcode і збирається на iOS Simulator
- Прохід Start → NEXT-PHASE пальцем без мережі
- Зміна тексту в JSON змінює екран без правки View

## Notes

XcodeGen: `ios/project.yml`. Бібліотека: `ZeroEchelonKit`. Додаток: `ZeroEchelon`.
