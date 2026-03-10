import Collections
import CoreGraphics
import Foundation
import Shared
import Terrain

/// Main road generation algorithm implementation with rule-based system
@MainActor
public final class RoadGenerator {
    private let logger = CWLogger(subsystem: "RoadGeneration")

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
    /// - Returns: Tuple of generated road segments and a diagnostic report
    public func generateRoadNetwork(initialRoad: RoadAttributes, initialQuery: QueryAttributes)
        -> (segments: [RoadSegment], report: GenerationReport)
    {
        let startTime = Date()
        var evaluated = 0
        var accepted = 0
        var failures: [String: Int] = [:]

        // Initialize priority queue with single entry
        let initialRoadQuery = RoadQuery(
            time: 0,
            roadAttributes: initialRoad,
            queryAttributes: initialQuery
        )
        queue.insert(initialRoadQuery)

        logger.info("Generation started — queue seeded at (\(initialRoad.startPoint.x), \(initialRoad.startPoint.y)), angle=\(initialRoad.angle), length=\(initialRoad.length)")

        // Process queue until empty
        while !queue.isEmpty {
            let currentQuery = queue.removeMin()
            evaluated += 1

            // Create context for evaluation
            let context = GenerationContext(
                currentLocation: currentQuery.queryAttributes.startPoint,
                terrainMap: terrainMap,
                cityState: cityState,
                existingInfrastructure: segments,
                queryAttributes: currentQuery.queryAttributes
            )

            // Validate the proposed road segment
            let (adjustedQuery, state, failureReason) = constraintEvaluator.evaluate(
                currentQuery.queryAttributes, context: context)

            if state == .succeed {
                accepted += 1

                // Create and add successful segment
                let newSegment = RoadSegment(
                    attributes: currentQuery.roadAttributes,
                    createdAt: currentQuery.time
                )
                segments.append(newSegment)

                logger.debug("Accepted segment #\(accepted) at (\(currentQuery.roadAttributes.startPoint.x), \(currentQuery.roadAttributes.startPoint.y))")

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
            } else {
                let reason = failureReason ?? "Unknown"
                failures[reason, default: 0] += 1
                logger.constraint("Rejected: \(reason) at (\(currentQuery.queryAttributes.startPoint.x), \(currentQuery.queryAttributes.startPoint.y))")
            }
        }

        let processingTime = Date().timeIntervalSince(startTime)
        let report = GenerationReport.build(
            evaluated: evaluated,
            accepted: accepted,
            failures: failures,
            processingTime: processingTime
        )

        logger.info("Generation finished — \(report.diagnosticMessage)")
        if !report.suggestedFixes.isEmpty {
            logger.info("Suggested fixes: \(report.suggestedFixes.joined(separator: "; "))")
        }

        return (segments, report)
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
