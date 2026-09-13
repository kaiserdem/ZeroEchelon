# fixtures/

Короткі прогони для перевірки рушія (коли з’явиться) і ручної звірки графа.

| Файл | Що перевіряє |
| --- | --- |
| `happy-path-s0-s5b.json` | Усі «Ні» на безпеці → Call → NEXT-PHASE |
| `veto-path-s5a.json` | «Так» на A1 → Out → Form |

Очікуваний `graphVersion` має збігатися з `manifest.json`.
