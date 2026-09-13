# ZeroEchelon

Канонічний **iOS-додаток** Zero Echelon.

## Відкрити

```bash
open ZeroEchelon.xcodeproj
```

Або з кореня репозиторію: `ZeroEchelon/ZeroEchelon.xcodeproj`.

## Тести рушія

У Xcode: `⌘U`, або:

```bash
cd ZeroEchelon
xcodebuild test -scheme ZeroEchelon -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Перегенерація проєкту (за потреби)

Якщо змінювали `project.yml`:

```bash
cd ZeroEchelon && xcodegen generate
```

## Структура

| Шлях | Зміст |
| --- | --- |
| `ZeroEchelon/` | SwiftUI + `Protocol/` рушій + `Resources/graph.json` |
| `ZeroEchelonTests/` | Unit-тести графа / engine |
| `project.yml` | XcodeGen |

Джерело протоколу в репо: `../protocol/`. Після правок графа оновіть копію в `ZeroEchelon/Resources/graph.json`.
