import XCTest
import Terrain
@testable import RoadGeneration

final class ConstraintRulesTests: XCTestCase {
    
    var config: RuleConfiguration!
    var terrainMap: Terrain.TerrainMap!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        config = RuleConfiguration()
        
        // Create a simple 10x10 terrain map for testing
        let header = Terrain.ASCHeader(
            ncols: 10,
            nrows: 10,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: 1,
            nodataValue: -9999
        )
        
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<10 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<10 {
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: .residential
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
    }
    
    // MARK: - BoundaryConstraintRule Tests
    
    @MainActor
    func testBoundaryConstraintWithinBounds() {
        let rule = BoundaryConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Road within bounds should succeed")
    }
    
    @MainActor
    func testBoundaryConstraintOutsideBounds() {
        let rule = BoundaryConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 990, y: 500),
            angle: 0,
            length: 50,  // Will extend past x=1000
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 990, y: 500),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .failed, "Road extending outside bounds should fail")
        XCTAssertNotNil(result.reason, "Failed constraint should provide reason")
    }
    
    // MARK: - TerrainConstraintRule Tests
    
    @MainActor
    func testTerrainConstraintGoodSlope() {
        let rule = TerrainConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),  // Valid terrain coordinates
            angle: 0,
            length: 2,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Terrain with acceptable slope should succeed")
    }
    
    @MainActor
    func testTerrainConstraintSteepSlope() {
        // Create terrain with steep slope
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<10 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<10 {
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: 0.8,  // Very steep
                    urbanizationFactor: 0.1,  // Low urbanization
                    district: .residential
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let header = Terrain.ASCHeader(ncols: 10, nrows: 10, xllcenter: 0, yllcenter: 0, cellsize: 1, nodataValue: -9999)
        let steepTerrain = Terrain.TerrainMap(header: header, nodes: nodes)
        
        let rule = TerrainConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 2,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: steepTerrain,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .failed, "Terrain with steep slope should fail")
    }
    
    // MARK: - AngleConstraintRule Tests
    
    @MainActor
    func testAngleConstraintValidAngle() {
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 105, y: 100),  // Close to test point
                angle: .pi / 2,  // 90 degrees
                length: 50,
                roadType: "main"
            ),
            createdAt: 0
        )
        
        let rule = AngleConstraintRule(config: config)
        
        // Propose a road at 90 degrees to existing - should be valid for main roads (60-170°)
        let query = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,  // 0 degrees, so 90° difference
            length: 50,
            roadType: "main",
            isMainRoad: true
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [existingSegment],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Valid intersection angle should succeed")
    }
    
    @MainActor
    func testAngleConstraintInvalidAngle() {
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 105, y: 100),
                angle: 0,  // Same direction
                length: 50,
                roadType: "main"
            ),
            createdAt: 0
        )
        
        let rule = AngleConstraintRule(config: config)
        
        // Propose a road at very small angle - should fail for main roads
        let query = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: .pi / 12,  // 15 degrees - too small
            length: 50,
            roadType: "main",
            isMainRoad: true
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [existingSegment],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .failed, "Invalid intersection angle should fail")
    }
    
    // MARK: - ProximityConstraintRule Tests
    
    @MainActor
    func testProximityConstraintSufficientDistance() {
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 100, y: 100),
                angle: 0,
                length: 50,
                roadType: "main"
            ),
            createdAt: 0
        )
        
        let rule = ProximityConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 200),  // 100m away
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 200),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [existingSegment],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Roads with sufficient distance should succeed")
    }
    
    @MainActor
    func testProximityConstraintTooClose() {
        let existingSegment = RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 100, y: 100),
                angle: 0,
                length: 50,
                roadType: "main"
            ),
            createdAt: 0
        )
        
        let rule = ProximityConstraintRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 105),  // Only 5m away
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 105),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [existingSegment],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .failed, "Roads too close should fail")
    }
    
    // MARK: - DistrictBoundaryRule Tests
    
    @MainActor
    func testDistrictBoundarySameDistrict() {
        let rule = DistrictBoundaryRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 2,  // Ends at (7, 5), same district
            roadType: "residential"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Roads within same district should succeed")
    }
    
    @MainActor
    func testDistrictBoundaryMainRoadCanCross() {
        // Create terrain with different districts
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<10 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<10 {
                let district: Terrain.DistrictType = x < 5 ? .residential : .business
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: district
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let header = Terrain.ASCHeader(ncols: 10, nrows: 10, xllcenter: 0, yllcenter: 0, cellsize: 1, nodataValue: -9999)
        let mixedTerrain = Terrain.TerrainMap(header: header, nodes: nodes)
        
        let rule = DistrictBoundaryRule(config: config)
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 4, y: 5),
            angle: 0,
            length: 3,  // Crosses district boundary to x=7
            roadType: "main",
            isMainRoad: true  // Main roads can cross
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 4, y: 5),
            terrainMap: mixedTerrain,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: query
        )
        
        let result = rule.evaluate(query, context: context)
        
        XCTAssertEqual(result.state, .succeed, "Main roads should be able to cross district boundaries")
    }
}

