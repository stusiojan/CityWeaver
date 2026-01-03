# Road Generation System Architecture

## Overview

This document describes the architecture of a procedural city road generation system that uses a priority queue-based algorithm with a flexible, rule-based constraint and goal system. The system is designed to integrate with a city growth simulation that dynamically updates road generation rules based on terrain, population, and urban development factors.

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    City Growth Simulation                    │
│         (External - Updates CityState & TerrainMap)         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ├─► CityState (population, density, age)
                     ├─► TerrainMap (1x1m node grid)
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

## Core Components

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
RoadGeneration/
├── Core/
│   ├── DataStructures.swift      (TerrainNode, CityState, RoadAttributes, etc.)
│   ├── RoadGenerator.swift       (Main algorithm)
│   └── PriorityQueue.swift       (Heap wrapper if needed)
│
├── Rules/
│   ├── Protocols.swift           (LocalConstraintRule, GlobalGoalRule)
│   ├── RuleConfiguration.swift  (Single source of truth)
│   │
│   ├── LocalConstraints/
│   │   ├── BoundaryConstraintRule.swift
│   │   ├── AngleConstraintRule.swift
│   │   ├── TerrainConstraintRule.swift
│   │   ├── ProximityConstraintRule.swift
│   │   └── DistrictBoundaryRule.swift
│   │
│   └── GlobalGoals/
│       ├── DistrictPatternRule.swift
│       ├── CoastalGrowthRule.swift
│       └── ConnectivityRule.swift
│
├── Generators/
│   ├── LocalConstraintGenerator.swift
│   └── GlobalGoalGenerator.swift
│
├── Evaluators/
│   ├── LocalConstraintEvaluator.swift
│   └── GlobalGoalEvaluator.swift
│
└── Examples/
    └── Usage.swift
```

---

## Summary

This architecture provides:

1. ✅ **Modularity:** Clear separation between road generation, rule generation, and rule evaluation
2. ✅ **Flexibility:** Easy to add new rules without modifying core algorithm
3. ✅ **Configurability:** Single source of truth for all parameters
4. ✅ **Simulation Integration:** Clean interface for city simulation to update rules
5. ✅ **Extensibility:** Well-defined extension points for future complexity
6. ✅ **Maintainability:** Responsibilities divided into logical components
7. ✅ **Simplicity:** Straightforward implementation without premature optimization

The system successfully balances the need for a simple initial implementation with the ability to evolve into a complex, realistic city generation system.
