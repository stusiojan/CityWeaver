# System reguł

Dwuwarstwowy system reguł: **Local Constraints** (walidacja) i **Global Goals** (generowanie). Reguły są dynamicznie tworzone na podstawie stanu miasta.

## Protokoły

### LocalConstraintRule

Waliduje propozycje dróg — może zaakceptować, odrzucić lub zmodyfikować.

```swift
@MainActor
protocol LocalConstraintRule {
    var priority: Int { get }             // niższy = wyższy priorytet
    var applicabilityScope: RuleScope { get }
    var config: RuleConfiguration { get set }

    func applies(to context: GenerationContext) -> Bool
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
}
```

`ConstraintResult` zawiera `state` (succeed/failed), `adjustedQuery` i opcjonalny `reason`.

### GlobalGoalRule

Generuje nowe propozycje dróg na podstawie celów planistycznych.

```swift
@MainActor
protocol GlobalGoalRule {
    var priority: Int { get }
    var applicabilityScope: RuleScope { get }
    var config: RuleConfiguration { get set }

    func applies(to context: GenerationContext) -> Bool
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes,
                          context: GenerationContext) -> [RoadProposal]
}
```

### RuleScope

```swift
enum RuleScope {
    case citywide               // stosowana wszędzie
    case district(DistrictType)  // tylko w danej dzielnicy
    case segmentSpecific         // zależy od segmentu
}
```

## Zaimplementowane reguły — Local Constraints

| Reguła | Priority | Scope | Co robi |
|--------|----------|-------|---------|
| **BoundaryConstraintRule** | 10 | citywide | Sprawdza czy droga mieści się w `cityBounds` (start i koniec) |
| **TerrainConstraintRule** | 15 | citywide | Sprawdza nachylenie < `maxBuildableSlope` i urbanizację > `minUrbanizationFactor` |
| **AngleConstraintRule** | 20 | segmentSpecific | Wymusza kąty skrzyżowań — inne progi dla dróg głównych (60-170°) i wewnętrznych (30-180°) |
| **ProximityConstraintRule** | 25 | citywide | Zapobiega zbyt bliskim drogom — sprawdza odległość endpoints > `minimumRoadDistance` |
| **DistrictBoundaryRule** | 30 | segmentSpecific | Blokuje drogi wewnętrzne na granicach dzielnic; drogi główne mogą przechodzić |

### Kolejność ewaluacji

Reguły przetwarzane w kolejności priority (10 → 15 → 20 → 25 → 30). **Pierwsza porażka kończy ewaluację** — short-circuit.

Logika: najpierw tanie sprawdzenia (granice), potem droższe (kąty z istniejącą infrastrukturą).

## Zaimplementowane reguły — Global Goals

| Reguła | Priority | Scope | Co robi |
|--------|----------|-------|---------|
| **CoastalGrowthRule** | 5 | citywide | Kontynuuje drogę w tym samym kierunku przy wybrzeżu, skraca do 90% |
| **ConnectivityRule** | 8 | citywide | Kontynuuje drogi główne prosto z rzadszym rozgałęzianiem |
| **DistrictPatternRule** | 10 | segmentSpecific | Generuje propozycje według wzorca dzielnicy — kąty, prawdopodobieństwo, długość |

### DistrictPatternRule — szczegóły

Najważniejsza reguła — generuje drogi dopasowane do typu dzielnicy:

1. Pobiera parametry z `RuleConfiguration` per typ dzielnicy
2. Dla każdego kąta rozgałęzienia (np. [0°, 90°, -90°] dla business):
   - Losuje z prawdopodobieństwa rozgałęzienia
   - Oblicza nowy punkt startowy (koniec bieżącej drogi)
   - Tworzy `RoadProposal` z dopasowaną długością (× mnożnik)
3. Drogi kontynuujące (kąt 0) dostają `defaultDelay`, rozgałęzienia `branchDelay`

## Generatory reguł

Dynamicznie tworzą zestawy reguł na podstawie stanu miasta:

### LocalConstraintGenerator

```swift
func generateRules(from cityState: CityState, terrainMap: TerrainMap,
                   config: RuleConfiguration) -> [LocalConstraintRule]
```

Zawsze: Boundary, Terrain, Proximity, DistrictBoundary
Warunkowo: Angle (jeśli `cityState.age > 0`)

### GlobalGoalGenerator

```swift
func generateRules(from cityState: CityState, terrainMap: TerrainMap,
                   config: RuleConfiguration) -> [GlobalGoalRule]
```

Zawsze: DistrictPattern, CoastalGrowth
Warunkowo: Connectivity (jeśli `cityState.age > 5`)

## Evaluatory

### LocalConstraintEvaluator

Iteruje reguły w kolejności priority. Dla każdej:
1. Sprawdza `applies(to:)` — czy reguła dotyczy tego kontekstu
2. Jeśli tak: `evaluate()` — jeśli failed, natychmiast zwraca porażkę
3. Jeśli succeed: potencjalnie modyfikuje query i kontynuuje

### GlobalGoalEvaluator

Zbiera propozycje ze wszystkich applicable reguł. Wiele reguł może generować propozycje jednocześnie.

## Rozszerzalność

Dodanie nowej reguły:
1. Struct conforming to `LocalConstraintRule` lub `GlobalGoalRule`
2. Implementacja `applies(to:)` i `evaluate()` / `generateProposals()`
3. Dodanie parametrów do `RuleConfiguration`
4. Update generatora w `LocalConstraintGenerator` / `GlobalGoalGenerator`

## Plik źródłowy

`Packages/RoadGeneration/Sources/RoadGeneration/Core/DataStructures.swift`
