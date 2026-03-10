# ASC Parser

Parser formatu ESRI ASCII Grid (.asc) — standardowego formatu GIS dla danych rastrowych wysokościowych.

## Format pliku

```
ncols         2229
nrows         2323
xllcenter     513329.00
yllcenter     276352.00
cellsize      1.00
nodata_value  -9999
<dane wysokości w wierszach...>
```

Plik składa się z nagłówka (6 linii) i siatki wartości wysokości rozdzielonych spacjami.

## API

```swift
public struct ASCParser: Sendable {
    public init()
    public func load(from url: URL) throws -> (ASCHeader, [[Double]])
}
```

Zwraca krotkę: metadane nagłówka + dwuwymiarowa siatka wysokości.

## Obsługa wariantów

Parser automatycznie rozpoznaje:

| Wariant nagłówka | Obsługa |
|-----------------|---------|
| `xllcenter` / `yllcenter` | Bezpośrednie użycie |
| `xllcorner` / `yllcorner` | Konwersja na center (+ cellsize/2) |
| `NODATA_VALUE` / `nodata_value` | Case-insensitive |

Wartości NODATA w siatce są zamieniane na `0.0`.

## Obsługa błędów

```swift
public enum ASCParserError: Error, LocalizedError {
    case fileNotFound
    case invalidHeader
    case invalidGridData
    case nodataValueNotSupported
    case invalidFileFormat
}
```

Walidacja sprawdza:
- Czy plik istnieje i jest czytelny
- Czy nagłówek zawiera wymagane pola (ncols, nrows, cellsize)
- Czy wymiary siatki zgadzają się z nagłówkiem

## Wydajność

Parser przetwarza pliki liniowo — złożoność O(rows × cols). Dla dużych plików (np. 2229×2323 = ~5M wartości) ładowanie trwa kilka sekund. Samo parsowanie nie downsampluje — to odpowiedzialność `OptimizedTerrainMapBuilder`.

## Plik źródłowy

`Packages/Terrain/Sources/Terrain/Parser/ASCParser.swift`
