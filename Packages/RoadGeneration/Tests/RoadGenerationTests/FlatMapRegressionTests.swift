import Testing
import Foundation
import Terrain
@testable import RoadGeneration

@Suite("Flat Map Regression Tests")
struct FlatMapRegressionTests {

    @Test("Flat map guarantees at least one road is generated")
    @MainActor
    func flatMapGeneratesRoads() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 100)
        let cityState = CityState(population: 10_000, density: 1_500, economicLevel: 0.6, age: 10)

        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )

        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 10,
            roadType: "main",
            isMainRoad: true
        )

        let (segments, report) = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )

        #expect(segments.count > 0, "Flat terrain should always produce roads")
        #expect(report.totalAccepted > 0)
        #expect(report.totalProposalsEvaluated > 0)
    }

    @Test("Generation report contains sensible statistics")
    @MainActor
    func reportHasSensibleStats() {
        let (terrainMap, config) = TestFixtures.flatTerrainMap(size: 50)
        let cityState = CityState(population: 5_000, density: 1_000, economicLevel: 0.5, age: 5)

        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )

        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 25, y: 25),
            angle: 0,
            length: 5,
            roadType: "main"
        )
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 25, y: 25),
            angle: 0,
            length: 5,
            roadType: "main",
            isMainRoad: true
        )

        let (segments, report) = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )

        #expect(report.totalAccepted == segments.count)
        #expect(report.totalFailed == report.totalProposalsEvaluated - report.totalAccepted)
        #expect(report.processingTimeSeconds >= 0)
        #expect(!report.diagnosticMessage.isEmpty)
    }
}
