# Pakiet RGA

Alternatywna implementacja algorytmu generowania dróg. Współistnieje z pakietem RoadGeneration jako eksperymentalna wersja — oba mają tę samą architekturę (priority queue + system reguł), ale różnią się szczegółami implementacji.

## Relacja z RoadGeneration

RGA i RoadGeneration mają **identyczną architekturę** — te same protokoły, ten sam core loop, analogiczne reguły. Różnice:

| Aspekt | RoadGeneration | RGA |
|--------|---------------|-----|
| Plik główny | `DataStructures.swift` (~1072 linii) | `RGA.swift` (~1034 linii) |
| Eksport | JSON, OBJ, glTF | Brak (tylko algorytm) |
| UI integracja | Pełna (RoadGeneratorView) | Minimalna |
| Status | Produkcyjny | Eksperymentalny |

## Struktura

```
Packages/RGA/Sources/RGA/
└── RGA.swift     — cały algorytm w jednym pliku
```

Zawiera duplikaty typów z RoadGeneration:
- `RoadAttributes`, `QueryAttributes`, `RoadSegment`, `RoadQuery`
- `CityState`, `GenerationContext`, `RuleConfiguration`
- Protokoły `LocalConstraintRule`, `GlobalGoalRule`
- Implementacje reguł (Boundary, Angle, Terrain, Proximity, District)
- `RoadGenerator` z priority queue

## Zależności

```
RGA
├── swift-collections (>= 1.0.0) — Heap<T>
└── Terrain (local) — TerrainMap, DistrictType
```

## Decyzje projektowe

- **Duplikacja kodu**: świadoma decyzja na etapie badań — iteracja algorytmu bez ryzyka psucia wersji produkcyjnej. RGA to "piaskownica" do eksperymentów
- **Brak eksportu**: RGA skupia się na samym algorytmie, eksport przez RoadGeneration
- **Osobny pakiet zamiast brancha**: umożliwia porównywanie wyników obu implementacji w tym samym buildzie

## Status

Testy mogą być niestabilne (`make test-rga`). Pakiet wymaga przeglądu i ewentualnego merge z RoadGeneration lub usunięcia po zakończeniu badań.

## Plik źródłowy

`Packages/RGA/Sources/RGA/RGA.swift`
