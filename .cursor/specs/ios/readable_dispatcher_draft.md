# Readable dispatcher / medic report draft

## Description

Чернетка на Form / Read / Give — стислий текст для зачитування і QR за духом `docs/08`: тип, місце, роль, N (SALT, якщо є), час джгута, 2–3 ключові факти. Не повний лог усіх кнопок.

## Requirements

- [x] `tourniquetOn` фіксується при переході з `Tq` → `Tq-time` (кнопка «Наклав»)
- [x] Лічильник SALT: відвідування вузлів `Red` / `Yellow` / `Green`|`Green2` (по прибуттю)
- [x] `dispatcherDraft` збирає лише відомі поля: T · E · роль · N (якщо >0) · джгут (якщо є) · короткі факти · «потрібна допомога»; без плейсхолдерів «ще не обрано / не вказано»
- [x] Факти — з відомих вузлів допомоги в `steps` (останні до 3), без Back/Home шуму
- [x] Persist `tourniquetOn` + лічильники у local event
- [x] iOS + web паритет; тести на джгут і наявність N у чернетці

## Acceptance Criteria

1. Після «Наклав» на Tq у чернетці є час джгута.
2. Після проходу Red/Yellow/Green у чернетці є рядок постраждалих з кольорами.
3. Старі тести чернетки оновлені під новий формат (contains type/place, не raw edge id).

## Notes

Повний M/ETHANE PDF і SHA — поза цим slice. K3/K4 draft не чіпаємо.
