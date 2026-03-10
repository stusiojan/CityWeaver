# Warstwa UI (App/)

Czysta warstwa SwiftUI — prezentacja i interakcja użytkownika. Logika biznesowa delegowana do pakietów (Terrain, RoadGeneration).

## Nawigacja

```
CWApp (@main)
└── ContentView (TabView — 3 zakładki)
    ├── Tab 1: TerrainEditorView — edycja terenu i dzielnic
    ├── Tab 2: RoadGeneratorView — generowanie i wizualizacja dróg
    └── Tab 3: SimpleDemoView — szybkie demo algorytmu
```

## Struktura plików

```
App/
├── CWApp.swift                  — entry point (@main)
├── ContentView.swift            — TabView z 3 zakładkami
├── TerrainEditor/               — edycja terenu
│   ├── TerrainEditorView.swift      — główny widok editora
│   ├── TerrainCanvasView.swift      — canvas 2D z interakcją
│   ├── OptimizedTerrainCanvasView.swift — canvas z cache obrazu
│   ├── DistrictPainter.swift        — logika malowania dzielnic
│   ├── DistrictPaletteView.swift    — paleta narzędzi i kolorów
│   ├── PaintTool.swift              — enum: brush/fill/eraser
│   ├── TerrainUndoManager.swift     — undo/redo (50 kroków)
│   └── TerrainOptimization.swift    — LOD i chunk manager
├── RoadGeneration/
│   └── RoadGeneratorView.swift      — panel sterowania + wizualizacja
├── Visualization/
│   ├── RoadNetwork3DView.swift      — SceneKit 3D view
│   └── SceneBuilder.swift           — budowanie sceny 3D
└── Configuration/
    ├── CityStateConfigView.swift    — konfiguracja miasta
    └── RuleConfigView.swift         — konfiguracja reguł
```

## Zarządzanie stanem

Aplikacja nie używa ViewModeli — stan zarządzany przez `@State` w widokach:

| Widok | Kluczowy stan |
|-------|--------------|
| `TerrainEditorView` | `terrainMap`, `activeTool`, `brushSize`, `undoManager` |
| `RoadGeneratorView` | `terrainMap`, parametry CityState, `ruleConfig`, `generatedRoads` |
| `SimpleDemoView` | `roads`, `terrainMap`, `visualizationType` |

## Workflow użytkownika

### 1. Przygotowanie terenu (TerrainEditorView)

```
Załaduj ASC → [automatyczny downsampling dla dużych plików]
    │
    ▼
Maluj dzielnice (brush/fill/eraser)
    │
    ├── Undo/Redo: ⌘Z / ⇧⌘Z
    ├── Skróty: B=Brush, F=Fill, E=Eraser
    │
    ▼
Walidacja dzielnic
    │
    ▼
Eksport do JSON
```

### 2. Generowanie dróg (RoadGeneratorView)

```
Załaduj teren (ASC lub JSON)
    │
    ▼
Konfiguracja:
├── CityState: populacja, gęstość, ekonomia, wiek
├── Reguły: nachylenie, odległości, cele per dzielnica
└── Droga startowa: pozycja, kąt, długość
    │
    ▼
Generate Roads → [progress] → RoadSegment[]
    │
    ▼
Wizualizacja 2D (canvas) + statystyki
    │
    ▼
Eksport: JSON / OBJ / glTF
```

### 3. Wizualizacja 3D (dostępna z RoadGeneratorView)

```
RoadNetwork3DView (SceneKit)
├── Obrót: przeciąganie myszą
├── Zoom: scroll / pinch
├── Pan: Option + przeciąganie
├── Toggles: teren, drogi, siatka
└── Slidery: skala pionowa, detail terenu
```

## Decyzje projektowe

- **Brak ViewModeli**: stan prosty, nie wymaga dodatkowej warstwy. Trade-off: mniej testowalne, ale szybsze prototypowanie
- **HSplitView layout**: panel sterowania po lewej, wizualizacja po prawej — naturalny workflow
- **Dwa canvasy terenu**: standardowy (TerrainCanvasView) z pełną interaktywnością i zoptymalizowany (OptimizedTerrainCanvasView) z cache'owanym obrazem — automatyczny wybór na podstawie rozmiaru mapy
- **SceneKit zamiast RealityKit**: macOS 15 support, prostsze API do bazowej wizualizacji 3D

## Powiązane dokumenty

- [Terrain Editor](terrain-editor.md) — narzędzia malowania, canvas, undo
- [Wizualizacja 3D](visualization.md) — SceneKit, SceneBuilder, eksport
