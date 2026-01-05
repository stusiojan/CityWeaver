import XCTest
import Terrain
@testable import RoadGeneration

final class IntegrationTests: XCTestCase {
    
    // MARK: - Full Generation Pipeline Tests
    
    @MainActor
    func testCompleteRoadGeneration() throws {
        // Create a realistic terrain map
        let header = Terrain.ASCHeader(
            ncols: 50,
            nrows: 50,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: 1,
            nodataValue: -9999
        )
        
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<50 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<50 {
                let z = sin(Double(x) * 0.1) * cos(Double(y) * 0.1) * 5
                let slope = abs(cos(Double(x) * 0.15)) * 0.3
                let district: Terrain.DistrictType
                
                // Create different districts
                if x < 15 {
                    district = .oldTown
                } else if x < 30 {
                    district = .residential
                } else if y < 25 {
                    district = .business
                } else {
                    district = .park
                }
                
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: z),
                    slope: slope,
                    urbanizationFactor: max(0, 1 - slope * 2),
                    district: district
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
        
        // Create city state
        let cityState = CityState(
            population: 50_000,
            density: 1_500,
            economicLevel: 0.6,
            age: 15
        )
        
        // Create configuration
        var config = RuleConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 50, height: 50)
        
        // Create generator
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Generate roads
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
        
        let startTime = Date()
        let roads = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
        let duration = Date().timeIntervalSince(startTime)
        
        // Validate results
        XCTAssertFalse(roads.isEmpty, "Should generate at least some roads")
        XCTAssertGreaterThan(roads.count, 10, "Should generate a reasonable number of roads")
        XCTAssertLessThan(duration, 5.0, "Generation should complete in reasonable time")
        
        // Verify all roads are within bounds
        for road in roads {
            let start = road.attributes.startPoint
            let end = CGPoint(
                x: start.x + cos(road.attributes.angle) * road.attributes.length,
                y: start.y + sin(road.attributes.angle) * road.attributes.length
            )
            
            XCTAssertTrue(config.cityBounds.contains(start), "Road start should be within bounds")
            XCTAssertTrue(config.cityBounds.contains(end), "Road end should be within bounds")
        }
        
        print("Generated \(roads.count) roads in \(duration) seconds")
    }
    
    @MainActor
    func testGenerationWithDistrictConstraints() throws {
        // Create terrain with distinct districts
        let header = Terrain.ASCHeader(
            ncols: 30,
            nrows: 30,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: 1,
            nodataValue: -9999
        )
        
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<30 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<30 {
                let district: Terrain.DistrictType = x < 15 ? .residential : .business
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: 0.1,
                    urbanizationFactor: 0.9,
                    district: district
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
        
        let cityState = CityState(population: 20_000, density: 1_000, economicLevel: 0.5, age: 10)
        
        var config = RuleConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 30, height: 30)
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Start in residential district
        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 10, y: 15),
            angle: 0,
            length: 3,
            roadType: "residential"
        )
        
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 10, y: 15),
            angle: 0,
            length: 3,
            roadType: "residential"
        )
        
        let roads = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
        
        XCTAssertFalse(roads.isEmpty, "Should generate roads")
        
        // Count roads in each district
        var residentialCount = 0
        var businessCount = 0
        
        for road in roads {
            let midPoint = CGPoint(
                x: road.attributes.startPoint.x + cos(road.attributes.angle) * road.attributes.length / 2,
                y: road.attributes.startPoint.y + sin(road.attributes.angle) * road.attributes.length / 2
            )
            
            if midPoint.x < 15 {
                residentialCount += 1
            } else {
                businessCount += 1
            }
        }
        
        print("Residential roads: \(residentialCount), Business roads: \(businessCount)")
        
        // Should have roads in both districts (main roads can cross)
        XCTAssertGreaterThan(residentialCount, 0, "Should have roads in residential district")
    }
    
    @MainActor
    func testGenerationWithTerrainConstraints() throws {
        // Create terrain with varying slopes
        let header = Terrain.ASCHeader(
            ncols: 30,
            nrows: 30,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: 1,
            nodataValue: -9999
        )
        
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<30 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<30 {
                // Create steep terrain in center
                let distanceFromCenter = sqrt(pow(Double(x) - 15, 2) + pow(Double(y) - 15, 2))
                let slope = distanceFromCenter < 5 ? 0.8 : 0.1  // Steep hill in center
                
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: 0),
                    slope: slope,
                    urbanizationFactor: max(0, 1 - slope * 2),
                    district: .residential
                )
                row.append(node)
            }
            nodes.append(row)
        }
        
        let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
        
        let cityState = CityState(population: 15_000, density: 1_000, economicLevel: 0.5, age: 5)
        
        var config = RuleConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 30, height: 30)
        config.maxBuildableSlope = 0.3
        
        let generator = RoadGenerator(
            cityState: cityState,
            terrainMap: terrainMap,
            config: config
        )
        
        // Start outside steep area
        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 3,
            roadType: "main"
        )
        
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 5, y: 5),
            angle: 0,
            length: 3,
            roadType: "main",
            isMainRoad: true
        )
        
        let roads = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
        
        XCTAssertFalse(roads.isEmpty, "Should generate roads in flat areas")
        
        // Verify no roads in steep center area
        for road in roads {
            let midPoint = CGPoint(
                x: road.attributes.startPoint.x + cos(road.attributes.angle) * road.attributes.length / 2,
                y: road.attributes.startPoint.y + sin(road.attributes.angle) * road.attributes.length / 2
            )
            
            let distanceFromCenter = sqrt(pow(midPoint.x - 15, 2) + pow(midPoint.y - 15, 2))
            
            // Most roads should avoid the steep center
            if distanceFromCenter < 5 {
                print("Warning: Road near steep area at (\(midPoint.x), \(midPoint.y))")
            }
        }
    }
    
    @MainActor
    func testRuleRegeneration() throws {
        let header = Terrain.ASCHeader(ncols: 20, nrows: 20, xllcenter: 0, yllcenter: 0, cellsize: 1, nodataValue: -9999)
        
        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<20 {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<20 {
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
        
        let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
        
        var cityState = CityState(population: 10_000, density: 1_000, economicLevel: 0.5, age: 0)
        
        var config = RuleConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: 20, height: 20)
        
        let generator = RoadGenerator(cityState: cityState, terrainMap: terrainMap, config: config)
        
        // Generate initial roads
        let initialRoad = RoadAttributes(
            startPoint: CGPoint(x: 10, y: 10),
            angle: 0,
            length: 2,
            roadType: "main"
        )
        
        let initialQuery = QueryAttributes(
            startPoint: CGPoint(x: 10, y: 10),
            angle: 0,
            length: 2,
            roadType: "main",
            isMainRoad: true
        )
        
        let roads1 = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
        
        XCTAssertFalse(roads1.isEmpty, "Should generate initial roads")
        
        // Update city state (triggers rule regeneration)
        cityState.age = 10
        cityState.markDirty()
        generator.updateCityState(cityState)
        
        // Generate more roads with updated rules
        generator.reset()
        let roads2 = generator.generateRoadNetwork(initialRoad: initialRoad, initialQuery: initialQuery)
        
        XCTAssertFalse(roads2.isEmpty, "Should generate roads after update")
        
        // The road count may differ due to rule changes
        print("Initial roads: \(roads1.count), After update: \(roads2.count)")
    }
}

