# Eksport sieci dróg

Dwa formaty eksportu: JSON (dane + metadane) i OBJ (Blender). Oba wspierają wybór eksportowanej zawartości: tylko drogi, tylko teren, lub drogi i teren razem.

## ExportContent

Wspólny enum kontrolujący zakres eksportu:

```swift
public enum ExportContent: String, CaseIterable, Sendable {
    case roadsOnly = "Roads Only"
    case terrainOnly = "Terrain Only"
    case roadsAndTerrain = "Roads & Terrain"
}
```

## JSON — RoadNetworkSerializer

Pełny eksport z metadanymi do archiwizacji i ponownego importu.

```swift
public struct RoadNetworkSerializer: Sendable {
    public func export(_ segments: [RoadSegment],
                       cityState: CityStateSnapshot,
                       configuration: ConfigurationSnapshot,
                       content: ExportContent = .roadsOnly,
                       terrainSnapshot: TerrainSnapshot? = nil) throws -> Data

    public func `import`(from data: Data) throws -> (roads: [RoadSegment], metadata: Metadata, terrain: TerrainSnapshot?)

    // uproszczona wersja — tylko segmenty, bez metadanych
    public func exportSimple(_ segments: [RoadSegment]) throws -> Data
    public func importSimple(from data: Data) throws -> [RoadSegment]
}
```

Struktura JSON:
```json
{
  "metadata": {
    "generatedAt": "2026-01-04T...",
    "cityState": { "population": 50000, "density": 1500, ... },
    "configuration": { "maxBuildableSlope": 0.3, ... }
  },
  "roads": [
    { "id": "uuid", "attributes": { "startPoint": {...}, "angle": 0, "length": 100, "roadType": "main" }, "createdAt": 0 }
  ],
  "terrain": {
    "cols": 500, "rows": 500, "cellsize": 1.0,
    "heights": [[...]]
  }
}
```

Pola `roads` i `terrain` są opcjonalne — obecność zależy od wybranego `ExportContent`.

## OBJ — OBJExporter

Format Wavefront OBJ kompatybilny z Blenderem. Generuje geometrię 3D dróg i/lub terenu w zależności od `ExportContent`.

```swift
public struct OBJExporter: Sendable {
    @MainActor
    public func export(segments: [RoadSegment],
                       terrainMap: TerrainMap?,
                       options: ExportOptions) -> (obj: String, mtl: String)

    public func saveToFiles(obj: String, mtl: String,
                            directory: URL, basename: String) throws
}

public struct ExportOptions: Sendable {
    public let roadWidth: Double           // domyślnie 4.0m
    public let roadElevation: Double       // domyślnie 0.1m nad terenem
    public let content: ExportContent      // domyślnie .roadsAndTerrain
    public let terrainDownsample: Int      // domyślnie 1 (pełna rozdzielczość)
    public let terrainVerticalScale: Double // domyślnie 1.0
}
```

### Geometria

- **Drogi**: prostokątne graniastosłupy (6 ścian) — szerokość z `roadWidth`, wysokość z `roadElevation`
- **Teren**: siatka trójkątów z downsamplowanych węzłów
- **Materiały**: osobny plik `.mtl` — ciemnoszary dla dróg, brązowy dla terenu

### Import do Blendera

1. File → Import → Wavefront (.obj)
2. Wybierz plik `.obj` (`.mtl` ładuje się automatycznie)
3. Drogi i teren z materiałami

## Porównanie formatów

| Cecha | JSON | OBJ |
|-------|------|-----|
| Metadane generowania | tak | nie |
| Reimport do CityWeaver | tak | nie |
| Geometria 3D | nie | tak |
| Teren | opcjonalnie | opcjonalnie |
| Kontrola zawartości | tak | tak |
| Rozmiar pliku | mały–średni | duży (tekst) |

## Pliki źródłowe

- `Packages/RoadGeneration/Sources/RoadGeneration/Export/ExportContent.swift`
- `Packages/RoadGeneration/Sources/RoadGeneration/Export/RoadNetworkSerializer.swift`
- `Packages/RoadGeneration/Sources/RoadGeneration/Export/OBJExporter.swift`
