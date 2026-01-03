import Foundation

/// Main structure representing the terrain map with a 2D grid of nodes
@MainActor
public final class TerrainMap: Sendable {
    public let header: ASCHeader
    private var _nodes: [[TerrainNode]]
    
    public var nodes: [[TerrainNode]] {
        _nodes
    }
    
    public init(header: ASCHeader, nodes: [[TerrainNode]]) {
        self.header = header
        self._nodes = nodes
    }
    
    /// Get node at specific grid coordinates
    /// - Parameters:
    ///   - x: Column index (0..<ncols)
    ///   - y: Row index (0..<nrows)
    /// - Returns: TerrainNode if coordinates are valid, nil otherwise
    public func getNode(at x: Int, y: Int) -> TerrainNode? {
        guard y >= 0, y < _nodes.count,
              x >= 0, x < _nodes[y].count else {
            return nil
        }
        return _nodes[y][x]
    }
    
    /// Get node at world coordinates
    /// - Parameter point: World coordinate point
    /// - Returns: TerrainNode if point is within bounds, nil otherwise
    public func getNode(at point: (x: Double, y: Double)) -> TerrainNode? {
        let gridX = Int((point.x - header.xllcenter) / header.cellsize)
        let gridY = Int((point.y - header.yllcenter) / header.cellsize)
        return getNode(at: gridX, y: gridY)
    }
    
    /// Set district for a specific node
    /// - Parameters:
    ///   - x: Column index
    ///   - y: Row index
    ///   - district: District type to set (or nil to clear)
    public func setDistrict(at x: Int, y: Int, district: DistrictType?) {
        guard y >= 0, y < _nodes.count,
              x >= 0, x < _nodes[y].count else {
            return
        }
        _nodes[y][x].district = district
    }
    
    /// Get all nodes with a specific district
    public func getNodes(for district: DistrictType) -> [(x: Int, y: Int, node: TerrainNode)] {
        var result: [(x: Int, y: Int, node: TerrainNode)] = []
        for y in 0..<_nodes.count {
            for x in 0..<_nodes[y].count {
                if _nodes[y][x].district == district {
                    result.append((x, y, _nodes[y][x]))
                }
            }
        }
        return result
    }
    
    /// Get dimensions of the terrain map
    public var dimensions: (rows: Int, cols: Int) {
        (_nodes.count, _nodes.first?.count ?? 0)
    }
}

