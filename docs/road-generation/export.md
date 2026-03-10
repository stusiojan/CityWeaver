# Eksport sieci dróg

Trzy formaty eksportu: JSON (dane + metadane), OBJ (Blender), glTF (game engines). Wszystkie eksportery są `Sendable` i mogą pracować z opcjonalnymi danymi terenu.

## JSON — RoadNetworkSerializer

Pełny eksport z metadanymi do archiwizacji i ponownego importu.

```swift
public struct RoadNetworkSerializer: Sendable {
    public func export(_ segments: [RoadSegment],
                       cityState: CityStateSnapshot,
                       configuration: ConfigurationSnapshot) throws -> Data

    public func `import`(from data: Data) throws -> (roads: [RoadSegment], metadata: Metadata)

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
  ]
}
```

## OBJ — OBJExporter

Format Wavefront OBJ kompatybilny z Blenderem. Generuje geometrię 3D dróg i opcjonalnie terenu.

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
    public let includeTerrain: Bool        // domyślnie true
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

## glTF — GLTFExporter

Format glTF 2.0 z materiałami PBR (metallic/roughness). Lepsze wsparcie materiałowe niż OBJ.

```swift
public struct GLTFExporter: Sendable {
    @MainActor
    public func export(segments: [RoadSegment],
                       terrainMap: TerrainMap?,
                       options: ExportOptions) -> (gltf: String, bin: Data?)

    public func saveToFiles(gltf: String, bin: Data?,
                            directory: URL, basename: String) throws
}
```

### Opcje

Identyczne jak OBJ plus:
- `embedBinary: Bool` — true: dane binarne jako base64 w pliku JSON; false: osobny plik `.bin`

### Struktura glTF

```
.gltf (JSON)
├── scene → nodes → meshes
├── accessors → bufferViews → buffers
├── materials (PBR metallic/roughness)
└── opcjonalnie: embedded base64 binary data

.bin (opcjonalnie)
└── vertex positions + indices
```

## Porównanie formatów

| Cecha | JSON | OBJ | glTF |
|-------|------|-----|------|
| Metadane generowania | tak | nie | nie |
| Reimport do CityWeaver | tak | nie | nie |
| Geometria 3D | nie | tak | tak |
| Materiały PBR | n/a | bazowe | tak |
| Teren | nie | opcjonalnie | opcjonalnie |
| Game engines | nie | limitowane | tak |
| Rozmiar pliku | mały | duży (tekst) | mały (binarny) |

## Pliki źródłowe

- `Packages/RoadGeneration/Sources/RoadGeneration/Export/RoadNetworkSerializer.swift`
- `Packages/RoadGeneration/Sources/RoadGeneration/Export/OBJExporter.swift`
- `Packages/RoadGeneration/Sources/RoadGeneration/Export/GLTFExporter.swift`
