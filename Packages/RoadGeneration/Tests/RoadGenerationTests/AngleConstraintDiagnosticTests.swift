import Testing
import Foundation
import Terrain
@testable import RoadGeneration

@Suite("AngleConstraint Diagnostic Tests")
struct AngleConstraintDiagnosticTests {

    @Test("Straight continuation should not be rejected by angle rule")
    @MainActor
    func straightContinuationAllowed() {
        // Create a flat 200x200 terrain with enough room
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 200)
        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)

        let generator = RoadGenerator(cityState: cityState, terrainMap: terrainMap, config: config)

        let initialRoad = RoadAttributes(startPoint: CGPoint(x: 50, y: 100), angle: 0, length: 20, roadType: "main")
        let initialQuery = QueryAttributes(startPoint: CGPoint(x: 50, y: 100), angle: 0, length: 20, roadType: "main", isMainRoad: true)

        let (segments, report) = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)

        // With the continuation fix, the generation tree should survive past the first few segments.
        // Before the fix, angle=0 continuations were always rejected, killing the tree at 1-3 segments.
        #expect(segments.count > 3, "Continuation fix should allow generation to survive past 3 segments, got \(segments.count). Failures: \(report.failuresByConstraint)")
    }

    @Test("Generation on flat terrain should produce multiple roads")
    @MainActor
    func flatTerrainProducesManyRoads() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 400)
        let cityState = CityState(population: 50_000, density: 3_000, economicLevel: 0.8, age: 10)

        let generator = RoadGenerator(cityState: cityState, terrainMap: terrainMap, config: config)

        let initialRoad = RoadAttributes(startPoint: CGPoint(x: 200, y: 200), angle: 0, length: 30, roadType: "main")
        let initialQuery = QueryAttributes(startPoint: CGPoint(x: 200, y: 200), angle: 0, length: 30, roadType: "main", isMainRoad: true)

        let (segments, report) = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)

        #expect(segments.count > 5, "Large flat terrain should produce more than 5 roads, got \(segments.count). Failures: \(report.failuresByConstraint)")
    }

    @Test("Angle constraint still rejects bad intersections")
    @MainActor
    func badAnglesStillRejected() {
        // Verify that non-continuation roads with bad angles are still rejected
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 100)

        // Place one existing segment
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(startPoint: CGPoint(x: 50, y: 50), angle: 0, length: 10, roadType: "main"),
            createdAt: 0
        )

        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)
        let context = GenerationContext(
            currentLocation: CGPoint(x: 52, y: 50),
            terrainMap: terrainMap,
            cityState: cityState,
            existingInfrastructure: [existingSegment],
            queryAttributes: QueryAttributes(startPoint: CGPoint(x: 52, y: 50), angle: 0.1, length: 10, roadType: "street", isMainRoad: false)
        )

        let rule = AngleConstraintRule(config: config)
        let result = rule.evaluate(
            QueryAttributes(startPoint: CGPoint(x: 52, y: 50), angle: 0.1, length: 10, roadType: "street", isMainRoad: false),
            context: context
        )

        // The angle diff is 0.1 rad (~5.7°) which is < internalRoadAngleMin (30°)
        // AND startPoint (52,50) is NOT at the endpoint (60,50) of the existing segment
        // So this should be rejected
        #expect(result.state == .failed, "Non-continuation road with small angle should be rejected")
    }

    @Test("Sibling roads from same origin should not be rejected by angle rule")
    @MainActor
    func siblingRoadsNotRejectedByAngleRule() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 100)

        // Existing segment starting at (50,50) going right (angle=0)
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(startPoint: CGPoint(x: 50, y: 50), angle: 0, length: 10, roadType: "main"),
            createdAt: 0
        )

        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)

        // Propose a sibling from the same startPoint at a small angle offset
        let proposedQuery = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50), angle: 0.2, length: 10, roadType: "street", isMainRoad: false
        )

        let context = GenerationContext(
            currentLocation: CGPoint(x: 50, y: 50),
            terrainMap: terrainMap,
            cityState: cityState,
            existingInfrastructure: [existingSegment],
            queryAttributes: proposedQuery
        )

        let rule = AngleConstraintRule(config: config)
        let result = rule.evaluate(proposedQuery, context: context)

        #expect(result.state == .succeed, "Sibling roads from the same origin should skip angle check")
    }

    @Test("Non-sibling nearby roads with bad angles should still be rejected")
    @MainActor
    func nonSiblingNearbyRoadsStillChecked() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 100)

        // Existing segment starting at (50,50) going right
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(startPoint: CGPoint(x: 50, y: 50), angle: 0, length: 10, roadType: "main"),
            createdAt: 0
        )

        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)

        // Propose from a DIFFERENT startPoint (52,50) — not a sibling, not a continuation
        let proposedQuery = QueryAttributes(
            startPoint: CGPoint(x: 52, y: 50), angle: 0.1, length: 10, roadType: "street", isMainRoad: false
        )

        let context = GenerationContext(
            currentLocation: CGPoint(x: 52, y: 50),
            terrainMap: terrainMap,
            cityState: cityState,
            existingInfrastructure: [existingSegment],
            queryAttributes: proposedQuery
        )

        let rule = AngleConstraintRule(config: config)
        let result = rule.evaluate(proposedQuery, context: context)

        #expect(result.state == .failed, "Non-sibling nearby roads with small angle diff should still be rejected")
    }

    @Test("Large City preset should produce many roads on flat terrain")
    @MainActor
    func largeCityPresetProducesManyRoads() {
        // Simulate Large City preset: intersectionMinSpacing=40, minimumRoadDistance=12, initialLength=30
        var (terrainMap, config) = TestFixtures.flatTerrainMap(size: 500)
        config.intersectionMinSpacing = 40.0
        config.minimumRoadDistance = 12.0

        let cityState = CityState(population: 200_000, density: 3_000, economicLevel: 0.8, age: 100)
        let generator = RoadGenerator(cityState: cityState, terrainMap: terrainMap, config: config)

        let initialRoad = RoadAttributes(startPoint: CGPoint(x: 250, y: 250), angle: 0, length: 30, roadType: "main")
        let initialQuery = QueryAttributes(startPoint: CGPoint(x: 250, y: 250), angle: 0, length: 30, roadType: "main", isMainRoad: true)

        let (segments, report) = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)

        #expect(segments.count > 20, "Large City preset should produce more than 20 roads on 500x500 terrain, got \(segments.count). Failures: \(report.failuresByConstraint)")
    }

    @Test("Parallel corridor roads should not be rejected by angle rule")
    @MainActor
    func parallelCorridorRoadsAllowed() {
        // Segment A going right, then proposed road C starting 24m further right also going right.
        // They're parallel and offset — paths don't intersect, so angle check should not apply.
        var (terrainMap, config) = TestFixtures.flatTerrainMap(size: 200)
        config.intersectionMinSpacing = 40.0

        // Segment A: (50,50) → (80,50), angle=0, length=30
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(startPoint: CGPoint(x: 50, y: 50), angle: 0, length: 30, roadType: "main"),
            createdAt: 0
        )

        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)

        // Proposed road C: starts at (104,50) going right — same corridor, but paths don't overlap
        let proposedQuery = QueryAttributes(
            startPoint: CGPoint(x: 104, y: 50), angle: 0, length: 20, roadType: "main", isMainRoad: true
        )

        let context = GenerationContext(
            currentLocation: CGPoint(x: 104, y: 50),
            terrainMap: terrainMap,
            cityState: cityState,
            existingInfrastructure: [existingSegment],
            queryAttributes: proposedQuery
        )

        let rule = AngleConstraintRule(config: config)
        let result = rule.evaluate(proposedQuery, context: context)

        // Distance from proposed start (104,50) to existing end (80,50) = 24 < intersectionMinSpacing=40
        // BUT the segment paths don't overlap — min segment distance is 24, which is the gap between them
        // With segment-distance check, this should pass
        #expect(result.state == .succeed, "Parallel roads in the same corridor should not be rejected")
    }

    @Test("Continuation from endpoint should be allowed even with same angle")
    @MainActor
    func continuationFromEndpointAllowed() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 100)

        // Existing segment from (50,50) angle=0 length=10 → endpoint = (60,50)
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(startPoint: CGPoint(x: 50, y: 50), angle: 0, length: 10, roadType: "main"),
            createdAt: 0
        )

        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)
        let context = GenerationContext(
            currentLocation: CGPoint(x: 60, y: 50),
            terrainMap: terrainMap,
            cityState: cityState,
            existingInfrastructure: [existingSegment],
            queryAttributes: QueryAttributes(startPoint: CGPoint(x: 60, y: 50), angle: 0, length: 10, roadType: "main", isMainRoad: false)
        )

        let rule = AngleConstraintRule(config: config)
        let result = rule.evaluate(
            QueryAttributes(startPoint: CGPoint(x: 60, y: 50), angle: 0, length: 10, roadType: "main", isMainRoad: false),
            context: context
        )

        // Start at endpoint of existing → continuation → should pass
        #expect(result.state == .succeed, "Road continuing from endpoint with same angle should be allowed")
    }
}
