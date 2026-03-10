# Stack technologiczny

## Języki i frameworki

| Technologia | Rola | Wersja |
|-------------|------|--------|
| **Swift** | Język programowania | 6.0+ |
| **SwiftUI** | Warstwa UI (macOS) | macOS 15.0+ |
| **SceneKit** | Wizualizacja 3D | System framework |
| **swift-collections** | Heap<T> dla priority queue | ≥ 1.0.0 |
| **XCTest** | Testy jednostkowe | System framework |

## Narzędzia developerskie

| Narzędzie | Rola | Uwagi |
|-----------|------|-------|
| **xcodegen** | Generowanie `.xcodeproj` z `project.yml` | Unika konfliktów merge w pbxproj |
| **xcode-build-server** | Bridge LSP między xcodeproj a edytorem | `buildServer.json` — kluczowe dla dev poza Xcode |
| **swiftformat** | Formatowanie kodu | |
| **xcbeautify** | Czytelne output z xcodebuild | |

## Komendy build

```bash
make build          # xcodebuild (Debug scheme)
make run            # uruchom zbudowaną aplikację
make test-terrain   # testy pakietu Terrain
make test-rga       # testy pakietu RoadGeneration
make test-core      # testy pakietu Core
make generate-xcodeproj  # regeneruj xcodeproj z project.yml
make lsp-bind       # powiąż LSP z xcodeproj
make clean-build    # usuń katalog .build
```

## Architektura modułów

```
App (SwiftUI) ─────────────┐
    │                      │
    ├── Terrain            │ Swift Packages
    ├── RoadGeneration ────┤ (w Packages/)
    ├── RGA                │
    ├── Core               │
    └── Shared             │
                           │
swift-collections ─────────┘ External dependency
```

## Konfiguracja projektu

- **`project.yml`**: manifest xcodegen — target, zależności, schematy
- **`buildServer.json`**: konfiguracja xcode-build-server
- **`makefile`**: skróty do build/test/clean
- **`Packages/*/Package.swift`**: manifesty Swift packages

## Decyzje technologiczne

- **Swift Packages zamiast framework targets**: izolacja, testowalność, czyste zależności
- **xcodegen zamiast ręcznego xcodeproj**: YAML jest merge-friendly; regeneracja po zmianach struktury
- **SceneKit zamiast RealityKit**: dojrzalsze API na macOS, prostsze do bazowej wizualizacji
- **Brak trzecich bibliotek (poza swift-collections)**: minimalne zależności, łatwiejsze utrzymanie
