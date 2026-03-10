import XCTest
import Terrain
@testable import RoadGeneration

final class ExportTests: XCTestCase {
    
    var sampleRoads: [RoadSegment]!
    var terrainMap: Terrain.TerrainMap!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        // Create sample roads for export testing
        sampleRoads = [
            RoadSegment(
                attributes: RoadAttributes(
                    startPoint: CGPoint(x: 10, y: 10),
                    angle: 0,
                    length: 20,
                    roadType: "main"
                ),
                createdAt: 0
            ),
            RoadSegment(
                attributes: RoadAttributes(
                    startPoint: CGPoint(x: 30, y: 10),
                    angle: .pi / 2,
                    length: 15,
                    roadType: "residential"
                ),
                createdAt: 1
            ),
            RoadSegment(
                attributes: RoadAttributes(
                    startPoint: CGPoint(x: 30, y: 25),
                    angle: .pi,
                    length: 10,
                    roadType: "street"
                ),
                createdAt: 2
            )
        ]
        
        // Create small terrain map
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
                let z = sin(Double(x) * 0.1) * 2
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: z),
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
    
    // MARK: - JSON Export Tests
    
    func testJSONExportRoundTrip() throws {
        let serializer = RoadNetworkSerializer()
        
        let cityState = RoadNetworkSerializer.CityStateSnapshot(
            population: 50_000,
            density: 1_500,
            economicLevel: 0.6,
            age: 15
        )
        
        let config = RoadNetworkSerializer.ConfigurationSnapshot(
            maxBuildableSlope: 0.3,
            minUrbanizationFactor: 0.2,
            minimumRoadDistance: 10.0
        )
        
        // Export to JSON
        let jsonData = try serializer.export(sampleRoads, cityState: cityState, configuration: config)
        
        XCTAssertFalse(jsonData.isEmpty, "JSON data should not be empty")
        
        // Verify it's valid JSON
        let json = try? JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(json, "Should produce valid JSON")
        
        // Import back
        let (importedRoads, importedMetadata, _) = try serializer.import(from: jsonData)
        
        // Verify road count matches
        XCTAssertEqual(importedRoads.count, sampleRoads.count, "Should import same number of roads")
        
        // Verify metadata
        XCTAssertEqual(importedMetadata.cityState.population, cityState.population)
        XCTAssertEqual(importedMetadata.cityState.density, cityState.density)
        XCTAssertEqual(importedMetadata.configuration.maxBuildableSlope, config.maxBuildableSlope)
        
        // Verify road attributes
        for (original, imported) in zip(sampleRoads, importedRoads) {
            XCTAssertEqual(imported.attributes.startPoint.x, original.attributes.startPoint.x, accuracy: 0.01)
            XCTAssertEqual(imported.attributes.startPoint.y, original.attributes.startPoint.y, accuracy: 0.01)
            XCTAssertEqual(imported.attributes.angle, original.attributes.angle, accuracy: 0.01)
            XCTAssertEqual(imported.attributes.length, original.attributes.length, accuracy: 0.01)
            XCTAssertEqual(imported.attributes.roadType, original.attributes.roadType)
        }
    }
    
    func testJSONSimpleExport() throws {
        let serializer = RoadNetworkSerializer()
        
        // Export without metadata
        let jsonData = try serializer.exportSimple(sampleRoads)
        
        XCTAssertFalse(jsonData.isEmpty, "JSON data should not be empty")
        
        // Import back
        let importedRoads = try serializer.importSimple(from: jsonData)
        
        XCTAssertEqual(importedRoads.count, sampleRoads.count, "Should import same number of roads")
    }
    
    func testJSONContainsExpectedFields() throws {
        let serializer = RoadNetworkSerializer()
        
        let cityState = RoadNetworkSerializer.CityStateSnapshot(
            population: 50_000,
            density: 1_500,
            economicLevel: 0.6,
            age: 15
        )
        
        let config = RoadNetworkSerializer.ConfigurationSnapshot(
            maxBuildableSlope: 0.3,
            minUrbanizationFactor: 0.2,
            minimumRoadDistance: 10.0
        )
        
        let jsonData = try serializer.export(sampleRoads, cityState: cityState, configuration: config)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        
        // Check for expected fields
        XCTAssertTrue(jsonString.contains("metadata"), "Should contain metadata section")
        XCTAssertTrue(jsonString.contains("generatedAt"), "Should contain generation timestamp")
        XCTAssertTrue(jsonString.contains("cityState"), "Should contain city state")
        XCTAssertTrue(jsonString.contains("configuration"), "Should contain configuration")
        XCTAssertTrue(jsonString.contains("roads"), "Should contain roads array")
        XCTAssertTrue(jsonString.contains("startPoint"), "Should contain road start points")
        XCTAssertTrue(jsonString.contains("angle"), "Should contain road angles")
    }
    
    // MARK: - OBJ Export Tests

    @MainActor
    func testOBJExportProducesValidFormat() {
        let exporter = OBJExporter()
        let options = OBJExporter.ExportOptions(
            roadWidth: 4.0,
            roadElevation: 0.1,
            content: .roadsOnly,
            terrainDownsample: 1,
            terrainVerticalScale: 1.0
        )
        
        let (obj, mtl) = exporter.export(segments: sampleRoads, terrainMap: nil, options: options)
        
        // Verify OBJ structure
        XCTAssertTrue(obj.contains("mtllib"), "OBJ should reference material file")
        XCTAssertTrue(obj.contains("v "), "OBJ should contain vertices")
        XCTAssertTrue(obj.contains("f "), "OBJ should contain faces")
        XCTAssertTrue(obj.contains("o Road_"), "OBJ should contain named objects")
        XCTAssertTrue(obj.contains("usemtl"), "OBJ should use materials")
        
        // Verify MTL structure
        XCTAssertTrue(mtl.contains("newmtl"), "MTL should define materials")
        XCTAssertTrue(mtl.contains("Ka"), "MTL should have ambient color")
        XCTAssertTrue(mtl.contains("Kd"), "MTL should have diffuse color")
        XCTAssertTrue(mtl.contains("Ks"), "MTL should have specular color")
    }
    
    @MainActor
    func testOBJExportWithTerrain() {
        let exporter = OBJExporter()
        let options = OBJExporter.ExportOptions(
            roadWidth: 4.0,
            roadElevation: 0.1,
            content: .roadsAndTerrain,
            terrainDownsample: 5,  // Downsample heavily for test
            terrainVerticalScale: 1.0
        )
        
        let (obj, mtl) = exporter.export(segments: sampleRoads, terrainMap: terrainMap, options: options)
        
        // Should include terrain
        XCTAssertTrue(obj.contains("o Terrain"), "OBJ should include terrain object")
        XCTAssertTrue(obj.contains("usemtl terrain"), "OBJ should use terrain material")
        
        // Should have terrain material
        XCTAssertTrue(mtl.contains("newmtl terrain"), "MTL should define terrain material")
        
        // Should have significantly more vertices with terrain
        let vertexCount = obj.components(separatedBy: "\nv ").count - 1
        XCTAssertGreaterThan(vertexCount, sampleRoads.count * 8, 
                            "Should have many vertices with terrain")
    }
    
    @MainActor
    func testOBJExportTerrainOnly() {
        let exporter = OBJExporter()
        let options = OBJExporter.ExportOptions(
            content: .terrainOnly,
            terrainDownsample: 5
        )

        let (obj, mtl) = exporter.export(segments: sampleRoads, terrainMap: terrainMap, options: options)

        // Should include terrain but no roads
        XCTAssertTrue(obj.contains("o Terrain"), "OBJ should include terrain object")
        XCTAssertFalse(obj.contains("o Road_"), "OBJ should not include road objects")
        XCTAssertTrue(mtl.contains("newmtl terrain"), "MTL should define terrain material")
        XCTAssertFalse(mtl.contains("newmtl road_"), "MTL should not define road materials")
    }

    @MainActor
    func testOBJVertexCount() {
        let exporter = OBJExporter()
        let options = OBJExporter.ExportOptions(content: .roadsOnly)
        
        let (obj, _) = exporter.export(segments: sampleRoads, terrainMap: nil, options: options)
        
        // Each road segment should produce 8 vertices (rectangular prism)
        let vertexLines = obj.components(separatedBy: "\n").filter { $0.hasPrefix("v ") }
        let expectedVertices = sampleRoads.count * 8
        
        XCTAssertEqual(vertexLines.count, expectedVertices, 
                      "Should have 8 vertices per road segment")
    }
    
    // MARK: - JSON Export with Terrain

    @MainActor
    func testJSONExportWithTerrain() throws {
        let serializer = RoadNetworkSerializer()

        let cityState = RoadNetworkSerializer.CityStateSnapshot(
            population: 50_000, density: 1_500, economicLevel: 0.6, age: 15
        )
        let config = RoadNetworkSerializer.ConfigurationSnapshot(
            maxBuildableSlope: 0.3, minUrbanizationFactor: 0.2, minimumRoadDistance: 10.0
        )
        let terrainSnapshot = RoadNetworkSerializer.TerrainSnapshot(terrainMap: terrainMap)

        let data = try serializer.export(
            sampleRoads,
            cityState: cityState,
            configuration: config,
            content: .roadsAndTerrain,
            terrainSnapshot: terrainSnapshot
        )

        let (importedRoads, _, importedTerrain) = try serializer.import(from: data)

        XCTAssertEqual(importedRoads.count, sampleRoads.count)
        XCTAssertNotNil(importedTerrain, "Should contain terrain data")
        XCTAssertEqual(importedTerrain?.cols, 50)
        XCTAssertEqual(importedTerrain?.rows, 50)
    }

    @MainActor
    func testJSONExportTerrainOnly() throws {
        let serializer = RoadNetworkSerializer()

        let cityState = RoadNetworkSerializer.CityStateSnapshot(
            population: 50_000, density: 1_500, economicLevel: 0.6, age: 15
        )
        let config = RoadNetworkSerializer.ConfigurationSnapshot(
            maxBuildableSlope: 0.3, minUrbanizationFactor: 0.2, minimumRoadDistance: 10.0
        )
        let terrainSnapshot = RoadNetworkSerializer.TerrainSnapshot(terrainMap: terrainMap)

        let data = try serializer.export(
            sampleRoads,
            cityState: cityState,
            configuration: config,
            content: .terrainOnly,
            terrainSnapshot: terrainSnapshot
        )

        let (importedRoads, _, importedTerrain) = try serializer.import(from: data)

        XCTAssertTrue(importedRoads.isEmpty, "Should not contain roads when exporting terrain only")
        XCTAssertNotNil(importedTerrain, "Should contain terrain data")
    }
}

