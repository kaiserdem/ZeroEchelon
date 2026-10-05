# Civilian witness — informational / communications loop

## Description

Цивільний свідок не втручається фізично: фіксує доступну без наближення інформацію, викликає професійні служби, передає їм структурований звіт. Дерева B–G/J лишаються в `graph.json`, але приховані через `engine-rules.civilianSafeMode`.

## Requirements

- [x] `civilianSafeMode` у `protocol/.../engine-rules.json` (+ Resources)
- [x] Вузол `Safe-civil` після Call → Form
- [x] iOS `ProtocolEngine` remap + hide Home `daily`
- [x] Web `ProtocolEngine` той самий remap
- [x] Unit-тести: safe path за замовчуванням; care trees через `makeCareEngine()`
- [x] Немає фізичних наказів: відійти 100–300 м, увімкнути аварійку, вимкнути джерело, йти до лікарні
- [x] Role лише як цивільний свідок (спостерігаю / подія стосується мене)
- [x] A\* — питання «звідси, не наближаючись»; `yes` у safe mode продовжує фіксацію, не CanLeave
- [x] `Observe-count` / `Observe-signs` перед A6 у цивільному шляху
- [x] Чернетка без SALT-кольорів, турнікета і «Зроблено» у safe mode
- [x] Дисклеймер без юридичних гарантій і без «підказує кроки»
- [x] Текст УКРНОІВІ: `docs/stakeholder/укрноіві-функціональність.md`

## Acceptance Criteria

- Home показує лише «Щось сталось зараз» і «Чек-лист після події»
- Після Call «Далі» → `Safe-civil` → Form (не Count / не Casualty-menu)
- У цивільному шляху A1 `yes` → наступне питання A, не Out
- Після A\* — кількість і ознаки, видимі звідси, у чернетці диспетчеру
- `civilianSafeMode.enabled = false` повертає старі дерева без зміни графа
- 112 і 101 на екранах небезпечної зони лишаються
- Жодне активне формулювання не наказує наближатися, входити, торкатися, переміщувати, евакуювати, гасити, лікувати

## Notes

Увімкнути лікування знову: `engine-rules.json` → `civilianSafeMode.enabled: false`, sync Resources, rebuild.
