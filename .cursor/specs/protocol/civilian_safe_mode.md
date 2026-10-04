# Civilian safe mode (hide treatment commands)

## Description

Після зустрічі з поліцією/ДСНС (2026-10): цивільному не даємо команд лікування. Продукт веде: 112 → безпека сцени → локація/тип → звіт. Дерева B–G і J лишаються в `graph.json`, але приховані через `engine-rules.civilianSafeMode`.

## Requirements

- [x] `civilianSafeMode` у `protocol/.../engine-rules.json` (+ Resources)
- [x] Вузол `Safe-civil` після Call → Form
- [x] iOS `ProtocolEngine` remap + hide Home `daily`
- [x] Web `ProtocolEngine` той самий remap
- [x] Unit-тести: safe path за замовчуванням; care trees через `makeCareEngine()`
- [ ] Memo для юриста / партнерів у `docs/stakeholder/` (опційно)

## Acceptance Criteria

- Home показує лише «Щось сталось зараз» і «Чек-лист після події»
- Після Call «Далі» → `Safe-civil` → Form (не Count / не Casualty-menu)
- `civilianSafeMode.enabled = false` повертає старі дерева без зміни графа
- 112 і 101 на вето лишаються

## Notes

Увімкнути лікування знову: `engine-rules.json` → `civilianSafeMode.enabled: false`, sync Resources, rebuild.
