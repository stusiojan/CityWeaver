# Terrain Builder

Budowanie `TerrainMap` z surowych danych wysokościowych. Dwa builderzy dla różnych scenariuszy.

## TerrainMapBuilder (synchroniczny)

Prosty builder dla małych map (<1M węzłów). Blokujący, jednowątkowy.

```swift
@MainActor
public struct TerrainMapBuilder: Sendable {
    public init()
    public func buildTerrainMap(header: ASCHeader, heights: [[Double]]) -> TerrainMap
}
```

### Jak działa

Dla każdego punktu siatki:
1. Oblicza współrzędne świata: `x = col * cellsize + xllcenter`, `y = row * cellsize + yllcenter`
2. Oblicza nachylenie metodą Horna (Sobel 3x3)
3. Oblicza współczynnik urbanizacji z nachylenia
4. Tworzy `TerrainNode` z `district = nil`

## OptimizedTerrainMapBuilder (async)

Actor-based builder dla dużych map (>1M węzłów). Przetwarza w tle z raportowaniem postępu.

```swift
public actor OptimizedTerrainMapBuilder {
    public init()

    public func buildTerrainMapProgressive(
        header: ASCHeader,
        heights: [[Double]],
        progress: @Sendable @escaping (Double, String) -> Void
    ) async -> TerrainMap

    public func buildDownsampledTerrainMap(
        header: ASCHeader,
        heights: [[Double]],
        downsampleFactor: Int,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async -> TerrainMap
}
```

### Strategia downsampling

| Rozmiar mapy | Czynnik | Redukcja |
|-------------|---------|----------|
| >4M węzłów | 4x | ~5M → ~300K węzłów |
| >2M węzłów | 3x | |
| >1M węzłów | 2x | |
| <1M węzłów | 1x (brak) | |

Downsampling uśrednia wysokości w oknie N×N. Nowy `cellsize` = oryginalny × factor.

### Responsywność UI

- Raportuje postęp co 10 wierszy (callback z 0.0-1.0 i status message)
- Wywołuje `Task.yield()` co 50 wierszy — oddaje kontrolę event loop
- Wynik zwracany przez `MainActor.run` (bo `TerrainMap` jest `@MainActor`)

### Wpływ na pamięć

```
Oryginał: 2000×2000 = 4M węzłów × ~100B = ~400MB RAM
4x downsample: 500×500 = 250K węzłów × ~100B = ~25MB RAM
Redukcja: ~16x w pamięci i koszcie renderowania
```

## Obliczanie nachylenia — metoda Horna

`TerrainCalculator` używa operatora Sobela (3×3) — standard w analizie GIS:

```
Kernel dx:          Kernel dy:
[-1  0  1]          [-1 -2 -1]
[-2  0  2]          [ 0  0  0]
[-1  0  1]          [ 1  2  1]
```

Wzór: `slope = atan(sqrt(dz_dx² + dz_dy²)) / (π/4)` — normalizowany do 0-1.

## Współczynnik urbanizacji

Konwersja nachylenia na zdatność zabudowy:

```swift
func calculateUrbanizationFactor(from slope: Double) -> Double {
    max(0.0, 1.0 - slope * 2.0)
}
```

| Nachylenie | Urbanizacja | Interpretacja |
|-----------|-------------|---------------|
| 0.0 | 1.0 | Płaski teren — w pełni zdatny |
| 0.25 | 0.5 | Umiarkowane nachylenie |
| 0.5+ | 0.0 | Strome — niezdatny do zabudowy |

## Decyzje projektowe

- **Dwa builderzy zamiast jednego z flagą async**: jawne rozdzielenie odpowiedzialności. Synchroniczny builder ma prostszą sygnaturę i nie wymaga `await`
- **Actor (nie Task)**: actor zapewnia izolację stanu — bezpieczne wywoływanie z wielu miejsc
- **Normalizacja nachylenia do 0-1**: ułatwia użycie w regułach generowania (porównywanie progów bez konwersji jednostek)

## Pliki źródłowe

- `Packages/Terrain/Sources/Terrain/Builder/TerrainMapBuilder.swift`
- `Packages/Terrain/Sources/Terrain/Builder/OptimizedTerrainMapBuilder.swift`
- `Packages/Terrain/Sources/Terrain/Calculator/TerrainCalculator.swift`
