# System dzielnic

Dzielnice definiują strefy miejskie z unikalnymi wzorcami generowania dróg. Są malowane ręcznie w TerrainEditor i wpływają na zachowanie algorytmu generowania.

## Typy dzielnic

| Typ | Wzorzec dróg | Kąty rozgałęzień | Prawdop. rozgałęzienia | Mnożnik długości |
|-----|-------------|-------------------|----------------------|-----------------|
| `business` | Gęsta siatka | 0°, 90°, -90° | 0.7 | 1.0 |
| `oldTown` | Organiczny | 0°, 30°, -30°, 45°, -45° | 0.9 | 0.6 |
| `residential` | Umiarkowany | 0°, 60°, -60° | 0.6 | 0.8 |
| `industrial` | Szerokie bloki | 0°, 90°, -90° | 0.5 | 1.2 |
| `park` | Minimalny | 0°, 45°, -45° | 0.3 | 0.5 |

Parametry per dzielnica konfigurowane w `RuleConfiguration` — powyższa tabela to wartości domyślne.

## Walidacja

`DistrictValidator` sprawdza spójność namalowanych dzielnic:

```swift
@MainActor
public struct DistrictValidator: Sendable {
    public func validate(_ map: TerrainMap) -> ValidationResult
}

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [ValidationError]
}
```

### Reguły walidacji

1. **Spójność** — każda dzielnica musi być ciągłym obszarem (flood fill, 4-connectivity: góra/dół/lewo/prawo). Fragmentacja = błąd z liczbą fragmentów
2. **Brak nakładania** — wymuszone przez strukturę danych (jeden `DistrictType?` per węzeł)
3. **Puste dzielnice** — dozwolone (pomijane w walidacji)

### Algorytm flood fill

Implementacja BFS z kolejką:
1. Zbierz wszystkie pozycje danego typu dzielnic
2. Rozpocznij flood fill od pierwszej pozycji
3. Odwiedź sąsiadów (4 kierunki) tego samego typu
4. Policz ile fragmentów zostało — jeśli >1, dzielnica jest rozłączona

## Serializacja

`TerrainMapSerializer` zapisuje i odczytuje pełny stan mapy z dzielnicami:

```swift
@MainActor
public struct TerrainMapSerializer: Sendable {
    public func export(_ map: TerrainMap, to url: URL) throws
    public func `import`(from url: URL) throws -> TerrainMap
}
```

Format JSON zachowuje:
- Metadane nagłówka (współrzędne geograficzne, cellsize)
- Wszystkie węzły z obliczonymi właściwościami
- Przypisania dzielnic

Wewnętrznie używa prywatnej struktury `SerializableTerrainMap` — koordynaty TerrainNode są spłaszczone do osobnych pól x/y/z w JSON.

## Jak dzielnice wpływają na generowanie dróg

Algorytm generowania używa dzielnic w dwóch miejscach:

### DistrictBoundaryRule (Local Constraint)
- Blokuje drogi wewnętrzne przed przekraczaniem granic dzielnic
- Drogi główne (`isMainRoad: true`) mogą przekraczać granice
- Priority: 30

### DistrictPatternRule (Global Goal)
- Generuje nowe propozycje dróg według wzorca dzielnic
- Używa kątów rozgałęzień, prawdopodobieństwa i mnożnika długości z `RuleConfiguration`
- Priority: 10

## Pliki źródłowe

- `Packages/Terrain/Sources/Terrain/Models/DistrictType.swift`
- `Packages/Terrain/Sources/Terrain/Validation/DistrictValidator.swift`
- `Packages/Terrain/Sources/Terrain/Serialization/TerrainMapSerializer.swift`
