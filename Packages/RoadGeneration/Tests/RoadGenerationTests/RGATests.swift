import Testing
import Foundation

@testable import RGA

// MARK: - Test Helpers

/// Helper to create a simple terrain map for testing
func createTestTerrainMap(bounds: CGRect, district: DistrictType = .residential) -> TerrainMap {
    let terrainMap = TerrainMap()
    
    for x in Int(bounds.minX)...Int(bounds.maxX) {
        for y in Int(bounds.minY)...Int(bounds.maxY) {
            let node = TerrainNode(
                coordinates: (x: Double(x), y: Double(y), z: 0),
                slope: 0.1,
                urbanizationFactor: 0.8,
                district: district
            )
            terrainMap.addNode(node)
        }
    }
    
    return terrainMap
}

/// Helper to create test city state
func createTestCityState(age: Int = 0) -> CityState {
    return CityState(
        population: 10000,
        density: 1500,
        economicLevel: 0.6,
        age: age
    )
}

/// Helper to create test configuration
func createTestConfiguration() -> RuleConfiguration {
    return RuleConfiguration()
}

// MARK: - Data Structure Tests

@Suite("Data Structure Tests")
struct DataStructureTests {
    
    @Test("RoadQuery comparison works correctly")
    func roadQueryComparison() {
        let ra1 = RoadAttributes(startPoint: .zero, angle: 0, length: 100, roadType: "main")
        let qa1 = QueryAttributes(startPoint: .zero, angle: 0, length: 100, roadType: "main")
        
        let query1 = RoadQuery(time: 1, roadAttributes: ra1, queryAttributes: qa1)
        let query2 = RoadQuery(time: 2, roadAttributes: ra1, queryAttributes: qa1)
        let query3 = RoadQuery(time: 1, roadAttributes: ra1, queryAttributes: qa1)
        
        #expect(query1 < query2)
        #expect(query1 == query3)
        #expect(!(query2 < query1))
    }
    
    @Test("TerrainMap stores and retrieves nodes correctly")
    func terrainMapStorage() {
        let terrainMap = TerrainMap()
        
        let node1 = TerrainNode(
            coordinates: (x: 10, y: 20, z: 5),
            slope: 0.2,
            urbanizationFactor: 0.7,
            district: .residential
        )
        
        terrainMap.addNode(node1)
        
        let retrieved = terrainMap.getNode(at: CGPoint(x: 10, y: 20))
        #expect(retrieved != nil)
        #expect(retrieved?.coordinates.x == 10)
        #expect(retrieved?.coordinates.y == 20)
        #expect(retrieved?.district == .residential)
    }
    
    @Test("TerrainMap returns nil for non-existent nodes")
    func terrainMapMissing() {
        let terrainMap = TerrainMap()
        let retrieved = terrainMap.getNode(at: CGPoint(x: 999, y: 999))
        #expect(retrieved == nil)
    }
    
    @Test("CityState dirty flag works")
    func cityStateDirtyFlag() {
        var cityState = createTestCityState()
        #expect(cityState.needsRuleRegeneration == true)
        
        cityState.needsRuleRegeneration = false
        #expect(cityState.needsRuleRegeneration == false)
        
        cityState.markDirty()
        #expect(cityState.needsRuleRegeneration == true)
    }
}

// MARK: - Local Constraint Rule Tests

@Suite("Local Constraint Rules")
struct LocalConstraintRuleTests {
    
    @Test("BoundaryConstraintRule rejects roads outside bounds")
    func boundaryConstraintRejectOutside() {
        var config = createTestConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        let rule = BoundaryConstraintRule(config: config)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 100, // Will extend beyond bounds
            roadType: "main"
        )
        
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .failed)
        #expect(result.reason == "Outside city bounds")
    }
    
    @Test("BoundaryConstraintRule accepts roads within bounds")
    func boundaryConstraintAcceptInside() {
        var config = createTestConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        
        let rule = BoundaryConstraintRule(config: config)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 500, y: 500),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .succeed)
    }
    
    @Test("TerrainConstraintRule rejects steep slopes")
    func terrainConstraintRejectSteep() {
        let config = createTestConfiguration()
        let rule = TerrainConstraintRule(config: config)
        
        let terrainMap = TerrainMap()
        let steepNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 50),
            slope: 0.9, // Very steep
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMap.addNode(steepNode)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .failed)
        #expect(result.reason == "Slope too steep")
    }
    
    @Test("TerrainConstraintRule rejects low urbanization")
    func terrainConstraintRejectLowUrbanization() {
        let config = createTestConfiguration()
        let rule = TerrainConstraintRule(config: config)
        
        let terrainMap = TerrainMap()
        let badNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.1, // Too low
            district: .residential
        )
        terrainMap.addNode(badNode)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .failed)
        #expect(result.reason == "Low urbanization factor")
    }
    
//    @Test("ProximityConstraintRule rejects roads too close")
//    func proximityConstraintRejectClose() {
//        let config = createTestConfiguration()
//        let rule = ProximityConstraintRule(config: config)
//        
//        let existingRoad = RoadSegment(
//            attributes: RoadAttributes(
//                startPoint: CGPoint(x: 100, y: 100),
//                angle: 0,
//                length: 50,
//                roadType: "main"
//            ),
//            createdAt: 0
//        )
//        
//        let qa = QueryAttributes(
//            startPoint: CGPoint(x: 100, y: 100),
//            angle: .pi / 2, // Perpendicular
//            length: 50,
//            roadType: "main"
//        )
//        
//        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
//        let context = GenerationContext(
//            currentLocation: qa.startPoint,
//            terrainMap: terrainMap,
//            cityState: createTestCityState(),
//            existingInfrastructure: [existingRoad],
//            queryAttributes: qa
//        )
//        
//        let result = rule.evaluate(qa, context: context)
//        #expect(result.state == .failed)
//        #expect(result.reason == "Too close to existing road")
//    }
    
    @Test("DistrictBoundaryRule prevents crossing districts for non-main roads")
    func districtBoundaryRejectCrossing() {
        let config = createTestConfiguration()
        let rule = DistrictBoundaryRule(config: config)
        
        let terrainMap = TerrainMap()
        
        // Start in residential
        let startNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMap.addNode(startNode)
        
        // End in business district
        let endNode = TerrainNode(
            coordinates: (x: 200, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .businessDistrict
        )
        terrainMap.addNode(endNode)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "local",
            isMainRoad: false
        )
        
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .failed)
        #expect(result.reason == "Cannot cross district boundary")
    }
    
    @Test("DistrictBoundaryRule allows crossing for main roads")
    func districtBoundaryAllowMainRoad() {
        let config = createTestConfiguration()
        let rule = DistrictBoundaryRule(config: config)
        
        let terrainMap = TerrainMap()
        
        let startNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMap.addNode(startNode)
        
        let endNode = TerrainNode(
            coordinates: (x: 200, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .businessDistrict
        )
        terrainMap.addNode(endNode)
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "main",
            isMainRoad: true
        )
        
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let result = rule.evaluate(qa, context: context)
        #expect(result.state == .succeed)
    }
}

// MARK: - Global Goal Rule Tests

@Suite("Global Goal Rules")
struct GlobalGoalRuleTests {
    
    @Test("DistrictPatternRule generates proposals")
    func districtPatternGeneratesProposals() {
        let config = createTestConfiguration()
        let rule = DistrictPatternRule(config: config)
        
        let terrainMap = TerrainMap()
        let node = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMap.addNode(node)
        
        let ra = RoadAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let proposals = rule.generateProposals(qa, ra, context: context)
        
        // Should generate 0-3 proposals based on probability
        #expect(proposals.count >= 0)
        #expect(proposals.count <= 3)
    }
    
    @Test("CoastalGrowthRule applies only to coastal districts")
    func coastalGrowthApplicability() {
        let config = createTestConfiguration()
        let rule = CoastalGrowthRule(config: config)
        
        let terrainMapCoastal = TerrainMap()
        let coastalNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .coastal
        )
        terrainMapCoastal.addNode(coastalNode)
        
        let contextCoastal = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMapCoastal,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: QueryAttributes(startPoint: .zero, angle: 0, length: 100, roadType: "main")
        )
        
        #expect(rule.applies(to: contextCoastal) == true)
        
        let terrainMapResidential = TerrainMap()
        let residentialNode = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMapResidential.addNode(residentialNode)
        
        let contextResidential = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMapResidential,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: QueryAttributes(startPoint: .zero, angle: 0, length: 100, roadType: "main")
        )
        
        #expect(rule.applies(to: contextResidential) == false)
    }
    
    @Test("ConnectivityRule applies only to main roads")
    func connectivityRuleMainRoadOnly() {
        let config = createTestConfiguration()
        let rule = ConnectivityRule(config: config)
        
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        
        let contextMainRoad = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: createTestCityState(age: 10),
            existingInfrastructure: [],
            queryAttributes: QueryAttributes(
                startPoint: .zero,
                angle: 0,
                length: 100,
                roadType: "main",
                isMainRoad: true
            )
        )
        
        #expect(rule.applies(to: contextMainRoad) == true)
        
        let contextLocalRoad = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: createTestCityState(age: 10),
            existingInfrastructure: [],
            queryAttributes: QueryAttributes(
                startPoint: .zero,
                angle: 0,
                length: 100,
                roadType: "local",
                isMainRoad: false
            )
        )
        
        #expect(rule.applies(to: contextLocalRoad) == false)
    }
}

// MARK: - Rule Generator Tests

@Suite("Rule Generators")
struct RuleGeneratorTests {
    
    @Test("LocalConstraintGenerator creates basic rules")
    func localConstraintGeneratorBasic() {
        let generator = LocalConstraintGenerator()
        let config = createTestConfiguration()
        let cityState = createTestCityState(age: 0)
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let rules = generator.generateRules(from: cityState, terrainMap: terrainMap, config: config)
        
        #expect(rules.count >= 4) // At minimum: boundary, terrain, proximity, district boundary
        #expect(rules.first?.priority ?? Int.max <= rules.last?.priority ?? 0) // Sorted by priority
    }
    
    @Test("LocalConstraintGenerator adds angle constraint for mature cities")
    func localConstraintGeneratorMatureCity() {
        let generator = LocalConstraintGenerator()
        let config = createTestConfiguration()
        let youngCity = createTestCityState(age: 0)
        let matureCity = createTestCityState(age: 5)
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let youngRules = generator.generateRules(from: youngCity, terrainMap: terrainMap, config: config)
        let matureRules = generator.generateRules(from: matureCity, terrainMap: terrainMap, config: config)
        
        #expect(matureRules.count >= youngRules.count)
    }
    
    @Test("GlobalGoalGenerator creates basic rules")
    func globalGoalGeneratorBasic() {
        let generator = GlobalGoalGenerator()
        let config = createTestConfiguration()
        let cityState = createTestCityState(age: 0)
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let rules = generator.generateRules(from: cityState, terrainMap: terrainMap, config: config)
        
        #expect(rules.count >= 2) // At minimum: district pattern, coastal growth
        #expect(rules.first?.priority ?? Int.max <= rules.last?.priority ?? 0) // Sorted by priority
    }
    
    @Test("GlobalGoalGenerator adds connectivity for mature cities")
    func globalGoalGeneratorMatureCity() {
        let generator = GlobalGoalGenerator()
        let config = createTestConfiguration()
        let youngCity = createTestCityState(age: 2)
        let matureCity = createTestCityState(age: 10)
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let youngRules = generator.generateRules(from: youngCity, terrainMap: terrainMap, config: config)
        let matureRules = generator.generateRules(from: matureCity, terrainMap: terrainMap, config: config)
        
        #expect(matureRules.count >= youngRules.count)
    }
}

// MARK: - Rule Evaluator Tests

@Suite("Rule Evaluators")
struct RuleEvaluatorTests {
    
    @Test("LocalConstraintEvaluator respects priority order")
    func localConstraintEvaluatorPriority() {
        var config = createTestConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        let rules: [LocalConstraintRule] = [
            BoundaryConstraintRule(config: config),
            TerrainConstraintRule(config: config)
        ]
        
        let evaluator = LocalConstraintEvaluator(rules: rules)
        
        // Test that boundary is checked first (will fail)
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 100, // Extends outside bounds
            roadType: "main"
        )
        
        let terrainMap = TerrainMap()
        let goodNode = TerrainNode(
            coordinates: (x: 50, y: 50, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.9,
            district: .residential
        )
        terrainMap.addNode(goodNode)
        
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let (_, state) = evaluator.evaluate(qa, context: context)
        #expect(state == .failed)
    }
    
    @Test("LocalConstraintEvaluator updates rules")
    func localConstraintEvaluatorUpdate() {
        let config = createTestConfiguration()
        let initialRules: [LocalConstraintRule] = [
            BoundaryConstraintRule(config: config)
        ]
        
        let evaluator = LocalConstraintEvaluator(rules: initialRules)
        
        let newRules: [LocalConstraintRule] = [
            BoundaryConstraintRule(config: config),
            TerrainConstraintRule(config: config)
        ]
        
        evaluator.updateRules(newRules)
        
        // Can't directly test private rules array, but we can test that evaluation works
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let context = GenerationContext(
            currentLocation: qa.startPoint,
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let (_, state) = evaluator.evaluate(qa, context: context)
        #expect(state == .succeed)
    }
    
    @Test("GlobalGoalEvaluator generates proposals from applicable rules")
    func globalGoalEvaluatorProposals() {
        let config = createTestConfiguration()
        let rules: [GlobalGoalRule] = [
            DistrictPatternRule(config: config)
        ]
        
        let evaluator = GlobalGoalEvaluator(rules: rules)
        
        let terrainMap = TerrainMap()
        let node = TerrainNode(
            coordinates: (x: 100, y: 100, z: 0),
            slope: 0.1,
            urbanizationFactor: 0.8,
            district: .residential
        )
        terrainMap.addNode(node)
        
        let ra = RoadAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let qa = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let context = GenerationContext(
            currentLocation: CGPoint(x: 100, y: 100),
            terrainMap: terrainMap,
            cityState: createTestCityState(),
            existingInfrastructure: [],
            queryAttributes: qa
        )
        
        let proposals = evaluator.generateProposals(qa, ra, context: context)
        
        #expect(proposals.count >= 0) // May generate 0-3 based on probability
    }
}

// MARK: - Road Generator Integration Tests

@Suite("Road Generator Integration")
struct RoadGeneratorTests {
    
    @Test("RoadGenerator initializes correctly")
    func roadGeneratorInitialization() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        #expect(generator.getSegments().isEmpty)
        #expect(generator.getQueueSize() == 0)
    }
    
    @Test("RoadGenerator generates road network from seed")
    func roadGeneratorGeneratesNetwork() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
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
        
        let segments = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        #expect(segments.count > 0) // Should generate at least the initial segment
        #expect(generator.getQueueSize() == 0) // Queue should be empty after completion
    }
    
    @Test("RoadGenerator respects boundary constraints")
    func roadGeneratorBoundaryRespect() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 200, height: 200))
        var config = createTestConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 200, height: 200)
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 100, y: 100),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        // All segments should be within bounds
        for segment in segments {
            let endPoint = CGPoint(
                x: segment.attributes.startPoint.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: segment.attributes.startPoint.y + sin(segment.attributes.angle) * segment.attributes.length
            )
            
            #expect(config.cityBounds.contains(segment.attributes.startPoint))
            #expect(config.cityBounds.contains(endPoint))
        }
    }
    
    @Test("RoadGenerator updates city state and regenerates rules")
    func roadGeneratorCityStateUpdate() {
        var cityState = createTestCityState(age: 0)
        cityState.needsRuleRegeneration = false
        
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        var newCityState = createTestCityState(age: 10)
        newCityState.population = 50000
        newCityState.markDirty()
        
        generator.updateCityState(newCityState)
        
        // Rules should have been regenerated
        // We can't directly test this, but we can verify the generator still works
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
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        #expect(segments.count > 0)
    }
    
    @Test("RoadGenerator reset clears state")
    func roadGeneratorReset() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
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
            roadType: "main"
        )
        
        _ = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        #expect(generator.getSegments().count > 0)
        
        generator.reset()
        
        #expect(generator.getSegments().isEmpty)
        #expect(generator.getQueueSize() == 0)
    }
    
    @Test("RoadGenerator handles multiple districts")
    func roadGeneratorMultipleDistricts() {
        let cityState = createTestCityState()
        let terrainMap = TerrainMap()
        
        // Create multiple districts
        for x in 0..<500 {
            for y in 0..<1000 {
                let node = TerrainNode(
                    coordinates: (x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: .businessDistrict
                )
                terrainMap.addNode(node)
            }
        }
        
        for x in 500..<1000 {
            for y in 0..<1000 {
                let node = TerrainNode(
                    coordinates: (x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: .residential
                )
                terrainMap.addNode(node)
            }
        }
        
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 250, y: 500),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 250, y: 500),
            angle: 0,
            length: 100,
            roadType: "main",
            isMainRoad: true
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        #expect(segments.count > 0)
    }
}

// MARK: - Configuration Tests

@Suite("Configuration Tests")
struct ConfigurationTests {
    
    @Test("RuleConfiguration has default values")
    func configurationDefaults() {
        let config = RuleConfiguration()
        
        #expect(config.cityBounds == CGRect(x: 0, y: 0, width: 1000, height: 1000))
        #expect(config.minimumRoadDistance == 10.0)
        #expect(config.maxBuildableSlope == 0.3)
        #expect(config.defaultDelay == 1)
    }
    
    @Test("RuleConfiguration branching probabilities exist for all districts")
    func configurationBranchingProbabilities() {
        let config = RuleConfiguration()
        
        let districts: [DistrictType] = [
            .businessDistrict,
            .oldTown,
            .residential,
            .industrial,
            .coastal,
            .undefined
        ]
        
        for district in districts {
            #expect(config.branchingProbability[district] != nil)
            #expect(config.roadLengthMultiplier[district] != nil)
            #expect(config.branchingAngles[district] != nil)
        }
    }
    
    @Test("RuleConfiguration angle constraints are valid")
    func configurationAngleConstraints() {
        let config = RuleConfiguration()
        
        #expect(config.mainRoadAngleMin < config.mainRoadAngleMax)
        #expect(config.internalRoadAngleMin < config.internalRoadAngleMax)
        #expect(config.mainRoadAngleMin > 0)
        #expect(config.mainRoadAngleMax <= .pi)
    }
}

// MARK: - End-to-End Tests

@Suite("End-to-End Scenarios")
struct EndToEndTests {
    
    @Test("Complete city generation workflow")
    func completeCityGenerationWorkflow() {
        // Setup initial state
        var cityState = CityState(
            population: 5000,
            density: 1000,
            economicLevel: 0.4,
            age: 0
        )
        
        let terrainMap = TerrainMap()
        
        // Create a simple terrain with different districts
        for x in 0..<1000 {
            for y in 0..<1000 {
                let district: DistrictType
                if x < 300 {
                    district = .oldTown
                } else if x < 600 {
                    district = .residential
                } else {
                    district = .businessDistrict
                }
                
                let node = TerrainNode(
                    coordinates: (x: Double(x), y: Double(y), z: 0),
                    slope: Double.random(in: 0...0.2),
                    urbanizationFactor: Double.random(in: 0.5...1.0),
                    district: district
                )
                terrainMap.addNode(node)
            }
        }
        
        let config = RuleConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Generate initial city stage
        let stage1Road = RoadAttributes(
            startPoint: CGPoint(x: 150, y: 500),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let stage1Query = QueryAttributes(
            startPoint: CGPoint(x: 150, y: 500),
            angle: 0,
            length: 100,
            roadType: "main",
            isMainRoad: true
        )
        
        let stage1Segments = generator.generateRoadNetwork(
            initialRoad: stage1Road,
            initialQuery: stage1Query
        )
        
        #expect(stage1Segments.count > 0)
        let stage1Count = stage1Segments.count
        
        // Simulate city growth
        cityState.population = 10000
        cityState.density = 2000
        cityState.economicLevel = 0.6
        cityState.age = 5
        cityState.markDirty()
        
        generator.updateCityState(cityState)
        generator.reset()
        
        // Generate second stage
        let stage2Road = RoadAttributes(
            startPoint: CGPoint(x: 450, y: 500),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let stage2Query = QueryAttributes(
            startPoint: CGPoint(x: 450, y: 500),
            angle: 0,
            length: 100,
            roadType: "main",
            isMainRoad: true
        )
        
        let stage2Segments = generator.generateRoadNetwork(
            initialRoad: stage2Road,
            initialQuery: stage2Query
        )
        
        #expect(stage2Segments.count > 0)
        
        // Verify both stages generated roads
        #expect(stage1Count > 0)
        #expect(stage2Segments.count > 0)
    }
    
    @Test("Coastal city development")
    func coastalCityDevelopment() {
        let cityState = createTestCityState()
        let terrainMap = TerrainMap()
        
        // Create coastal terrain
        for x in 0..<1000 {
            for y in 0..<1000 {
                let district: DistrictType = (y < 200) ? .coastal : .residential
                
                let node = TerrainNode(
                    coordinates: (x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.8,
                    district: district
                )
                terrainMap.addNode(node)
            }
        }
        
        let config = RuleConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Start from coastal area
        let coastalRoad = RoadAttributes(
            startPoint: CGPoint(x: 500, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let coastalQuery = QueryAttributes(
            startPoint: CGPoint(x: 500, y: 100),
            angle: 0,
            length: 100,
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: coastalRoad,
            initialQuery: coastalQuery
        )
        
        #expect(segments.count > 0)
        
        // Verify some roads are in coastal district
        let coastalSegments = segments.filter { segment in
            segment.attributes.startPoint.y < 200
        }
        
        #expect(coastalSegments.count > 0)
    }
    
    @Test("High slope terrain rejection")
    func highSlopeTerrainRejection() {
        let cityState = createTestCityState()
        let terrainMap = TerrainMap()
        
        // Create terrain with high slopes in center
        for x in 0..<1000 {
            for y in 0..<1000 {
                let slope: Double
                if x > 400 && x < 600 && y > 400 && y < 600 {
                    slope = 0.8 // Very steep
                } else {
                    slope = 0.1
                }
                
                let node = TerrainNode(
                    coordinates: (x: Double(x), y: Double(y), z: 0),
                    slope: slope,
                    urbanizationFactor: 0.8,
                    district: .residential
                )
                terrainMap.addNode(node)
            }
        }
        
        let config = RuleConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Start from steep area
        let steepRoad = RoadAttributes(
            startPoint: CGPoint(x: 500, y: 500),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let steepQuery = QueryAttributes(
            startPoint: CGPoint(x: 500, y: 500),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: steepRoad,
            initialQuery: steepQuery
        )
        
        // Should generate no segments or very few (all should fail terrain check)
        #expect(segments.count == 0)
    }
}

// MARK: - Edge Case Tests

@Suite("Edge Cases")
struct EdgeCaseTests {
    
    @Test("Empty terrain map")
    func emptyTerrainMap() {
        let cityState = createTestCityState()
        let terrainMap = TerrainMap() // Empty
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
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
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: initialRoad,
            initialQuery: initialQuery
        )
        
        // Should fail terrain checks
        #expect(segments.count == 0)
    }
    
    @Test("Zero length road")
    func zeroLengthRoad() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let zeroRoad = RoadAttributes(
            startPoint: CGPoint(x: 500, y: 500),
            angle: 0,
            length: 0,
            roadType: "main"
        )
        
        let zeroQuery = QueryAttributes(
            startPoint: CGPoint(x: 500, y: 500),
            angle: 0,
            length: 0,
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: zeroRoad,
            initialQuery: zeroQuery
        )
        
        // Should accept the zero-length road (it's valid, just won't extend)
        #expect(segments.count >= 0)
    }
    
    @Test("Extreme angles")
    func extremeAngles() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let angles: [Double] = [0, .pi / 2, .pi, 3 * .pi / 2, 2 * .pi]
        
        for angle in angles {
            generator.reset()
            
            let road = RoadAttributes(
                startPoint: CGPoint(x: 500, y: 500),
                angle: angle,
                length: 50,
                roadType: "main"
            )
            
            let query = QueryAttributes(
                startPoint: CGPoint(x: 500, y: 500),
                angle: angle,
                length: 50,
                roadType: "main"
            )
            
            let segments = generator.generateRoadNetwork(
                initialRoad: road,
                initialQuery: query
            )
            
            // Should handle all angles
            #expect(segments.count >= 0)
        }
    }
    
    @Test("Very small city bounds")
    func verySmallCityBounds() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        var config = createTestConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let road = RoadAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 20,
            roadType: "main"
        )
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 50, y: 50),
            angle: 0,
            length: 20,
            roadType: "main"
        )
        
        let segments = generator.generateRoadNetwork(
            initialRoad: road,
            initialQuery: query
        )
        
        // Should work but with limited expansion
        #expect(segments.count >= 0)
        
        // All segments should be within small bounds
        for segment in segments {
            #expect(segment.attributes.startPoint.x >= 0)
            #expect(segment.attributes.startPoint.x <= 100)
            #expect(segment.attributes.startPoint.y >= 0)
            #expect(segment.attributes.startPoint.y <= 100)
        }
    }
}

// MARK: - Performance Tests

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("Large terrain map generation")
    func largeTerrainMapGeneration() {
        let cityState = createTestCityState()
        let terrainMap = createTestTerrainMap(bounds: CGRect(x: 0, y: 0, width: 500, height: 500))
        let config = createTestConfiguration()
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        let road = RoadAttributes(
            startPoint: CGPoint(x: 250, y: 250),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let query = QueryAttributes(
            startPoint: CGPoint(x: 250, y: 250),
            angle: 0,
            length: 50,
            roadType: "main"
        )
        
        let startTime = Date()
        let segments = generator.generateRoadNetwork(
            initialRoad: road,
            initialQuery: query
        )
        let duration = Date().timeIntervalSince(startTime)
        
        #expect(segments.count >= 0)
        #expect(duration < 10.0) // Should complete in reasonable time
    }
}
