# ios/

Канонічний Xcode-додаток тепер тут:

**`ZeroEchelon/ZeroEchelon.xcodeproj`**

Відкрийте цей проєкт у Xcode і запускайте схему `ZeroEchelon`.

Цей каталог `ios/` лишає лише **бібліотеку + тести** рушія (`Package.swift`, `Sources/ZeroEchelonKit`, `Tests/`), щоб ганяти логіку без симулятора:

```bash
cd ios && swift test
```

Сирці протоколу в додатку: `ZeroEchelon/ZeroEchelon/Protocol/`  
Граф у бандлі: `ZeroEchelon/ZeroEchelon/Resources/graph.json` (копія з `protocol/graphs/…`; після правок графа — оновіть копію).
