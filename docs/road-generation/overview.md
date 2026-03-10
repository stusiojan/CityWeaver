# Pakiet RoadGeneration

Algorytm proceduralnego generowania sieci dróg miejskich oparty na priority queue i elastycznym systemie reguł. Generuje drogi respektujące teren, granice dzielnic i wzorce urbanistyczne.

## Co robi

Przyjmuje `TerrainMap` (z pakietu Terrain) i konfigurację, generuje sieć dróg jako listę `RoadSegment[]`, opcjonalnie eksportuje do JSON/OBJ/glTF.

## Struktura modułu

```
Packages/RoadGeneration/Sources/RoadGeneration/
├── Core/
│   ├── Models/
│   │   ├── RoadAttributes.swift          — geometria segmentu drogi
│   │   ├── QueryAttributes.swift         — dane propozycji drogi
│   │   ├── RoadSegment.swift             — zatwierdzony segment drogi
│   │   ├── RoadQuery.swift               — propozycja w priority queue
│   │   ├── CityState.swift               — stan symulacji miasta
│   │   ├── RuleConfiguration.swift       — parametry algorytmu
│   │   ├── GenerationContext.swift        — kontekst ewaluacji reguł
│   │   ├── GenerationReport.swift        — raport diagnostyczny
│   │   └── ConstraintTypes.swift         — ConstraintState, RuleScope, ConstraintResult, RoadProposal
│   ├── Rules/
│   │   ├── RuleProtocols.swift           — LocalConstraintRule, GlobalGoalRule
│   │   ├── LocalConstraints/
│   │   │   ├── BoundaryConstraintRule.swift
│   │   │   ├── TerrainConstraintRule.swift
│   │   │   ├── AngleConstraintRule.swift
│   │   │   ├── ProximityConstraintRule.swift
│   │   │   └── DistrictBoundaryRule.swift
│   │   └── GlobalGoals/
│   │       ├── DistrictPatternRule.swift
│   │       ├── CoastalGrowthRule.swift
│   │       └── ConnectivityRule.swift
│   ├── Evaluation/
│   │   ├── LocalConstraintGenerator.swift
│   │   ├── GlobalGoalGenerator.swift
│   │   ├── LocalConstraintEvaluator.swift
│   │   └── GlobalGoalEvaluator.swift
│   ├── RoadGenerator.swift               — główna klasa algorytmu
│   └── ExampleUsage.swift                — demo do szybkiego testu
├── Export/
│   ├── RoadNetworkSerializer.swift — JSON export/import z metadanymi
│   ├── OBJExporter.swift           — Wavefront OBJ (Blender)
│   └── GLTFExporter.swift          — glTF 2.0 z materiałami PBR
└── Visualization/
    └── (zarezerwowane)
```

## Dataflow

```
TerrainMap + CityState + RuleConfiguration
                │
                ▼
         RoadGenerator.init()
                │
                ├─► LocalConstraintGenerator → [LocalConstraintRule]
                └─► GlobalGoalGenerator → [GlobalGoalRule]
                │
                ▼
    generateRoadNetwork(initialRoad, initialQuery)
                │
                ├─► Priority Queue (Heap<RoadQuery>)
                │         │
                │         ▼ pop min time
                ├─► LocalConstraintEvaluator.evaluate()
                │    │
                │    ├── succeed → dodaj RoadSegment
                │    │              │
                │    │              ▼
                │    │    GlobalGoalEvaluator.generateProposals()
                │    │              │
                │    │              ▼
                │    │    nowe RoadQuery → z powrotem do kolejki
                │    │
                │    └── failed → odrzuć propozycję
                │
                ▼
         RoadSegment[] (wynik)
                │
                ▼
         Export: JSON / OBJ / glTF
```

## Kluczowe typy

### RoadSegment — wynik generowania

```swift
public struct RoadSegment: Codable, Sendable {
    public let id: UUID
    public let attributes: RoadAttributes
    public let createdAt: Int
}

public struct RoadAttributes: Codable, Sendable {
    public let startPoint: CGPoint
    public let angle: Double      // radiany
    public let length: Double
    public let roadType: String   // "main", "highway", "residential", "street"
}
```

### CityState — stan symulacji miasta

```swift
public struct CityState {
    public var population: Int
    public var density: Double        // na km²
    public var economicLevel: Double  // 0-1
    public var age: Int               // lata symulacji
    public var needsRuleRegeneration: Bool
}
```

Wiek miasta wpływa na aktywowane reguły:
- `age == 0`: brak AngleConstraintRule
- `age > 5`: aktywacja ConnectivityRule
- Większy wiek = więcej reguł = bardziej złożona sieć

### RuleConfiguration — jedyne źródło parametrów

Centralna konfiguracja z ~15 parametrami pogrupowanymi w kategorie:

| Kategoria | Parametry | Domyślne |
|-----------|-----------|----------|
| Granice | `cityBounds` | 1000×1000 od (0,0) |
| Kąty | `mainRoadAngle{Min,Max}`, `internalRoadAngle{Min,Max}` | 60-170° / 30-180° |
| Odległości | `minimumRoadDistance`, `intersectionMinSpacing` | 10m / 30m |
| Teren | `maxBuildableSlope`, `minUrbanizationFactor` | 0.3 / 0.2 |
| Cele | `branchingProbability`, `roadLengthMultiplier`, `branchingAngles` | per dzielnica |
| Czas | `defaultDelay`, `branchDelay` | 1 / 3 |

## Zależności

```
RoadGeneration
├── swift-collections (>= 1.0.0) — Heap<T> dla priority queue
└── Terrain (local) — TerrainMap, TerrainNode, DistrictType
```

## Złożoność

- **Czas**: O(n log n) — operacje na Heap
- **Pamięć**: O(n) — segmenty + kolejka

## Decyzje projektowe

- **Rozbicie na mniejsze pliki**: Models/, Rules/, Evaluation/ + RoadGenerator.swift — tematyczny podział na ~20 plików zamiast jednego monolitu. SPM autodiscovery eliminuje potrzebę ręcznego zarządzania listą plików
- **Protokoły reguł z priority**: umożliwia dodawanie nowych reguł bez modyfikacji core algorytmu
- **Heap zamiast sortowanej tablicy**: O(log n) insert/extract vs O(n) dla tablicy
- **@MainActor na RoadGenerator**: spójne z TerrainMap, upraszcza integrację z UI

## Powiązane dokumenty

- [System reguł](rule-system.md) — protokoły, implementacje, evaluatory
- [Algorytm generowania](algorithm.md) — core loop, priority queue, flow
- [Eksport](export.md) — JSON, OBJ, glTF
