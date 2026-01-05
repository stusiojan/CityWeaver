import Collections
import CoreGraphics
import Foundation
import Terrain

// MARK: - Core Data Structures

/// Result state from local constraint validation
enum ConstraintState {
    case succeed
    case failed
}

// Using DistrictType from Terrain package
// Note: Terrain.DistrictType has: business, oldTown, residential, industrial, park
// We extend it here to add mappings for RGA-specific types
extension Terrain.DistrictType {
    /// Map to RGA district patterns (coastal and undefined map to existing types)
    var rgaPattern: Terrain.DistrictType {
        return self
    }

    /// Check if this is a coastal-like district
    var isCoastal: Bool {
        // In future, this could be determined by proximity to water
        return false
    }
}

/// Scope of rule application
enum RuleScope {
    case citywide
    case district(Terrain.DistrictType)
    case segmentSpecific
}

/// Result from constraint evaluation with optional adjustments
struct ConstraintResult {
    let state: ConstraintState
    let adjustedQuery: QueryAttributes
    let reason: String?

    init(state: ConstraintState, adjustedQuery: QueryAttributes, reason: String? = nil) {
        self.state = state
        self.adjustedQuery = adjustedQuery
        self.reason = reason
    }
}

/// Proposal for a new road segment
struct RoadProposal {
    let roadAttributes: RoadAttributes
    let queryAttributes: QueryAttributes
    let delay: Int
}

/// Geometric properties of a road segment
/// Additional attributes like width, surface type, or elevation could be added here
public struct RoadAttributes: Codable, Sendable {
    /// Starting point of the road segment
    public let startPoint: CGPoint
    /// Direction angle in radians
    public let angle: Double
    /// Length of the road segment
    public let length: Double
    /// Type of road (highway, residential, etc.)
    public let roadType: String

    public init(startPoint: CGPoint, angle: Double, length: Double, roadType: String) {
        self.startPoint = startPoint
        self.angle = angle
        self.length = length
        self.roadType = roadType
    }

    /// Additional properties that could be added:
    /// - width: Double
    /// - surfaceType: RoadSurfaceType
    /// - elevation: Double
    /// - speedLimit: Int
    /// - lanes: Int
}

/// Data associated with a road building request
/// Similar to RoadAttributes but represents a proposal rather than final geometry
/// Additional validation data or metadata could be added here
public struct QueryAttributes {
    /// Starting point of the proposed road
    public let startPoint: CGPoint
    /// Direction angle in radians
    public let angle: Double
    /// Proposed length of the road segment
    public let length: Double
    /// Type of road being proposed
    public let roadType: String
    /// Whether this is a main road in the district
    public let isMainRoad: Bool

    /// Additional properties that could be added:
    /// - priority: Int
    /// - requesterType: RoadRequesterType
    /// - buildCost: Double
    /// - environmentalImpact: Double
    /// - populationDensityRequirement: Double

    public init(
        startPoint: CGPoint, angle: Double, length: Double, roadType: String,
        isMainRoad: Bool = false
    ) {
        self.startPoint = startPoint
        self.angle = angle
        self.length = length
        self.roadType = roadType
        self.isMainRoad = isMainRoad
    }
}

/// A proposal to create a new road segment in the priority queue
/// Additional metadata like creation timestamp or source could be added
struct RoadQuery: Comparable {
    /// Priority timestamp - lower values processed first
    let time: Int
    /// Final geometric properties of the proposed road
    let roadAttributes: RoadAttributes
    /// Query data for validation
    let queryAttributes: QueryAttributes

    /// Additional properties that could be added:
    /// - sourceSegmentId: UUID?
    /// - generationReason: String
    /// - estimatedBuildTime: TimeInterval

    static func < (lhs: RoadQuery, rhs: RoadQuery) -> Bool {
        return lhs.time < rhs.time
    }

    static func == (lhs: RoadQuery, rhs: RoadQuery) -> Bool {
        return lhs.time == rhs.time
    }
}

/// A confirmed, immutable road segment that has passed all validation
/// Additional metadata like construction date or usage statistics could be added
public struct RoadSegment: Codable, Sendable {
    /// Unique identifier for the segment
    public let id: UUID
    /// Final geometric properties
    public let attributes: RoadAttributes
    /// Timestamp when segment was created
    public let createdAt: Int

    /// Additional properties that could be added:
    /// - trafficFlow: Double
    /// - maintenanceSchedule: [Date]
    /// - connectedSegments: Set<UUID>
    /// - buildCost: Double

    public init(attributes: RoadAttributes, createdAt: Int) {
        self.id = UUID()
        self.attributes = attributes
        self.createdAt = createdAt
    }
}

// MARK: - Terrain System
// Using Terrain package - TerrainMap and TerrainNode from Terrain module

// MARK: - City State

/// Current state of the city simulation
/// Additional city-wide metrics could be added here
public struct CityState {
    /// Total population
    public var population: Int
    /// Population per square kilometer
    public var density: Double
    /// Economic development level (0-1)
    public var economicLevel: Double
    /// City age in simulation years
    public var age: Int

    /// Additional properties that could be added:
    /// - gdp: Double
    /// - trafficCongestion: Double
    /// - pollutionLevel: Double
    /// - housingDemand: Double
    /// - employmentRate: Double

    /// Flag indicating if rules need regeneration
    public var needsRuleRegeneration: Bool = true

    /// Marks that rules should be regenerated on next iteration
    public mutating func markDirty() {
        needsRuleRegeneration = true
    }

    public init(population: Int, density: Double, economicLevel: Double, age: Int) {
        self.population = population
        self.density = density
        self.economicLevel = economicLevel
        self.age = age
    }
}

/// Context for road generation containing all necessary state
/// Additional contextual information could be added here
struct GenerationContext {
    /// Current location being evaluated
    let currentLocation: CGPoint
    /// Terrain data
    let terrainMap: Terrain.TerrainMap
    /// Current city state
    let cityState: CityState
    /// Already generated road segments
    let existingInfrastructure: [RoadSegment]
    /// The query being evaluated
    let queryAttributes: QueryAttributes

    /// Additional properties that could be added:
    /// - timeOfDay: TimeInterval
    /// - season: Season
    /// - weatherConditions: Weather
    /// - nearbyBuildings: [Building]
}

// MARK: - Rule Configuration

/// Central configuration for all rule parameters - single source of truth
/// All rule-related parameters should be defined here
public struct RuleConfiguration {
    // Boundary constraints
    public var cityBounds: CGRect = CGRect(
        origin: CGPoint(x: 0, y: 0), size: CGSize(width: 1000, height: 1000))
    //    var cityBounds: CGRect = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    // Angle constraints (in radians)
    public var mainRoadAngleMin: Double = 60 * .pi / 180
    public var mainRoadAngleMax: Double = 170 * .pi / 180
    public var internalRoadAngleMin: Double = 30 * .pi / 180
    public var internalRoadAngleMax: Double = 180 * .pi / 180

    // Distance constraints
    public var minimumRoadDistance: Double = 10.0
    public var intersectionMinSpacing: Double = 50.0

    // Terrain constraints
    public var maxBuildableSlope: Double = 0.3
    public var minUrbanizationFactor: Double = 0.2

    // Global goal parameters
    public var branchingProbability: [Terrain.DistrictType: Double] = [
        .business: 0.7,
        .oldTown: 0.9,
        .residential: 0.6,
        .industrial: 0.5,
        .park: 0.3,
    ]

    public var roadLengthMultiplier: [Terrain.DistrictType: Double] = [
        .business: 1.0,
        .oldTown: 0.6,
        .residential: 0.8,
        .industrial: 1.2,
        .park: 0.5,
    ]

    public var branchingAngles: [Terrain.DistrictType: [Double]] = [
        .business: [0, .pi / 2, -.pi / 2],  // Grid pattern
        .oldTown: [0, .pi / 6, -.pi / 6, .pi / 4, -.pi / 4],  // Organic
        .residential: [0, .pi / 3, -.pi / 3],
        .industrial: [0, .pi / 2, -.pi / 2],
        .park: [0, .pi / 4, -.pi / 4],
    ]

    // Coastal development
    public var coastalGrowthBias: Double = 0.8

    // Delays
    public var defaultDelay: Int = 1
    public var branchDelay: Int = 3

    public init() {}

    /// Additional parameters that could be added:
    /// - zoneDensityFactors: [DistrictType: Double]
    /// - roadWidths: [String: Double]
    /// - trafficFlowParameters: TrafficConfig
    /// - seasonalModifiers: SeasonalConfig
}

// MARK: - Rule Protocols

/// Protocol for local constraint rules that validate road proposals
@MainActor
protocol LocalConstraintRule {
    /// Priority for rule evaluation (lower = higher priority)
    var priority: Int { get }
    /// Scope of applicability
    var applicabilityScope: RuleScope { get }
    /// Configuration reference
    var config: RuleConfiguration { get set }

    /// Check if rule applies to given context
    func applies(to context: GenerationContext) -> Bool

    /// Evaluate the constraint
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
}

/// Protocol for global goal rules that generate new road proposals
@MainActor
protocol GlobalGoalRule {
    /// Priority for rule evaluation (lower = higher priority)
    var priority: Int { get }
    /// Scope of applicability
    var applicabilityScope: RuleScope { get }
    /// Configuration reference
    var config: RuleConfiguration { get set }

    /// Check if rule applies to given context
    func applies(to context: GenerationContext) -> Bool

    /// Generate new road proposals
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
}

// MARK: - Local Constraint Rules Implementation

/// Validates that roads stay within city boundaries
struct BoundaryConstraintRule: LocalConstraintRule {
    var priority: Int = 10
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true  // Always applies
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let endPoint = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        if !config.cityBounds.contains(qa.startPoint) || !config.cityBounds.contains(endPoint) {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Outside city bounds")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}

/// Validates intersection angles based on road type
struct AngleConstraintRule: LocalConstraintRule {
    var priority: Int = 20
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return !context.existingInfrastructure.isEmpty
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let minAngle = qa.isMainRoad ? config.mainRoadAngleMin : config.internalRoadAngleMin
        let maxAngle = qa.isMainRoad ? config.mainRoadAngleMax : config.internalRoadAngleMax

        // Check angles with nearby existing roads
        for segment in context.existingInfrastructure {
            let distance = sqrt(
                pow(segment.attributes.startPoint.x - qa.startPoint.x, 2)
                    + pow(segment.attributes.startPoint.y - qa.startPoint.y, 2)
            )

            if distance < config.intersectionMinSpacing {
                let angleDiff = abs(qa.angle - segment.attributes.angle)
                let normalizedAngle = min(angleDiff, 2 * .pi - angleDiff)

                if normalizedAngle < minAngle || normalizedAngle > maxAngle {
                    return ConstraintResult(
                        state: .failed, adjustedQuery: qa, reason: "Invalid intersection angle")
                }
            }
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}

/// Validates terrain suitability
struct TerrainConstraintRule: LocalConstraintRule {
    var priority: Int = 15
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let worldCoords = (x: Double(qa.startPoint.x), y: Double(qa.startPoint.y))
        guard let node = context.terrainMap.getNode(at: worldCoords) else {
            return ConstraintResult(state: .failed, adjustedQuery: qa, reason: "No terrain data")
        }

        if node.slope > config.maxBuildableSlope {
            return ConstraintResult(state: .failed, adjustedQuery: qa, reason: "Slope too steep")
        }

        if node.urbanizationFactor < config.minUrbanizationFactor {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Low urbanization factor")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}

/// Prevents roads from being too close to each other
struct ProximityConstraintRule: LocalConstraintRule {
    var priority: Int = 25
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return !context.existingInfrastructure.isEmpty
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let proposedEnd = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        for segment in context.existingInfrastructure {
            let existingEnd = CGPoint(
                x: segment.attributes.startPoint.x + cos(segment.attributes.angle)
                    * segment.attributes.length,
                y: segment.attributes.startPoint.y + sin(segment.attributes.angle)
                    * segment.attributes.length
            )

            let distance = sqrt(
                pow(proposedEnd.x - existingEnd.x, 2) + pow(proposedEnd.y - existingEnd.y, 2)
            )

            if distance < config.minimumRoadDistance {
                return ConstraintResult(
                    state: .failed, adjustedQuery: qa, reason: "Too close to existing road")
            }
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}

/// Handles district boundary transitions
struct DistrictBoundaryRule: LocalConstraintRule {
    var priority: Int = 30
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let startWorldCoords = (x: Double(qa.startPoint.x), y: Double(qa.startPoint.y))
        guard let startNode = context.terrainMap.getNode(at: startWorldCoords) else {
            return ConstraintResult(state: .succeed, adjustedQuery: qa)
        }

        let endPoint = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        let endWorldCoords = (x: Double(endPoint.x), y: Double(endPoint.y))
        guard let endNode = context.terrainMap.getNode(at: endWorldCoords) else {
            return ConstraintResult(state: .succeed, adjustedQuery: qa)
        }

        // Hard transition - roads cannot cross district boundaries (except main roads)
        if startNode.district != endNode.district && !qa.isMainRoad {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Cannot cross district boundary")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}

// MARK: - Global Goal Rules Implementation

/// Generates roads based on district-specific patterns
struct DistrictPatternRule: GlobalGoalRule {
    var priority: Int = 10
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        let worldCoords = (x: Double(ra.startPoint.x), y: Double(ra.startPoint.y))
        guard let node = context.terrainMap.getNode(at: worldCoords) else {
            return []
        }

        let district = node.district ?? .residential  // Default to residential if no district set
        let probability = config.branchingProbability[district] ?? 0.5
        let lengthMultiplier = config.roadLengthMultiplier[district] ?? 0.8
        let angles = config.branchingAngles[district] ?? [0, .pi / 4, -.pi / 4]

        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        for (index, angleOffset) in angles.enumerated() {
            if Double.random(in: 0...1) > probability {
                continue
            }

            let newAngle = ra.angle + angleOffset
            let newLength = ra.length * lengthMultiplier

            let newRoadAttributes = RoadAttributes(
                startPoint: endPoint,
                angle: newAngle,
                length: newLength,
                roadType: ra.roadType
            )

            let newQueryAttributes = QueryAttributes(
                startPoint: endPoint,
                angle: newAngle,
                length: newLength,
                roadType: ra.roadType,
                isMainRoad: qa.isMainRoad
            )

            let delay = index == 0 ? config.defaultDelay : config.branchDelay

            proposals.append(
                RoadProposal(
                    roadAttributes: newRoadAttributes,
                    queryAttributes: newQueryAttributes,
                    delay: delay
                ))
        }

        return proposals
    }
}

/// Biases road growth along coastlines or rivers
struct CoastalGrowthRule: GlobalGoalRule {
    var priority: Int = 5
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        // Check if we're near coastal area (using extension property)
        let worldCoords = (
            x: Double(context.currentLocation.x), y: Double(context.currentLocation.y)
        )
        guard let node = context.terrainMap.getNode(at: worldCoords) else {
            return false
        }
        return node.district?.isCoastal ?? false
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        // Bias growth to follow coastline (simplified - would need actual coastline data)
        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        // Generate road that continues along coast
        let newRoadAttributes = RoadAttributes(
            startPoint: endPoint,
            angle: ra.angle,  // Keep same direction along coast
            length: ra.length * 0.9,
            roadType: ra.roadType
        )

        let newQueryAttributes = QueryAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length * 0.9,
            roadType: ra.roadType,
            isMainRoad: qa.isMainRoad
        )

        proposals.append(
            RoadProposal(
                roadAttributes: newRoadAttributes,
                queryAttributes: newQueryAttributes,
                delay: config.defaultDelay
            ))

        return proposals
    }
}

/// Connects districts with main roads
struct ConnectivityRule: GlobalGoalRule {
    var priority: Int = 8
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return context.queryAttributes.isMainRoad
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        // Simplified - would need actual district center calculations
        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        // Main roads continue straight and branch less frequently
        let newRoadAttributes = RoadAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length,
            roadType: ra.roadType
        )

        let newQueryAttributes = QueryAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length,
            roadType: ra.roadType,
            isMainRoad: true
        )

        proposals.append(
            RoadProposal(
                roadAttributes: newRoadAttributes,
                queryAttributes: newQueryAttributes,
                delay: config.defaultDelay
            ))

        return proposals
    }
}

// MARK: - Rule Generators

/// Generates local constraint rules from city state and terrain
@MainActor
class LocalConstraintGenerator {
    /// Generates rules based on current city state
    /// - Parameters:
    ///   - cityState: Current state of the city
    ///   - terrainMap: Terrain data
    ///   - config: Rule configuration
    /// - Returns: Array of local constraint rules
    func generateRules(
        from cityState: CityState, terrainMap: Terrain.TerrainMap, config: RuleConfiguration
    ) -> [LocalConstraintRule] {
        var rules: [LocalConstraintRule] = []

        // Always include boundary constraint
        rules.append(BoundaryConstraintRule(config: config))

        // Add terrain constraint
        rules.append(TerrainConstraintRule(config: config))

        // Add proximity constraint
        rules.append(ProximityConstraintRule(config: config))

        // Add angle constraint for mature cities
        if cityState.age > 0 {
            rules.append(AngleConstraintRule(config: config))
        }

        // Add district boundary rule
        rules.append(DistrictBoundaryRule(config: config))

        // Sort by priority
        return rules.sorted { $0.priority < $1.priority }
    }
}

/// Generates global goal rules from city state and terrain
@MainActor
class GlobalGoalGenerator {
    /// Generates rules based on current city state
    /// - Parameters:
    ///   - cityState: Current state of the city
    ///   - terrainMap: Terrain data
    ///   - config: Rule configuration
    /// - Returns: Array of global goal rules
    func generateRules(
        from cityState: CityState, terrainMap: Terrain.TerrainMap, config: RuleConfiguration
    ) -> [GlobalGoalRule] {
        var rules: [GlobalGoalRule] = []

        // Always include district pattern rule
        rules.append(DistrictPatternRule(config: config))

        // Add coastal growth if city is near water
        rules.append(CoastalGrowthRule(config: config))

        // Add connectivity rule for established cities
        if cityState.age > 5 {
            rules.append(ConnectivityRule(config: config))
        }

        // Sort by priority
        return rules.sorted { $0.priority < $1.priority }
    }
}

// MARK: - Rule Evaluators

/// Evaluates local constraints using rule collection
@MainActor
class LocalConstraintEvaluator {
    private var rules: [LocalConstraintRule]

    init(rules: [LocalConstraintRule]) {
        self.rules = rules
    }

    /// Updates the rule set
    func updateRules(_ newRules: [LocalConstraintRule]) {
        self.rules = newRules.sorted { $0.priority < $1.priority }
    }

    /// Evaluates all applicable rules
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> (
        QueryAttributes, ConstraintState
    ) {
        var currentQuery = qa

        for rule in rules {
            if rule.applies(to: context) {
                let result = rule.evaluate(currentQuery, context: context)

                if result.state == .failed {
                    return (result.adjustedQuery, .failed)
                }

                currentQuery = result.adjustedQuery
            }
        }

        return (currentQuery, .succeed)
    }
}

/// Evaluates global goals using rule collection
@MainActor
class GlobalGoalEvaluator {
    private var rules: [GlobalGoalRule]

    init(rules: [GlobalGoalRule]) {
        self.rules = rules
    }

    /// Updates the rule set
    func updateRules(_ newRules: [GlobalGoalRule]) {
        self.rules = newRules.sorted { $0.priority < $1.priority }
    }

    /// Generates proposals from all applicable rules
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        var allProposals: [RoadProposal] = []

        for rule in rules {
            if rule.applies(to: context) {
                let proposals = rule.generateProposals(qa, ra, context: context)
                allProposals.append(contentsOf: proposals)
            }
        }

        return allProposals
    }
}

// MARK: - Main Road Generator

/// Main road generation algorithm implementation with rule-based system
@MainActor
public final class RoadGenerator {
    /// Priority queue of road proposals to be processed
    private var queue: Heap<RoadQuery>
    /// List of successfully placed road segments
    private var segments: [RoadSegment]

    /// Current city state
    private var cityState: CityState
    /// Terrain data
    private var terrainMap: Terrain.TerrainMap
    /// Rule configuration
    private var config: RuleConfiguration

    /// Rule generators
    private let constraintGenerator: LocalConstraintGenerator
    private let goalGenerator: GlobalGoalGenerator

    /// Rule evaluators
    private var constraintEvaluator: LocalConstraintEvaluator
    private var goalEvaluator: GlobalGoalEvaluator

    public init(cityState: CityState, terrainMap: Terrain.TerrainMap, config: RuleConfiguration) {
        self.queue = Heap<RoadQuery>()
        self.segments = []
        self.cityState = cityState
        self.terrainMap = terrainMap
        self.config = config

        self.constraintGenerator = LocalConstraintGenerator()
        self.goalGenerator = GlobalGoalGenerator()

        // Generate initial rules
        let constraintRules = constraintGenerator.generateRules(
            from: cityState, terrainMap: terrainMap, config: config)
        let goalRules = goalGenerator.generateRules(
            from: cityState, terrainMap: terrainMap, config: config)

        self.constraintEvaluator = LocalConstraintEvaluator(rules: constraintRules)
        self.goalEvaluator = GlobalGoalEvaluator(rules: goalRules)
    }

    /// Updates city state and regenerates rules if needed
    /// - Parameter newCityState: Updated city state from simulation
    public func updateCityState(_ newCityState: CityState) {
        self.cityState = newCityState

        if newCityState.needsRuleRegeneration {
            regenerateRules()
            var mutableState = newCityState
            mutableState.needsRuleRegeneration = false
            self.cityState = mutableState
        }
    }

    /// Updates terrain map
    /// - Parameter newTerrainMap: Updated terrain data
    public func updateTerrainMap(_ newTerrainMap: Terrain.TerrainMap) {
        self.terrainMap = newTerrainMap
        regenerateRules()
    }

    /// Updates rule configuration
    /// - Parameter newConfig: Updated configuration
    public func updateConfiguration(_ newConfig: RuleConfiguration) {
        self.config = newConfig
        regenerateRules()
    }

    /// Regenerates all rules based on current state
    private func regenerateRules() {
        let constraintRules = constraintGenerator.generateRules(
            from: cityState, terrainMap: terrainMap, config: config)
        let goalRules = goalGenerator.generateRules(
            from: cityState, terrainMap: terrainMap, config: config)

        constraintEvaluator.updateRules(constraintRules)
        goalEvaluator.updateRules(goalRules)
    }

    /// Main algorithm entry point - generates road network from initial seed
    /// - Parameters:
    ///   - initialRoad: Starting road attributes for the generation process
    ///   - initialQuery: Starting query attributes for validation
    /// - Returns: Array of generated road segments forming the final network
    public func generateRoadNetwork(initialRoad: RoadAttributes, initialQuery: QueryAttributes)
        -> [RoadSegment]
    {
        // Initialize priority queue with single entry
        let initialRoadQuery = RoadQuery(
            time: 0,
            roadAttributes: initialRoad,
            queryAttributes: initialQuery
        )
        queue.insert(initialRoadQuery)

        // Process queue until empty
        while !queue.isEmpty {
            let currentQuery = queue.removeMin()

            // Create context for evaluation
            let context = GenerationContext(
                currentLocation: currentQuery.queryAttributes.startPoint,
                terrainMap: terrainMap,
                cityState: cityState,
                existingInfrastructure: segments,
                queryAttributes: currentQuery.queryAttributes
            )

            // Validate the proposed road segment
            let (adjustedQuery, state) = constraintEvaluator.evaluate(
                currentQuery.queryAttributes, context: context)

            if state == .succeed {
                // Create and add successful segment
                let newSegment = RoadSegment(
                    attributes: currentQuery.roadAttributes,
                    createdAt: currentQuery.time
                )
                segments.append(newSegment)

                // Generate new road proposals based on global goals
                let proposals = goalEvaluator.generateProposals(
                    adjustedQuery,
                    currentQuery.roadAttributes,
                    context: context
                )

                // Add proposals to queue
                for proposal in proposals {
                    let newQuery = RoadQuery(
                        time: currentQuery.time + proposal.delay,
                        roadAttributes: proposal.roadAttributes,
                        queryAttributes: proposal.queryAttributes
                    )
                    queue.insert(newQuery)
                }
            }
            // If state == .failed, simply discard the proposal
        }

        return segments
    }

    /// Gets the current list of generated segments
    /// - Returns: Array of all successfully placed road segments
    public func getSegments() -> [RoadSegment] {
        return segments
    }

    /// Gets the current size of the processing queue
    /// - Returns: Number of pending road proposals
    public func getQueueSize() -> Int {
        return queue.count
    }

    /// Clears all generated segments and queue for fresh generation
    public func reset() {
        segments.removeAll()
        queue = Heap<RoadQuery>()
    }
}

// MARK: - Usage Example

/// Example usage of the road generation algorithm with rule-based system
@MainActor
public func exampleUsage() -> [RoadSegment] {
    // Create a simple terrain map for testing
    let header = Terrain.ASCHeader(
        ncols: 1000,
        nrows: 1000,
        xllcenter: 0,
        yllcenter: 0,
        cellsize: 1,
        nodataValue: -9999
    )

    // Create nodes grid
    var nodes: [[Terrain.TerrainNode]] = []
    for y in 0..<1000 {
        var row: [Terrain.TerrainNode] = []
        for x in 0..<1000 {
            let node = Terrain.TerrainNode(
                coordinates: Terrain.TerrainNode.Coordinates(
                    x: Double(x),
                    y: Double(y),
                    z: Double.random(in: 0...10)
                ),
                slope: Double.random(in: 0...0.5),
                urbanizationFactor: Double.random(in: 0.3...1.0),
                district: .residential
            )
            row.append(node)
        }
        nodes.append(row)
    }

    let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)

    // Setup initial city state
    var cityState = CityState(
        population: 10000,
        density: 1500,
        economicLevel: 0.6,
        age: 0
    )

    // Setup rule configuration
    var config = RuleConfiguration()

    // Create generator
    let generator = RoadGenerator(
        cityState: cityState,
        terrainMap: terrainMap,
        config: config
    )

    // Create initial road segment (town center)
    let initialRoad = RoadAttributes(
        startPoint: CGPoint(x: 500, y: 500),
        angle: 0,
        length: 100,
        roadType: "main"
    )

    let initialQuery = QueryAttributes(
        startPoint: CGPoint(x: 500, y: 500),
        angle: 0,
        length: 100,
        roadType: "main",
        isMainRoad: true
    )

    // Generate the initial road network
    print("Generating initial city...")
    let roadNetwork = generator.generateRoadNetwork(
        initialRoad: initialRoad,
        initialQuery: initialQuery
    )

    print("Generated \(roadNetwork.count) road segments")

    // Simulate city growth iteration
    cityState.population = 15000
    cityState.density = 2000
    cityState.age = 1
    cityState.markDirty()

    // Update generator with new city state
    generator.updateCityState(cityState)

    // Generate next iteration (would start with new initial roads at city edge)
    print("\nSimulating city growth iteration...")

    // Print some statistics
    print("Final road count: \(generator.getSegments().count)")
    print("Queue size: \(generator.getQueueSize())")

    return generator.getSegments()
}
