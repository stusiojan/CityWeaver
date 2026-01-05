import XCTest
import Terrain
@testable import RoadGeneration

final class GoalRulesTests: XCTestCase {
    
    var config: RuleConfiguration!
    var terrainMap: Terrain.TerrainMap!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        config = RuleConfiguration()
        
        // Create a 10x10 terrain map with mixed districts
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
        
        terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
    }
    
    // MARK: - DistrictPatternRule Tests
    
    @MainActor
    func testDistrictPatternRuleBusinessDistrict() {
        let rule = DistrictPatternRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 6, y: 5),  // In business district
            angle: 0,
            length: 2,
            roadType: "main"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 6, y: 5),
            angle: 0,
            length: 2,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 6, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
        
        // Business districts use grid pattern [0, π/2, -π/2]
        XCTAssertFalse(proposals.isEmpty, "District pattern should generate proposals")
        
        // Check that generated proposals follow grid pattern (angles 0, 90, -90)
        let angles = proposals.map { $0.roadAttributes.angle }
        for angle in angles {
            let normalizedAngle = fmod(angle - roadAttrs.angle + 2 * .pi, 2 * .pi)
            let isGrid = normalizedAngle < 0.1 || 
                         abs(normalizedAngle - .pi/2) < 0.1 || 
                         abs(normalizedAngle - 3 * .pi/2) < 0.1
            XCTAssertTrue(isGrid, "Business district should generate grid-like angles")
        }
    }
    
    @MainActor
    func testDistrictPatternRuleResidentialDistrict() {
        let rule = DistrictPatternRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 2, y: 5),  // In residential district
            angle: 0,
            length: 2,
            roadType: "residential"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 2, y: 5),
            angle: 0,
            length: 2,
            roadType: "residential"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 2, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
        
        XCTAssertFalse(proposals.isEmpty, "Residential district should generate proposals")
        
        // Check that road length is adjusted by multiplier
        for proposal in proposals {
            let lengthRatio = proposal.roadAttributes.length / roadAttrs.length
            let residentialMultiplier = config.roadLengthMultiplier[.residential] ?? 0.8
            XCTAssertEqual(lengthRatio, residentialMultiplier, accuracy: 0.01, 
                          "Road length should be adjusted by district multiplier")
        }
    }
    
    @MainActor
    func testDistrictPatternRuleBranchingProbability() {
        let rule = DistrictPatternRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 6, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 6, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 6, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        // Run multiple times to test probabilistic behavior
        var totalProposals = 0
        let iterations = 100
        for _ in 0..<iterations {
            let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
            totalProposals += proposals.count
        }
        
        let averageProposals = Double(totalProposals) / Double(iterations)
        
        // Business district has 3 possible angles with 0.7 probability each
        // Expected average: 3 * 0.7 = 2.1
        XCTAssertGreaterThan(averageProposals, 1.5, "Should generate some branches on average")
        XCTAssertLessThan(averageProposals, 3.0, "Should not always generate all branches")
    }
    
    // MARK: - CoastalGrowthRule Tests
    
    @MainActor
    func testCoastalGrowthRuleApplies() {
        // Create terrain with coastal district
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<10 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<10 {
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: .park  // No coastal in Terrain.DistrictType
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let header = Terrain.ASCHeader(ncols: 10, nrows: 10, xllcenter: 0, yllcenter: 0, cellsize: 1, nodataValue: -9999)
        let coastalTerrain = Terrain.TerrainMap(header: header, nodes: nodes)
        
        let rule = CoastalGrowthRule(config: config)
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: coastalTerrain,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let applies = rule.applies(to: context)
        
        // With current implementation, isCoastal returns false
        XCTAssertFalse(applies, "Coastal rule should not apply to non-coastal districts")
    }
    
    @MainActor
    func testCoastalGrowthRuleProposals() {
        let rule = CoastalGrowthRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
        
        XCTAssertEqual(proposals.count, 1, "Coastal rule should generate one continuing road")
        
        if let proposal = proposals.first {
            // Road should continue in same direction (along coast)
            XCTAssertEqual(proposal.roadAttributes.angle, roadAttrs.angle, accuracy: 0.01,
                          "Coastal road should continue in same direction")
            
            // Length should be slightly reduced (0.9x)
            XCTAssertEqual(proposal.roadAttributes.length, roadAttrs.length * 0.9, accuracy: 0.01,
                          "Coastal road length should be reduced")
        }
    }
    
    // MARK: - ConnectivityRule Tests
    
    @MainActor
    func testConnectivityRuleAppliesToMainRoads() {
        let rule = ConnectivityRule(config: config)
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 10,
            roadType: "main",
            isMainRoad: true
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let applies = rule.applies(to: context)
        
        XCTAssertTrue(applies, "Connectivity rule should apply to main roads")
    }
    
    @MainActor
    func testConnectivityRuleDoesNotApplyToNonMainRoads() {
        let rule = ConnectivityRule(config: config)
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 10,
            roadType: "residential",
            isMainRoad: false
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let applies = rule.applies(to: context)
        
        XCTAssertFalse(applies, "Connectivity rule should not apply to non-main roads")
    }
    
    @MainActor
    func testConnectivityRuleGeneratesContinuation() {
        let rule = ConnectivityRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 20,
            roadType: "main"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 20,
            roadType: "main",
            isMainRoad: true
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 5, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
        
        XCTAssertEqual(proposals.count, 1, "Connectivity rule should generate one continuing main road")
        
        if let proposal = proposals.first {
            // Should continue straight
            XCTAssertEqual(proposal.roadAttributes.angle, roadAttrs.angle, accuracy: 0.01,
                          "Main road should continue straight")
            
            // Should maintain length
            XCTAssertEqual(proposal.roadAttributes.length, roadAttrs.length, accuracy: 0.01,
                          "Main road should maintain length")
            
            // Should remain a main road
            XCTAssertTrue(proposal.queryAttributes.isMainRoad, "Continuation should remain a main road")
        }
    }
    
    // MARK: - Delay Tests
    
    @MainActor
    func testProposalDelays() {
        let rule = DistrictPatternRule(config: config)
        
        let roadAttrs = RoadAttributes(
            startPoint: CGPoint(x: 6, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let queryAttrs = QueryAttributes(
            startPoint: CGPoint(x: 6, y: 5),
            angle: 0,
            length: 10,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 6, y: 5),
            terrainMap: terrainMap,
            cityState: CityState(population: 10000, density: 1000, economicLevel: 0.5, age: 10),
            existingInfrastructure: [],
            queryAttributes: queryAttrs
        )
        
        let proposals = rule.generateProposals(queryAttrs, roadAttrs, context: context)
        
        // First proposal (straight ahead) should have defaultDelay
        // Branch proposals should have branchDelay
        for (index, proposal) in proposals.enumerated() {
            if index == 0 {
                XCTAssertEqual(proposal.delay, config.defaultDelay, 
                              "First proposal should use default delay")
            } else {
                XCTAssertEqual(proposal.delay, config.branchDelay, 
                              "Branch proposals should use branch delay")
            }
        }
    }
}

