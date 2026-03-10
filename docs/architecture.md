# Architektura systemu CityWeaver

Proceduralny generator sieci dróg miejskich. Aplikacja macOS w SwiftUI z modularnym backendem w Swift Packages.

## Diagram modułów

```
┌─────────────────────────────────────────────────────┐
│                    App (SwiftUI)                     │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│  │TerrainEditor │ │RoadGeneration│ │Visualization │ │
│  │   (Canvas,   │ │  (Generator  │ │   (3D View,  │ │
│  │  Districts)  │ │    View)     │ │ SceneKit)    │ │
│  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ │
│         │                │                │          │
│  ┌──────┴────────────────┴────────────────┴───────┐  │
│  │              Configuration Views                │  │
│  └─────────────────────┬──────────────────────────┘  │
└────────────────────────┼─────────────────────────────┘
                         │ depends on
    ┌────────────────────┼────────────────────┐
    │                    │                    │
┌───▼───┐         ┌─────▼─────┐        ┌─────▼────┐
│ Core  │         │RoadGenera-│        │ Terrain  │
│       │         │  tion     │        │          │
└───────┘         └─────┬─────┘        └──────────┘
                        │ depends on        ▲
┌───────┐               │                  │
│Shared │         ┌─────▼─────┐            │
│       │         │   RGA     ├────────────┘
└───────┘         └───────────┘

External: swift-collections (Heap<T>)
```

## Pakiety

| Pakiet | Ścieżka | Rola | Zależności |
|--------|---------|------|-----------|
| **Terrain** | `Packages/Terrain/` | Ładowanie terenu (ASC), obliczanie nachylenia, zarządzanie dzielnicami, serializacja | — |
| **RoadGeneration** | `Packages/RoadGeneration/` | Generowanie dróg (priority queue + system reguł), eksport (JSON, OBJ, glTF) | Terrain, swift-collections |
| **RGA** | `Packages/RGA/` | Alternatywna implementacja algorytmu generowania dróg | Terrain, swift-collections |
| **Core** | `Packages/Core/` | Fundament — typy podstawowe | — |
| **Shared** | `Packages/Shared/` | Współdzielone utilities | — |

## Warstwa UI (App/)

Czysta warstwa SwiftUI bez logiki biznesowej. Organizacja by feature:

| Feature | Pliki | Opis |
|---------|-------|------|
| **TerrainEditor** | 8 plików | Edycja terenu — canvas 2D, malowanie dzielnic, undo/redo |
| **RoadGeneration** | 1 plik | Panel sterowania generowaniem dróg |
| **Visualization** | 2 pliki | Wizualizacja 3D sieci dróg (SceneKit) |
| **Configuration** | 2 pliki | Konfiguracja parametrów miasta i reguł |

Entry point: `CWApp.swift` → `ContentView.swift` (TabView)

## Algorytm generowania dróg

System rule-based z priority queue (Heap<T>):

```
CityState + TerrainMap
        │
        ▼
  RoadGenerator
        │
        ├──► Priority Queue (RoadQuery)
        │         │
        │         ▼
        ├──► Local Constraints (filtrowanie)
        │    ├── BoundaryConstraintRule
        │    ├── TerrainConstraintRule
        │    ├── AngleConstraintRule
        │    ├── ProximityConstraintRule
        │    └── DistrictBoundaryRule
        │
        ├──► Global Goals (generowanie nowych propozycji)
        │    ├── DistrictPatternRule
        │    ├── CoastalGrowthRule
        │    └── ConnectivityRule
        │
        ▼
  RoadSegment[] ──► Export (JSON / OBJ / glTF)
```

## Dane wejściowe

- **Terrain**: pliki ASC (ESRI ASCII Grid) z danymi wysokościowymi
- **Districts**: malowane ręcznie w TerrainEditor, serializowane do JSON
- **Konfiguracja**: parametry miasta (CityState) i reguły generowania (RuleConfiguration)

## Stack technologiczny

- **Język**: Swift 6.0+, modern concurrency (`@MainActor`, `async`/`await`)
- **UI**: SwiftUI (macOS 15.0+)
- **3D**: SceneKit
- **Build**: xcodegen (`project.yml`) → `.xcodeproj`
- **LSP**: xcode-build-server (`buildServer.json`)
- **Formatowanie**: swiftformat
- **Testy**: XCTest per pakiet (`make test-terrain`, `make test-rga`)

## Decyzje architektoniczne

- **Modularyzacja w Swift Packages**: izolacja domen, testowalność bez UI, czyste zależności
- **xcodegen**: `.xcodeproj` generowany z YAML — unika konfliktów merge w pbxproj
- **Dwa algorytmy (RoadGeneration vs RGA)**: RGA to iteracja/eksperyment algorytmu; oba współistnieją podczas badań
- **@MainActor na TerrainMap i RoadGenerator**: uproszczenie concurrency — dane terenu i generator modyfikowane tylko z main thread
- **OptimizedTerrainMapBuilder**: async actor z 4x downsampling dla dużych map — kompromis między dokładnością a wydajnością

---

*Źródło szczegółowej dokumentacji per moduł: `docs/terrain/`, `docs/road-generation/`, `docs/rga/`, `docs/app/`*
*Archiwalna dokumentacja: `docs/legacy/`*
