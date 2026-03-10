# Algorytm generowania dróg

Priority queue-based algorithm inspirowany pracami Parish & Müller (2001) — "Procedural Modeling of Cities". Przetwarza propozycje dróg w kolejności priorytetowej, waliduje je i generuje nowe propozycje.

## Core loop

```
1. Inicjalizacja:
   - Wstaw seed road do kolejki Q z time = 0
   - S = [] (pusta lista segmentów)

2. WHILE Q ≠ ∅:
   a. Pop road query r(t, ra, qa) z najmniejszym time t
   b. Utwórz GenerationContext z aktualnym stanem
   c. Ewaluacja local constraints:
        (adjusted_qa, state) = constraintEvaluator.evaluate(qa, context)
   d. IF state == SUCCEED:
        i.   Utwórz RoadSegment z ra, dodaj do S
        ii.  Generuj nowe propozycje:
               proposals = goalEvaluator.generateProposals(adjusted_qa, ra, context)
        iii. Dla każdego proposal:
               Wstaw do Q z time = t + proposal.delay

3. RETURN S
```

## RoadGenerator — klasa

```swift
@MainActor
public final class RoadGenerator {
    public init(cityState: CityState, terrainMap: TerrainMap, config: RuleConfiguration)

    public func generateRoadNetwork(
        initialRoad: RoadAttributes,
        initialQuery: QueryAttributes
    ) -> [RoadSegment]

    public func updateCityState(_ newCityState: CityState)
    public func updateTerrainMap(_ newTerrainMap: TerrainMap)
    public func updateConfiguration(_ newConfig: RuleConfiguration)
    public func getSegments() -> [RoadSegment]
    public func getQueueSize() -> Int
    public func reset()
}
```

### Inicjalizacja

Constructor tworzy generatory reguł i od razu generuje zestawy reguł:

```
init(cityState, terrainMap, config)
  │
  ├─► LocalConstraintGenerator.generateRules() → constraintEvaluator
  └─► GlobalGoalGenerator.generateRules() → goalEvaluator
```

### Regeneracja reguł

Wywoływana gdy:
- `updateCityState()` z `needsRuleRegeneration == true`
- `updateTerrainMap()` — zawsze
- `updateConfiguration()` — zawsze

Regeneracja od nowa tworzy zestawy reguł i aktualizuje evaluatory.

## Priority Queue

Używa `Heap<RoadQuery>` z swift-collections (min-heap):

```swift
struct RoadQuery: Comparable {
    let time: Int
    let roadAttributes: RoadAttributes
    let queryAttributes: QueryAttributes

    static func < (lhs: RoadQuery, rhs: RoadQuery) -> Bool {
        lhs.time < rhs.time  // niższy time = wyższy priorytet
    }
}
```

### Mechanizm priorytetów

- `defaultDelay = 1` — kontynuacja drogi w tym samym kierunku
- `branchDelay = 3` — nowa odnoga

Efekt: drogi główne rosną dalej zanim pojawiają się odgałęzienia. To tworzy naturalną hierarchię sieci.

## GenerationContext

Snapshot stanu przekazywany do reguł:

```swift
struct GenerationContext {
    let currentLocation: CGPoint        // pozycja ewaluowanej drogi
    let terrainMap: TerrainMap          // dane terenu
    let cityState: CityState           // stan miasta
    let existingInfrastructure: [RoadSegment]  // dotychczasowe drogi
    let queryAttributes: QueryAttributes       // propozycja do ewaluacji
}
```

`existingInfrastructure` rośnie z każdym dodanym segmentem — reguły Angle i Proximity sprawdzają kolizje z istniejącymi drogami.

## Wydajność

| Rozmiar mapy | Segmenty | Czas |
|-------------|----------|------|
| <50×50 | ~100-500 | <1s |
| <200×200 | ~500-2000 | 1-5s |
| <1000×1000 | ~2000-10000 | 5-30s |

Bottleneck: `ProximityConstraintRule` i `AngleConstraintRule` sprawdzają wszystkie istniejące segmenty (O(n) per ewaluację). Optymalizacja: spatial index (quadtree) — niezaimplementowany, ale architektura na to pozwala.

## Przykład użycia

```swift
import Terrain
import RoadGeneration

let terrainMap = TerrainMapBuilder().buildTerrainMap(header: header, heights: heights)
let cityState = CityState(population: 50_000, density: 1_500, economicLevel: 0.6, age: 15)
var config = RuleConfiguration()

let generator = RoadGenerator(cityState: cityState, terrainMap: terrainMap, config: config)

let initialRoad = RoadAttributes(startPoint: CGPoint(x: 500, y: 500),
                                  angle: 0, length: 100, roadType: "main")
let initialQuery = QueryAttributes(startPoint: CGPoint(x: 500, y: 500),
                                    angle: 0, length: 100, roadType: "main", isMainRoad: true)

let roads = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
```

## Plik źródłowy

`Packages/RoadGeneration/Sources/RoadGeneration/Core/DataStructures.swift`
