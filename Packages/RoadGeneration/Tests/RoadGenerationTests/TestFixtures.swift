import Foundation
import Terrain
@testable import RoadGeneration

/// Shared test fixtures for RoadGeneration tests
enum TestFixtures {

    /// Creates a completely flat terrain map with uniform properties.
    ///
    /// Every node has slope=0, urbanization=1.0, district=.residential.
    /// Returns a matching `RuleConfiguration` with `cityBounds` set to the map size.
    @MainActor
    static func flatTerrainMap(size: Int) -> (Terrain.TerrainMap, RuleConfiguration) {
        let header = Terrain.ASCHeader(
            ncols: size,
            nrows: size,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: 1,
            nodataValue: -9999
        )

        var nodes: [[Terrain.TerrainNode]] = []
        for y in 0..<size {
            var row: [Terrain.TerrainNode] = []
            for x in 0..<size {
                let node = Terrain.TerrainNode(
                    coordinates: Terrain.TerrainNode.Coordinates(
                        x: Double(x), y: Double(y), z: 0
                    ),
                    slope: 0,
                    urbanizationFactor: 1.0,
                    district: .residential
                )
                row.append(node)
            }
            nodes.append(row)
        }

        let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)

        var config = RuleConfiguration()
        config.cityBounds = CGRect(x: 0, y: 0, width: size, height: size)

        return (terrainMap, config)
    }
}
