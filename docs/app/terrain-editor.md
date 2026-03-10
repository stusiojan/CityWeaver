# Terrain Editor

Interaktywny edytor terenu do ładowania danych wysokościowych i malowania dzielnic miejskich.

## Ładowanie danych

### Pliki ASC

`TerrainEditorView` obsługuje ładowanie plików `.asc` przez `.fileImporter`:

1. Parser (`ASCParser`) ładuje nagłówek i siatkę wysokości
2. Automatyczna strategia budowania:
   - <1M węzłów → `TerrainMapBuilder` (synchroniczny)
   - ≥1M węzłów → `OptimizedTerrainMapBuilder` (async z downsampling)
3. Progress indicator podczas ładowania dużych plików

### Pliki JSON

Wcześniej wyeksportowane mapy z dzielnicami — ładowane przez `TerrainMapSerializer.import()`.

## Narzędzia malowania

Enum `PaintTool` z trzema narzędziami:

### Brush (klawisz B)

Maluje okrągły obszar o regulowanym rozmiarze (1-20 komórek).

```swift
// DistrictPainter
func paintBrush(at gridX: Int, y gridY: Int, brushSize: Int,
                district: DistrictType?, on map: TerrainMap)
```

Iteruje po kwadracie `brushSize × brushSize` wokół kursora, maluje komórki w promieniu okręgu.

### Fill (klawisz F)

Flood fill — wypełnia spójny obszar (4-connectivity: góra/dół/lewo/prawo).

```swift
func paintFill(at gridX: Int, y gridY: Int,
               district: DistrictType?, on map: TerrainMap)
```

BFS z kolejką. Wypełnia komórki z tym samym aktualnym district co punkt startowy.

### Eraser (klawisz E)

Brush z `district = nil` — czyści przypisanie dzielnicy.

## Canvas

### TerrainCanvasView

Pełna interakcja — rendering bezpośredni:

- **Heatmap wysokości**: niebieski (niski) → zielony (środek) → czerwony (wysoki)
- **Overlay dzielnic**: półprzezroczyste kolory per typ
- **Siatka**: pojawia się przy zoom > 2.0x
- **Viewport optimization**: renderuje tylko widoczne komórki

Gesty:
- **Malowanie**: drag gesture z aktualizacją w real-time
- **Zoom**: scroll wheel (macOS) lub pinch (trackpad), zakres 0.1x-10.0x
- **Pan**: drag gdy brak aktywnego narzędzia

### OptimizedTerrainCanvasView

Rendering przez cache'owany obraz (max 2048×2048 px):
- Pre-renderuje cały teren do `CGImage`
- Szybsze odświeżanie — obraz jest skalowany zamiast przeliczany
- Te same narzędzia malowania (współdzielony `DistrictPainter`)

## Undo/Redo

`TerrainUndoManager` — snapshot-based system:

```swift
class TerrainUndoManager {
    func saveSnapshot(_ map: TerrainMap)    // zapisz stan przed operacją
    func undo(on map: TerrainMap)           // przywróć poprzedni stan
    func redo(on map: TerrainMap)           // przywróć następny stan
}
```

- Maksymalnie 50 stanów w historii
- Snapshot = słownik `"x,y" → DistrictType?`
- Skróty klawiaturowe: ⌘Z (undo), ⇧⌘Z (redo)

## Optymalizacje

`TerrainOptimization.swift` zawiera:

### TerrainLODManager

Oblicza poziom agregacji na podstawie zoomu:
- Zoom ≥ 1.0 → agregacja 1×1 (pełna rozdzielczość)
- Zoom 0.5-1.0 → agregacja 2×2
- Zoom 0.1-0.5 → agregacja 5×5
- Zoom < 0.1 → agregacja 10×10

### TerrainChunkManager

Dzieli mapę na chunki (100 komórek) i śledzi widoczność — renderuje tylko chunki w viewport.

## Paleta (DistrictPaletteView)

Panel boczny z:
- Selektor narzędzia (Brush/Fill/Eraser) z ikonami i skrótami klawiaturowymi
- Slider rozmiaru pędzla (1-20)
- Siatka kolorów dzielnic (5 typów z kolorowym wskaźnikiem)

## Pliki źródłowe

- `App/TerrainEditor/TerrainEditorView.swift`
- `App/TerrainEditor/TerrainCanvasView.swift`
- `App/TerrainEditor/OptimizedTerrainCanvasView.swift`
- `App/TerrainEditor/DistrictPainter.swift`
- `App/TerrainEditor/DistrictPaletteView.swift`
- `App/TerrainEditor/PaintTool.swift`
- `App/TerrainEditor/TerrainUndoManager.swift`
- `App/TerrainEditor/TerrainOptimization.swift`
