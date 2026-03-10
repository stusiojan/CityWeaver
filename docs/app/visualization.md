# Wizualizacja 3D

Wizualizacja sieci dróg i terenu w 3D przy użyciu SceneKit.

## RoadNetwork3DView

Główny widok 3D osadzony w `SCNView` przez `NSViewRepresentable`:

### Kontrolki

| Akcja | Sterowanie |
|-------|-----------|
| Obrót | Przeciąganie myszą |
| Zoom | Scroll / pinch |
| Pan | Option + przeciąganie |
| Reset | Podwójne kliknięcie |

### Opcje wyświetlania

- **Show Terrain**: toggle siatki terenu (domyślnie: on)
- **Show Roads**: toggle dróg (domyślnie: on)
- **Show Grid**: siatka referencyjna (domyślnie: off)
- **Vertical Scale**: 0.1x - 5.0x — skalowanie wysokości terenu
- **Terrain Detail**: 1-10x downsampling — mniej trójkątów = szybszy rendering

### Pasek informacji

Wyświetla wymiary mapy i podpowiedzi sterowania.

## SceneBuilder

Buduje `SCNScene` z danych terenu i dróg:

```swift
struct SceneBuilder {
    struct BuildOptions {
        let roadWidth: Double           // domyślnie 4.0
        let roadHeight: Double          // domyślnie 0.5
        let terrainVerticalScale: Double // domyślnie 1.0
        let terrainDownsample: Int      // domyślnie 1
        let showGrid: Bool
    }

    @MainActor
    func buildScene(terrainMap: TerrainMap?,
                    roads: [RoadSegment],
                    options: BuildOptions) -> SCNScene
}
```

### Geometria terenu

1. Downsampluje węzły (co N-ty węzeł)
2. Tworzy siatkę trójkątów z wierzchołków
3. Koloruje wg wysokości (gradient brązowy → zielony)
4. Skaluje pionowo wg `terrainVerticalScale`

### Geometria dróg

1. Każdy segment → prostokątny graniastosłup
2. Szerokość z `roadWidth`, wysokość z `roadHeight`
3. Pozycja: punkt startowy + kąt + elevation z terenu
4. Kolor per typ: niebieski (main/highway), szary (residential/street)

### Oświetlenie

- **Ambient light**: miękkie oświetlenie otoczenia
- **Directional light**: słońce z cieniami (pod kątem)
- **Kamera**: automatycznie pozycjonowana żeby objąć całą scenę

## Opcje eksportu (ExportOptionsView)

Dostępne z RoadGeneratorView:

| Format | Eksporter | Opcje |
|--------|-----------|-------|
| JSON | `RoadNetworkSerializer` | Metadane + segmenty |
| OBJ | `OBJExporter` | Szerokość, teren, downsampling |
| glTF | `GLTFExporter` | j.w. + embedded binary |

## Decyzje projektowe

- **SceneKit zamiast RealityKit**: macOS 15 kompatybilność. RealityKit na macOS jest mniej dojrzały i ma mniejsze API surface
- **Turntable camera**: orbit control — naturalny dla inspekcji obiektów 3D
- **Downsampling terenu w 3D**: niezależny od downsamplingu przy ładowaniu — użytkownik kontroluje osobno, co pozwala na szybką wizualizację dużych map
- **Brak LOD w runtime**: scena budowana jednorazowo — OK dla obecnych rozmiarów, ale może wymagać optymalizacji dla bardzo dużych sieci

## Pliki źródłowe

- `App/Visualization/RoadNetwork3DView.swift`
- `App/Visualization/SceneBuilder.swift`
