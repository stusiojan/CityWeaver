import Testing
@testable import Terrain

@Suite("TerrainMapBuilder Tests")
@MainActor
struct TerrainMapBuilderTests {
    
    @Test("Build TerrainMap from heights")
    func testBuildTerrainMap() async {
        let header = ASCHeader(
            ncols: 3,
            nrows: 3,
            xllcenter: 100.0,
            yllcenter: 200.0,
            cellsize: 1.0,
            nodataValue: -9999
        )
        
        let heights = [
            [10.0, 11.0, 12.0],
            [10.5, 11.5, 12.5],
            [11.0, 12.0, 13.0]
        ]
        
        let builder = TerrainMapBuilder()
        let map = builder.buildTerrainMap(header: header, heights: heights)
        
        #expect(map.dimensions.rows == 3)
        #expect(map.dimensions.cols == 3)
        
        // Check first node coordinates
        let node = map.getNode(at: 0, y: 0)
        #expect(node != nil)
        #expect(node?.coordinates.x == 100.0)
        #expect(node?.coordinates.y == 200.0)
        #expect(node?.coordinates.z == 10.0)
    }
    
    @Test("Calculate slope and urbanization for nodes")
    func testNodeCalculations() async {
        let header = ASCHeader(
            ncols: 3,
            nrows: 3,
            xllcenter: 0.0,
            yllcenter: 0.0,
            cellsize: 1.0,
            nodataValue: -9999
        )
        
        let heights = [
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0]
        ]
        
        let builder = TerrainMapBuilder()
        let map = builder.buildTerrainMap(header: header, heights: heights)
        
        let node = map.getNode(at: 1, y: 1)
        #expect(node != nil)
        #expect(node?.slope == 0.0)
        #expect(node?.urbanizationFactor == 1.0)
    }
}

