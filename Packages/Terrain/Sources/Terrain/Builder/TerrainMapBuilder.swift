import Foundation

/// Builder for constructing TerrainMap from raw height data
@MainActor
public struct TerrainMapBuilder: Sendable {
    private let calculator: TerrainCalculator
    
    public init() {
        self.calculator = TerrainCalculator()
    }
    
    /// Build a complete TerrainMap from ASC header and height grid
    /// - Parameters:
    ///   - header: ASC file header with metadata
    ///   - heights: 2D array of elevation values [row][col]
    /// - Returns: TerrainMap with calculated nodes
    public func buildTerrainMap(
        header: ASCHeader,
        heights: [[Double]]
    ) -> TerrainMap {
        var nodes: [[TerrainNode]] = []
        
        for y in 0..<header.nrows {
            var row: [TerrainNode] = []
            
            for x in 0..<header.ncols {
                let height = heights[y][x]
                
                // Calculate world coordinates
                let worldX = header.xllcenter + Double(x) * header.cellsize
                let worldY = header.yllcenter + Double(y) * header.cellsize
                let worldZ = height
                
                let coordinates = TerrainNode.Coordinates(
                    x: worldX,
                    y: worldY,
                    z: worldZ
                )
                
                // Calculate slope
                let slope = calculator.calculateSlope(
                    at: x,
                    y: y,
                    heights: heights,
                    cellsize: header.cellsize
                )
                
                // Calculate urbanization factor
                let urbanizationFactor = calculator.calculateUrbanizationFactor(from: slope)
                
                // Create node (district will be set later by user)
                let node = TerrainNode(
                    coordinates: coordinates,
                    slope: slope,
                    urbanizationFactor: urbanizationFactor,
                    district: nil
                )
                
                row.append(node)
            }
            
            nodes.append(row)
        }
        
        return TerrainMap(header: header, nodes: nodes)
    }
}

