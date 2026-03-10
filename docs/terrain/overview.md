# Pakiet Terrain

Samodzielny Swift Package odpowiedzialny za ładowanie, przetwarzanie i zarządzanie danymi terenowymi. Fundament całego systemu — dostarcza `TerrainMap` do algorytmu generowania dróg.

## Co robi

Terrain przetwarza surowe dane wysokościowe (pliki ASC) w strukturę `TerrainMap` wzbogaconą o obliczone właściwości (nachylenie, współczynnik urbanizacji) i ręcznie malowane dzielnice. Nie zawiera żadnego kodu UI.

## Struktura modułu

```
Packages/Terrain/Sources/Terrain/
├── Models/
│   ├── ASCHeader.swift              — metadane pliku ASC
│   ├── TerrainNode.swift            — pojedynczy punkt siatki
│   ├── TerrainMap.swift             — kompletna mapa terenu
│   └── DistrictType.swift           — typy dzielnic
├── Parser/
│   └── ASCParser.swift              — parser formatu ESRI ASCII Grid
├── Calculator/
│   └── TerrainCalculator.swift      — obliczanie nachylenia i urbanizacji
├── Builder/
│   ├── TerrainMapBuilder.swift      — synchroniczny builder (małe mapy)
│   └── OptimizedTerrainMapBuilder.swift — async builder z downsampling
├── Validation/
│   └── DistrictValidator.swift      — walidacja spójności dzielnic
└── Serialization/
    └── TerrainMapSerializer.swift   — import/export JSON
```

## Dataflow

```
Plik ASC (.asc)
    │
    ▼
ASCParser.load(from:)
    │
    ├─► ASCHeader (metadane: wymiary, cellsize, origin)
    └─► [[Double]] (siatka wysokości)
    │
    ▼
TerrainMapBuilder / OptimizedTerrainMapBuilder
    │
    ├─► TerrainCalculator.calculateSlope()         — metoda Horna (Sobel 3x3)
    └─► TerrainCalculator.calculateUrbanizationFactor()
    │
    ▼
TerrainMap (gotowa do użycia)
    │
    ├─► RoadGenerator (jako wejście do generowania dróg)
    ├─► TerrainEditor UI (malowanie dzielnic)
    │
    ▼
TerrainMapSerializer.export()
    │
    ▼
JSON (z dzielnicami i obliczonymi właściwościami)
```

## Kluczowe typy

### TerrainNode

Pojedynczy punkt siatki terenu (1x1m rozdzielczość):

```swift
public struct TerrainNode: Sendable, Codable {
    public let coordinates: Coordinates  // x, y (world), z (wysokość)
    public let slope: Double             // 0-1 (0=płaski, 1=45°+)
    public let urbanizationFactor: Double // 0-1 (0=niezdatny, 1=płaski)
    public var district: DistrictType?   // opcjonalnie przypisana dzielnica
}
```

### TerrainMap

Kompletna mapa terenu — `@MainActor final class`:

```swift
@MainActor
public final class TerrainMap: Sendable {
    public let header: ASCHeader
    public var nodes: [[TerrainNode]]     // read-only
    public var dimensions: (rows: Int, cols: Int)

    public func getNode(at x: Int, y: Int) -> TerrainNode?
    public func getNode(at point: (x: Double, y: Double)) -> TerrainNode?
    public func setDistrict(at x: Int, y: Int, district: DistrictType?)
    public func getNodes(for district: DistrictType) -> [(x: Int, y: Int, node: TerrainNode)]
}
```

### DistrictType

```swift
public enum DistrictType: String, CaseIterable, Codable, Sendable {
    case business      // gęsta siatka, proste drogi, skrzyżowania 90°
    case oldTown       // organiczny układ, nieregularne kąty
    case residential   // umiarkowana gęstość, zakrzywione ulice
    case industrial    // szerokie drogi, duże bloki
    case park          // minimalna ilość dróg
}
```

## Zależności

Brak — Terrain jest samodzielnym pakietem bez zewnętrznych zależności.

```
Platform: macOS 15.0+
Swift tools: 6.0
```

## Decyzje projektowe

- **@MainActor na TerrainMap**: upraszcza concurrency — mapa terenu jest modyfikowana tylko z main thread (malowanie dzielnic w UI). Trade-off: nie można modyfikować mapy z background threadów, ale w praktyce jedynym konsumentem jest UI
- **Sendable na wszystkich typach**: umożliwia bezpieczne przekazywanie danych między aktorami
- **Dwa builderzy**: synchroniczny dla małych map (<1M węzłów), async actor dla dużych — kompromis między prostotą API a responsywnością UI
- **Horn's method (Sobel)**: standard w GIS dla obliczania nachylenia z danych rastrowych. Alternatywa: prosta różnica między sąsiadami, ale Sobel daje gładsze wyniki

## Powiązane dokumenty

- [ASC Parser](asc-parser.md) — szczegóły parsowania formatu ESRI ASCII Grid
- [Terrain Builder](terrain-builder.md) — budowanie mapy z optymalizacjami
- [System dzielnic](district-system.md) — dzielnice, walidacja, serializacja
