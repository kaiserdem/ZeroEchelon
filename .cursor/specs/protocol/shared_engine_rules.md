# Shared Engine Rules

## Description

Єдина політика рушія для всіх клієнтів (iOS, web, майбутній Android): `protocol/graphs/zero-echelon-core/engine-rules.json`. Клієнти лише інтерпретують rules + edges графа.

## Requirements

- [x] Файл `engine-rules.json` з sceneRecheck, safety queues, casualty remaps
- [x] Swift `EngineRules` + `GraphLoader.loadBundledPackage()`
- [x] `ProtocolEngine` читає rules (не хардкодить черги A1–A6 / A7 / casualty)
- [x] Web `ProtocolEngine` імпортує той самий JSON
- [x] Копія в `ZeroEchelon/Resources/engine-rules.json`
- [x] Manifest посилається на `engineRulesFile`

## Acceptance Criteria

- Зміна черги для `traffic` у `engine-rules.json` змінює поведінку iOS і web після sync ресурсів / rebuild
- Unit-тести `trafficSafetySkipsUXO` лишаються зеленими

## Notes

UI-тексти helper/voice overrides можуть лишатися в клієнті; медичні/навігаційні remaps — лише в `protocol/`.
