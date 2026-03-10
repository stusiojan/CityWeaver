import CoreGraphics
import Foundation
import Terrain

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
    let config = RuleConfiguration()

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
    let (roadNetwork, report) = generator.generateRoadNetwork(
        initialRoad: initialRoad,
        initialQuery: initialQuery
    )

    print("Generated \(roadNetwork.count) road segments")
    print(report.diagnosticMessage)

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
