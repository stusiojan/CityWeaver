# Road Generation System Architecture

## Overview

This document describes the architecture of a procedural city road generation system that uses a priority queue-based algorithm with a flexible, rule-based constraint and goal system. The system is designed to integrate with a city growth simulation that dynamically updates road generation rules based on terrain, population, and urban development factors.

The system consists of few main modules:
1. **Terrain Module** (Implemented) - Handles loading, processing, and managing terrain data from ASC files
2. **Road Generation Module** (POC implemented as RGA package) - Generates road networks based on terrain and city state
3. **Export Module** (To be implemented) - Exporting city maps to json or other formats
4. **UI** (Partially implemented) - Enables user friendly input entering and displaying generated city

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    City Growth Simulation                    │
│         (External - Updates CityState & TerrainMap)         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ├─► CityState (population, density, age)
                     ├─► TerrainMap (1x1m node grid with height data)
                     └─► Configuration Updates
                     
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                      RoadGenerator                           │
│  ┌───────────────────────────────────────────────────┐      │
│  │            Priority Queue (Heap<RoadQuery>)       │      │
│  │              Sorted by time/priority               │      │
│  └───────────────────────────────────────────────────┘      │
│                                                               │
│  ┌─────────────────┐         ┌─────────────────────┐        │
│  │ Constraint      │         │ Goal                │        │
│  │ Evaluator       │         │ Evaluator           │        │
│  │                 │         │                     │        │
│  │ ┌─────────────┐ │         │ ┌─────────────────┐ │        │
│  │ │  Rules[]:   │ │         │ │   Rules[]:      │ │        │
│  │ │  - Boundary │ │         │ │   - District    │ │        │
│  │ │  - Angle    │ │         │ │     Pattern     │ │        │
│  │ │  - Terrain  │ │         │ │   - Coastal     │ │        │
│  │ │  - Proximity│ │         │ │     Growth      │ │        │
│  │ │  - District │ │         │ │   - Connectivity│ │        │
│  │ └─────────────┘ │         │ └─────────────────┘ │        │
│  └─────────────────┘         └─────────────────────┘        │
│          ▲                            ▲                      │
│          │                            │                      │
│  ┌───────┴─────────┐         ┌────────┴─────────┐           │
│  │ Constraint      │         │ Goal             │           │
│  │ Generator       │         │ Generator        │           │
│  └─────────────────┘         └──────────────────┘           │
│          ▲                            ▲                      │
│          └────────────┬───────────────┘                      │
│                       │                                      │
│              ┌────────┴─────────┐                            │
│              │ RuleConfiguration│                            │
│              │ (Single Source   │                            │
│              │  of Truth)       │                            │
│              └──────────────────┘                            │
└─────────────────────────────────────────────────────────────┘
                     │
                     ▼
           ┌─────────────────┐
           │  RoadSegment[]  │
           │  (Final Output) │
           └─────────────────┘
```

---

## Terrain Module

The Terrain module is a standalone Swift package (`Packages/Terrain/`) that handles all terrain data loading, processing, and management. It provides the foundation for road generation by supplying terrain information with calculated properties like slope and urbanization factor.

### Module Structure

```
Packages/Terrain/
├── Package.swift
├── Sources/Terrain/
│   ├── Models/
│   │   ├── ASCHeader.swift           # ASC file header metadata
│   │   ├── TerrainNode.swift         # Single terrain grid point
│   │   ├── TerrainMap.swift          # Complete terrain data structure
│   │   └── DistrictType.swift        # District classification enum
│   ├── Parser/
│   │   └── ASCParser.swift           # ASC file format parser
│   ├── Calculator/
│   │   └── TerrainCalculator.swift   # Slope and urbanization calculations
│   ├── Builder/
│   │   ├── TerrainMapBuilder.swift           # Synchronous builder for small maps
│   │   └── OptimizedTerrainMapBuilder.swift  # Async builder with downsampling
│   ├── Validation/
│   │   └── DistrictValidator.swift   # District boundary validation
│   └── Serialization/
│       └── TerrainMapSerializer.swift # JSON import/export
└── Tests/TerrainTests/
    ├── ASCParserTests.swift
    ├── TerrainCalculatorTests.swift
    ├── TerrainMapBuilderTests.swift
    └── DistrictValidatorTests.swift
```

### Data Flow

```
ASC File (.asc)
    │
    ▼
ASCParser.load(from:)
    │
    ├─► ASCHeader (metadata)
    └─► [[Double]] (height grid)
    │
    ▼
TerrainMapBuilder.buildTerrainMap()
    │
    ├─► TerrainCalculator.calculateSlope() for each node
    ├─► TerrainCalculator.calculateUrbanizationFactor() for each node
    │
    ▼
TerrainMap (ready for road generation)
    │
    ├─► Used by RoadGenerator
    ├─► User paints districts via TerrainEditor UI
    │
    ▼
TerrainMapSerializer.export()
    │
    ▼
JSON file (with districts)
```

### Key Components

#### 1. ASC File Format Support

The module supports standard ESRI ASCII Grid format (.asc):

```
ncols         2229
nrows         2323
xllcenter     513329.00
yllcenter     276352.00
cellsize      1.00
nodata_value  -9999
<grid data follows...>
```

**ASCParser** handles:
- Flexible header parsing (auto-detects header lines)
- Both `xllcenter/yllcenter` and `xllcorner/yllcorner`
- NODATA value replacement (converts to 0.0)
- Error handling with descriptive messages

```swift
public struct ASCParser {
    public func load(from url: URL) throws -> (ASCHeader, [[Double]])
}
```

#### 2. Terrain Calculations

**TerrainCalculator** derives properties from elevation data:

```swift
public struct TerrainCalculator {
    func calculateSlope(at x: Int, y: Int, heights: [[Double]], cellsize: Double) -> Double
    func calculateUrbanizationFactor(from slope: Double) -> Double
}
```

**Slope Calculation:**
- Uses Horn's method (3x3 kernel convolution)
- Returns slope as rise/run ratio (0-1+ range)
- Formula: `sqrt(dz_dx² + dz_dy²) / cellsize`

**Urbanization Factor:**
- Converts slope to buildability score (0-1)
- Formula: `max(0, 1 - (slope / 0.5))`
- Interpretation:
  - 1.0: Flat terrain, fully buildable
  - 0.5: Moderate slope
  - 0.0: Slope ≥ 0.5 (50% grade), unbuildable

#### 3. TerrainMap Data Structure

**Core Models:**

```swift
// ASC file metadata
public struct ASCHeader: Codable, Sendable {
    let ncols: Int
    let nrows: Int
    let xllcenter: Double
    let yllcenter: Double
    let cellsize: Double
    let nodataValue: Double
}

// Single terrain grid point
public struct TerrainNode: Codable, Sendable {
    struct Coordinates: Codable, Sendable {
        let x: Double  // World X coordinate
        let y: Double  // World Y coordinate
        let z: Double  // Elevation
    }
    
    let coordinates: Coordinates
    let slope: Double                    // 0-1+
    let urbanizationFactor: Double       // 0-1
    var district: DistrictType?          // Optional district assignment
}

// Complete terrain map
@MainActor
public final class TerrainMap: Codable, Sendable {
    public let header: ASCHeader
    private var nodes: [[TerrainNode]]
    
    public var dimensions: (rows: Int, cols: Int) { ... }
    public func getNode(at x: Int, y: Int) -> TerrainNode?
    public func setDistrict(at x: Int, y: Int, district: DistrictType?)
}

// District types
public enum DistrictType: String, Codable, CaseIterable, Sendable {
    case business
    case oldTown
    case residential
    case industrial
    case park
}
```

#### 4. Performance Optimizations

**Two Builder Implementations:**

**TerrainMapBuilder** (Synchronous):
- For maps < 1M nodes
- Blocking operation
- Simple API

**OptimizedTerrainMapBuilder** (Actor):
- For large maps (> 1M nodes)
- Background processing with progress callbacks
- Automatic downsampling strategy:
  - `> 4M nodes`: 4x downsampling (~5M → ~300K nodes)
  - `> 2M nodes`: 3x downsampling
  - `> 1M nodes`: 2x downsampling
  - `< 1M nodes`: No downsampling
- Task yielding every 50 rows for UI responsiveness

```swift
public actor OptimizedTerrainMapBuilder {
    public func buildDownsampledTerrainMap(
        header: ASCHeader,
        heights: [[Double]],
        downsampleFactor: Int,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async -> TerrainMap
}
```

**Memory & Performance:**
- Original: 2000×2000 map = 4M nodes × ~100 bytes = ~400MB RAM
- Downsampled 4x: 500×500 = 250K nodes × ~100 bytes = ~25MB RAM
- 16x reduction in memory usage and rendering cost

#### 5. District Management

**DistrictValidator** ensures district integrity:

```swift
public struct DistrictValidator {
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [ValidationError]
    }
    
    public enum ValidationError {
        case districtNotConnected(district: DistrictType, fragmentCount: Int)
    }
    
    public func validate(_ map: TerrainMap) -> ValidationResult
}
```

**Validation Rules:**
- Districts must be contiguous (uses flood-fill algorithm)
- No overlapping districts (enforced by data structure)
- Reports number of disconnected fragments

#### 6. Persistence

**TerrainMapSerializer** for saving/loading:

```swift
public struct TerrainMapSerializer {
    public func export(_ map: TerrainMap) throws -> Data       // To JSON
    public func `import`(from data: Data) throws -> TerrainMap // From JSON
}
```

Preserves:
- Header metadata (geographic coordinates, cell size)
- All terrain nodes with calculated properties
- District assignments from user painting

### Terrain Editor UI

Interactive application for terrain preparation (`App/TerrainEditor/`):

**Features:**
1. **File Loading:**
   - `.fileImporter` for selecting ASC files
   - Automatic downsampling for large files
   - Progress indicator during loading

2. **Visualization:**
   - Height-based heatmap (blue=low → green=mid → red=high)
   - Interactive Canvas with viewport rendering
   - Grid lines when zoomed in (scale > 2.0x)

3. **District Painting Tools:**
   - **Brush:** Adjustable size (1-20 cells)
   - **Fill:** Flood-fill for large areas
   - **Eraser:** Remove district assignments
   - District overlay with semi-transparent colors

4. **Navigation:**
   - Pinch-to-zoom (trackpad, 2 fingers)
   - Scroll wheel zoom (mouse)
   - Pan by dragging (when not painting)
   - Zoom range: 0.1x to 10x

5. **Editing Features:**
   - Undo/Redo system (keyboard shortcuts ⌘Z / ⇧⌘Z)
   - Tool shortcuts (B=Brush, F=Fill, E=Eraser)
   - Real-time validation feedback

6. **Export/Import:**
   - Save terrain maps with districts to JSON
   - Load previously saved maps
   - Validate before export

**Performance Optimizations:**
- Viewport rendering (only draw visible cells)
- Level of Detail based on zoom
- Debounced updates during painting
- Efficient gesture handling

### Integration with Road Generation

The Terrain module provides `TerrainMap` to the Road Generator:

```swift
// Road generation will receive:
let terrainMap: TerrainMap

// Access terrain data:
if let node = terrainMap.getNode(at: x, y: y) {
    let slope = node.slope
    let buildable = node.urbanizationFactor
    let district = node.district
    let elevation = node.coordinates.z
    
    // Use in constraint rules:
    // - TerrainConstraintRule checks slope and urbanizationFactor
    // - DistrictPatternRule uses district type
    // - Elevation affects road connections
}
```

**Key Usage Patterns:**

1. **Constraint Evaluation:**
   ```swift
   let node = terrainMap.getNode(at: proposedLocation)
   if node.urbanizationFactor < config.minUrbanizationFactor {
       return .failed  // Too steep to build
   }
   ```

2. **District-Based Generation:**
   ```swift
   if node.district == .business {
       // Generate grid pattern
   } else if node.district == .oldTown {
       // Generate organic layout
   }
   ```

3. **Elevation-Aware Routing:**
   ```swift
   let elevationDiff = abs(startNode.coordinates.z - endNode.coordinates.z)
   if elevationDiff > config.maxElevationChange {
       // Add switchbacks or reject route
   }
   ```

---

## Core Components (Road Generation - To Be Implemented)

### 1. Data Structures

#### **TerrainNode**
- Represents a single point in the terrain grid (1x1m resolution)
- **Attributes:**
  - `coordinates`: (x, y, z) position
  - `slope`: Terrain steepness (0-1)
  - `urbanizationFactor`: Buildability factor (0-1)
  - `district`: District classification (business, old town, residential, etc.)
- **Extensibility:** Can add soil type, water proximity, vegetation, flood risk

#### **CityState**
- Current state of the city simulation
- **Attributes:**
  - `population`: Total population
  - `density`: Population per km²
  - `economicLevel`: Economic development (0-1)
  - `age`: City age in simulation years
  - `needsRuleRegeneration`: Flag for rule updates
- **Extensibility:** Can add GDP, traffic congestion, pollution, housing demand

#### **RoadAttributes & QueryAttributes**
- `RoadAttributes`: Final geometric properties of a road segment
- `QueryAttributes`: Proposal data for validation
- **Attributes:**
  - `startPoint`: Starting position
  - `angle`: Direction in radians
  - `length`: Segment length
  - `roadType`: Road classification
  - `isMainRoad`: (QueryAttributes only) Main road flag
- **Extensibility:** Can add width, surface type, elevation, lanes

#### **RoadSegment**
- Immutable confirmed road segment
- **Attributes:**
  - `id`: Unique identifier
  - `attributes`: Road geometry
  - `createdAt`: Creation timestamp
- **Extensibility:** Can add traffic flow, maintenance schedule, connections

#### **RoadQuery**
- Priority queue item representing a road proposal
- **Attributes:**
  - `time`: Priority value (lower = higher priority)
  - `roadAttributes`: Proposed geometry
  - `queryAttributes`: Validation data
- Implements `Comparable` for priority queue ordering

#### **GenerationContext**
- Context object containing all state needed for rule evaluation
- **Attributes:**
  - `currentLocation`: Location being evaluated
  - `terrainMap`: Terrain data
  - `cityState`: Current city state
  - `existingInfrastructure`: Already generated roads
  - `queryAttributes`: The proposal being evaluated

---

### 2. Configuration System

#### **RuleConfiguration**
- **Single source of truth** for all rule parameters
- Organized by category:
  - **Boundary constraints:** City bounds
  - **Angle constraints:** Min/max angles for main and internal roads
  - **Distance constraints:** Minimum spacing between roads and intersections
  - **Terrain constraints:** Max slope, min urbanization factor
  - **Global goal parameters:** Branching probabilities, length multipliers, branching angles per district
  - **Timing:** Delays for different road types

**Design Principle:** All numeric values and configuration should be centralized here. Rules reference this configuration rather than hardcoding values.

---

### 3. Rule System

#### **Rule Protocols**

##### **LocalConstraintRule**
```swift
protocol LocalConstraintRule {
    var priority: Int { get }
    var applicabilityScope: RuleScope { get }
    var config: RuleConfiguration { get set }
    
    func applies(to context: GenerationContext) -> Bool
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
}
```

- **Purpose:** Validate road proposals against local constraints
- **Returns:** `ConstraintResult` with state (succeed/failed) and potentially adjusted query
- **Priority:** Lower number = higher priority (evaluated first)

##### **GlobalGoalRule**
```swift
protocol GlobalGoalRule {
    var priority: Int { get }
    var applicabilityScope: RuleScope { get }
    var config: RuleConfiguration { get set }
    
    func applies(to context: GenerationContext) -> Bool
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext) -> [RoadProposal]
}
```

- **Purpose:** Generate new road proposals based on city planning goals
- **Returns:** Array of `RoadProposal` (0-3 new roads)
- **Priority:** Lower number = higher priority (evaluated first)

#### **RuleScope**
Defines where a rule applies:
- `.citywide`: Applies everywhere
- `.district(DistrictType)`: Applies in specific district
- `.segmentSpecific`: Applies based on individual segment properties

---

### 4. Implemented Rules

#### **Local Constraint Rules**

| Rule | Priority | Scope | Purpose |
|------|----------|-------|---------|
| **BoundaryConstraintRule** | 10 | Citywide | Ensures roads stay within city bounds |
| **TerrainConstraintRule** | 15 | Citywide | Validates slope and urbanization factor |
| **AngleConstraintRule** | 20 | Segment-specific | Enforces intersection angle requirements (60-170° for main roads, wider for internal) |
| **ProximityConstraintRule** | 25 | Citywide | Prevents roads from being too close |
| **DistrictBoundaryRule** | 30 | Segment-specific | Hard transitions at district boundaries |

#### **Global Goal Rules**

| Rule | Priority | Scope | Purpose |
|------|----------|-------|---------|
| **CoastalGrowthRule** | 5 | Citywide (coastal areas) | Biases growth along coastlines |
| **ConnectivityRule** | 8 | Citywide (main roads) | Ensures districts connect via main roads |
| **DistrictPatternRule** | 10 | Segment-specific | Generates roads based on district patterns (grid for business, organic for old town) |

---

### 5. Rule Generators

#### **LocalConstraintGenerator**
- **Responsibility:** Creates constraint rules based on city state and terrain
- **Method:** `generateRules(from cityState, terrainMap, config) -> [LocalConstraintRule]`
- **Logic:**
  - Always includes boundary, terrain, proximity constraints
  - Conditionally adds angle constraint (for cities age > 0)
  - Always includes district boundary rule
  - Returns rules sorted by priority

#### **GlobalGoalGenerator**
- **Responsibility:** Creates goal rules based on city state and terrain
- **Method:** `generateRules(from cityState, terrainMap, config) -> [GlobalGoalRule]`
- **Logic:**
  - Always includes district pattern rule
  - Adds coastal growth rule
  - Conditionally adds connectivity rule (for cities age > 5)
  - Returns rules sorted by priority

**Design Note:** Generators can inspect city state and terrain to decide which rules to include and with what parameters. As the city evolves, the rule set evolves.

---

### 6. Rule Evaluators

#### **LocalConstraintEvaluator**
- **Responsibility:** Evaluates all applicable local constraint rules
- **Method:** `evaluate(_ qa, context) -> (QueryAttributes, ConstraintState)`
- **Process:**
  1. Iterate through rules in priority order
  2. For each rule that applies to the context:
     - Evaluate the constraint
     - If failed, return immediately with failed state
     - If succeeded, potentially adjust query and continue
  3. Return final adjusted query and succeed state

#### **GlobalGoalEvaluator**
- **Responsibility:** Generates proposals from all applicable global goal rules
- **Method:** `generateProposals(_ qa, _ ra, context) -> [RoadProposal]`
- **Process:**
  1. Iterate through rules in priority order
  2. For each rule that applies to the context:
     - Generate proposals
     - Collect all proposals
  3. Return combined list of proposals

**Design Note:** Multiple rules can contribute proposals. Higher priority rules evaluate first, but all applicable rules contribute.

---

### 7. Main Algorithm (RoadGenerator)

#### **Core Algorithm Flow**

```
1. Initialize priority queue Q with seed road query r(0, ra, qa)
2. Initialize empty segment list S
3. WHILE Q is not empty:
     a. Pop road query r(t, ra, qa) with smallest time t from Q
     b. Create generation context with current state
     c. Evaluate local constraints:
          (adjusted_qa, state) = constraintEvaluator.evaluate(qa, context)
     d. IF state == SUCCEED:
          i.  Create segment from ra and add to S
          ii. Generate new proposals:
               proposals = goalEvaluator.generateProposals(adjusted_qa, ra, context)
          iii. For each proposal:
                - Create new RoadQuery with time = t + proposal.delay
                - Insert into Q
4. RETURN S (final road network)
```

#### **Key Methods**

- **`generateRoadNetwork(initialRoad, initialQuery)`**
  - Main entry point for road generation
  - Processes priority queue until empty
  - Returns final list of road segments

- **`updateCityState(newCityState)`**
  - Updates city state
  - Regenerates rules if `needsRuleRegeneration` flag is set

- **`updateTerrainMap(newTerrainMap)`**
  - Updates terrain data
  - Triggers rule regeneration

- **`updateConfiguration(newConfig)`**
  - Updates rule configuration
  - Triggers rule regeneration

- **`regenerateRules()`** (private)
  - Calls generators to create new rule sets
  - Updates evaluators with new rules

---

## Integration with City Simulation

### Simulation Iteration Flow

```
1. City Simulation calculates next iteration
     - Updates population, density, economic factors
     - Updates terrain urbanization factors
     - Updates district classifications

2. Simulation marks city state as dirty:
     cityState.markDirty()

3. Simulation passes updated state to RoadGenerator:
     generator.updateCityState(newCityState)
     generator.updateTerrainMap(newTerrainMap)

4. RoadGenerator detects dirty flag and regenerates rules:
     - LocalConstraintGenerator creates new constraint rules
     - GlobalGoalGenerator creates new goal rules
     - Evaluators are updated with new rules

5. RoadGenerator can now generate next stage of city:
     segments = generator.generateRoadNetwork(seedRoad, seedQuery)

6. Simulation receives generated roads and updates infrastructure
```

### Update Triggers

Rules are regenerated when:
- **City state changes** AND `needsRuleRegeneration` is `true`
- **Terrain map is updated**
- **Configuration is changed**

---

## Extensibility Points

### Adding New Rules

#### To add a new local constraint:
1. Create struct conforming to `LocalConstraintRule`
2. Implement `applies(to:)` logic
3. Implement `evaluate(_:context:)` validation logic
4. Add parameters to `RuleConfiguration` if needed
5. Update `LocalConstraintGenerator` to include the rule

#### To add a new global goal:
1. Create struct conforming to `GlobalGoalRule`
2. Implement `applies(to:)` logic
3. Implement `generateProposals(_:_:context:)` logic
4. Add parameters to `RuleConfiguration` if needed
5. Update `GlobalGoalGenerator` to include the rule

### Adding New Attributes

#### To terrain nodes:
1. Add properties to `TerrainNode`
2. Update terrain data population
3. Use in rule logic

#### To city state:
1. Add properties to `CityState`
2. Update simulation to populate values
3. Use in rule generation logic

#### To roads:
1. Add to `RoadAttributes` and/or `QueryAttributes`
2. Update rule logic to consider new attributes
3. Update proposal generation to set new attributes

### Complex Rule Examples

#### Example: Traffic-based road widening
```swift
struct TrafficBasedWidthRule: LocalConstraintRule {
    var priority: Int = 35
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration
    
    func applies(to context: GenerationContext) -> Bool {
        // Check if we have traffic data
        return context.cityState.age > 10
    }
    
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult {
        // Calculate expected traffic
        // Adjust road width based on nearby population density
        // Return adjusted query with modified width
    }
}
```

#### Example: Organic growth from town square
```swift
struct OrganicGrowthRule: GlobalGoalRule {
    var priority: Int = 7
    var applicabilityScope: RuleScope = .district(.oldTown)
    let townSquareLocation: CGPoint
    
    func applies(to context: GenerationContext) -> Bool {
        guard let node = context.terrainMap.getNode(at: context.currentLocation) else {
            return false
        }
        return node.district == .oldTown
    }
    
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext) -> [RoadProposal] {
        // Calculate vector from town square
        // Generate roads that curve around the square
        // Add randomness for organic feel
        // Return proposals with varied angles and lengths
    }
}
```

---

## Performance Considerations

### Complexity
- **Time:** O(n log n) where n is number of generated segments (due to priority queue operations)
- **Space:** O(n) for storing segments and queue

### Optimization Opportunities
1. **Spatial indexing:** For large cities, add quadtree for nearby segment queries
2. **Rule caching:** Cache rule applicability checks if evaluation is expensive
3. **Batch processing:** Process multiple proposals in parallel if order-independent
4. **Terrain lookup optimization:** Pre-compute district boundaries or use spatial hash

### Design Decision: Simplicity over Optimization
Per requirements, the current implementation prioritizes simplicity:
- Direct terrain node lookup (no spatial indexing)
- Real-time rule evaluation (no caching)
- Sequential processing

These can be optimized later if needed without changing the architecture.

---

## Future Enhancement Possibilities

### Rule System
- **Rule composition:** Allow rules to combine or chain
- **Rule weights:** Instead of binary succeed/fail, use weighted scores
- **Dynamic priorities:** Rules adjust their priority based on context
- **Rule conflicts:** Explicit conflict resolution strategies

### City Simulation Integration
- **Event-driven updates:** React to specific city events (new district, economic boom)
- **Incremental generation:** Generate roads progressively as city grows
- **Historical tracking:** Maintain road age and renovation data

### Advanced Features
- **Multi-level roads:** Bridges, tunnels, elevated highways
- **Public transport:** Integration with transit planning
- **Zoning enforcement:** Stricter integration with land use
- **Economic simulation:** Road cost/benefit analysis

---

## Code Organization

```
CityWeaver/
│
├── Packages/Terrain/                    ✅ IMPLEMENTED
│   ├── Package.swift
│   ├── Sources/Terrain/
│   │   ├── Models/
│   │   │   ├── ASCHeader.swift
│   │   │   ├── TerrainNode.swift
│   │   │   ├── TerrainMap.swift
│   │   │   └── DistrictType.swift
│   │   ├── Parser/
│   │   │   └── ASCParser.swift
│   │   ├── Calculator/
│   │   │   └── TerrainCalculator.swift
│   │   ├── Builder/
│   │   │   ├── TerrainMapBuilder.swift
│   │   │   └── OptimizedTerrainMapBuilder.swift
│   │   ├── Validation/
│   │   │   └── DistrictValidator.swift
│   │   └── Serialization/
│   │       └── TerrainMapSerializer.swift
│   └── Tests/TerrainTests/
│       ├── ASCParserTests.swift
│       ├── TerrainCalculatorTests.swift
│       ├── TerrainMapBuilderTests.swift
│       └── DistrictValidatorTests.swift
│
├── App/                                 ✅ IMPLEMENTED (UI)
│   ├── CWApp.swift
│   ├── ContentView.swift
│   └── TerrainEditor/
│       ├── TerrainEditorView.swift
│       ├── TerrainCanvasView.swift
│       ├── DistrictPaletteView.swift
│       ├── DistrictPainter.swift
│       ├── PaintTool.swift
│       ├── TerrainUndoManager.swift
│       └── OptimizedTerrainCanvasView.swift
│
└── Packages/RoadGeneration/             ⏳ TO BE IMPLEMENTED
    ├── Package.swift
    ├── Sources/RoadGeneration/
    │   ├── Core/
    │   │   ├── DataStructures.swift      (CityState, RoadAttributes, etc.)
    │   │   ├── RoadGenerator.swift       (Main algorithm)
    │   │   └── PriorityQueue.swift       (Heap wrapper if needed)
    │   │
    │   ├── Rules/
    │   │   ├── Protocols.swift           (LocalConstraintRule, GlobalGoalRule)
    │   │   ├── RuleConfiguration.swift   (Single source of truth)
    │   │   │
    │   │   ├── LocalConstraints/
    │   │   │   ├── BoundaryConstraintRule.swift
    │   │   │   ├── AngleConstraintRule.swift
    │   │   │   ├── TerrainConstraintRule.swift
    │   │   │   ├── ProximityConstraintRule.swift
    │   │   │   └── DistrictBoundaryRule.swift
    │   │   │
    │   │   └── GlobalGoals/
    │   │       ├── DistrictPatternRule.swift
    │   │       ├── CoastalGrowthRule.swift
    │   │       └── ConnectivityRule.swift
    │   │
    │   ├── Generators/
    │   │   ├── LocalConstraintGenerator.swift
    │   │   └── GlobalGoalGenerator.swift
    │   │
    │   └── Evaluators/
    │       ├── LocalConstraintEvaluator.swift
    │       └── GlobalGoalEvaluator.swift
    │
    └── Tests/RoadGenerationTests/
        └── (to be implemented)
```

---

## Summary

### Current Implementation Status

**✅ Terrain Module (Complete):**
- ASC file loading and parsing
- Terrain property calculations (slope, urbanization factor)
- TerrainMap data structure with district support
- District validation
- JSON serialization/deserialization
- Performance optimizations for large maps (downsampling, async processing)
- Full test coverage
- Interactive UI for terrain editing

**⏳ Road Generation Module (To Be Implemented):**
- Priority queue-based algorithm
- Rule-based constraint and goal system
- Rule generators and evaluators
- City state integration
- Road network output

### Architecture Benefits

This architecture provides:

1. ✅ **Modularity:** Clear separation between terrain management and road generation
2. ✅ **Flexibility:** Easy to add new rules without modifying core algorithm
3. ✅ **Configurability:** Single source of truth for all parameters
4. ✅ **Simulation Integration:** Clean interface for city simulation to update rules
5. ✅ **Extensibility:** Well-defined extension points for future complexity
6. ✅ **Maintainability:** Responsibilities divided into logical components
7. ✅ **Simplicity:** Straightforward implementation without premature optimization
8. ✅ **Testability:** Standalone modules with comprehensive test coverage
9. ✅ **Performance:** Optimized for large datasets with async processing and downsampling

### Getting Started with Terrain Module

The Terrain module is already integrated and ready to use:

```swift
import Terrain

// Load ASC file
let parser = ASCParser()
let (header, heights) = try parser.load(from: ascFileURL)

// Build terrain map (for large files, use OptimizedTerrainMapBuilder)
let builder = TerrainMapBuilder()
let terrainMap = builder.buildTerrainMap(header: header, heights: heights)

// Access terrain data
if let node = terrainMap.getNode(at: x, y: y) {
    print("Elevation: \(node.coordinates.z)")
    print("Slope: \(node.slope)")
    print("Urbanization: \(node.urbanizationFactor)")
    print("District: \(node.district?.rawValue ?? "none")")
}

// Set district (for user input or simulation)
terrainMap.setDistrict(at: x, y: y, district: .residential)

// Validate districts
let validator = DistrictValidator()
let result = validator.validate(terrainMap)
if !result.isValid {
    for error in result.errors {
        print("Validation error: \(error)")
    }
}

// Save/load with districts
let serializer = TerrainMapSerializer()
let jsonData = try serializer.export(terrainMap)
let loadedMap = try serializer.import(from: jsonData)
```

### Next Steps for Road Generation Implementation

1. **Create RoadGeneration Package:**
   - Set up package structure: `Packages/RoadGeneration/`
   - Add `import Terrain` dependency in Package.swift
   - Define core data structures (CityState, RoadAttributes, QueryAttributes, RoadSegment)

2. **Implement Priority Queue:**
   - Heap-based priority queue for RoadQuery
   - Efficient O(log n) insertion and extraction
   - Comparable conformance for RoadQuery based on time

3. **Define Rule Protocols:**
   - `LocalConstraintRule` protocol with evaluate method
   - `GlobalGoalRule` protocol with generateProposals method
   - `RuleScope` enum: .citywide, .district(DistrictType), .segmentSpecific

4. **Implement Configuration System:**
   - `RuleConfiguration` struct with all parameters
   - Centralized configuration management
   - Default values based on realistic city planning

5. **Create Initial Rules:**
   - `BoundaryConstraintRule` - keep roads within bounds
   - `TerrainConstraintRule` - use `terrainMap.getNode()` to check slope/urbanization
   - `DistrictPatternRule` - generate based on `node.district`

6. **Build Core Algorithm:**
   - `RoadGenerator` class with priority queue processing
   - Integration with Terrain module (pass `TerrainMap` to generator)
   - Rule evaluation pipeline (constraints → goals → new queries)

7. **Integration Pattern:**
   ```swift
   let generator = RoadGenerator(
       terrainMap: terrainMap,  // From Terrain module
       cityState: cityState,
       config: config
   )
   let roads = generator.generateRoadNetwork(
       initialRoad: seedRoad,
       initialQuery: seedQuery
   )
   ```

8. **Add Tests:**
   - Unit tests for each rule
   - Integration tests with real TerrainMap data
   - Performance benchmarks on large maps

### Available Sample Data

- `Data/test.asc` - Small 10×10 test file
- `Data/80052_1526701_M-34-51-C-d-4-1.asc` - Real terrain data 2229×2323
- `Data/terrain_map.json` - Example exported terrain with districts

The system successfully balances the need for a simple initial implementation with the ability to evolve into a complex, realistic city generation system. The Terrain module provides a solid foundation for road generation with all necessary terrain data and district information.
