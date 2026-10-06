# Civic hub mock (тестовий мирний шар)

## Description

Тестова четверта кнопка на Home — «Лікар, аптека, донор». Окремий SwiftUI-контур з моковими даними. Не частина `protocol/` і не змінює `ProtocolEngine`.

Орієнтир: `docs/stakeholder/мирний-шар.html`. Гілка: `feature/civic-hub-mock`.

## Requirements

- [ ] На Home (лише `currentNode.id == "Home"`) є тихіша кнопка UA «Лікар, аптека, донор» / EN «Doctor, pharmacy, donor»
- [ ] Кнопка відкриває civic-контур через push (NavigationView), не sheet і не вузол графа
- [ ] Hub показує 4 розділи: онлайн-консультація, запис у клініку, аптека, донорство
- [ ] Дані з бандлованого `civic-mock.json` (локально, без мережі)
- [x] Hub і розділи без заголовка, бейджа «Демо» і опису демо (лише «Назад» + контент)
- [ ] «Зателефонувати» відкриває `tel:`; зовнішні приклади — `openURL` на мок-лінк
- [ ] Смуга 112 на civic-екранах або легкий шлях назад на Home з 112
- [ ] `ProtocolEngine` / `graph.json` не містять civic-вузлів
- [ ] XcodeGen: файли під `ZeroEchelon/Civic/` підхоплюються з sources

## Acceptance Criteria

1. Збірка ZeroEchelon на симуляторі проходить.
2. З Home можна відкрити hub і всі 4 розділи з мок-списками.
3. Гострі три кнопки Home і переходи incident/daily/wave без змін.
4. Юніт-тест: мок JSON парситься і містить усі 4 секції.

## Notes

Архітектура: легкий MVVM. `CivicMockStore` + Views. Не TCA.
