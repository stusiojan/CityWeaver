import Foundation
import Terrain

/// Painter for district assignments with various tools
@MainActor
final class DistrictPainter {
    
    /// Paint a single cell with the selected district
    func paintCell(
        _ map: TerrainMap,
        x: Int,
        y: Int,
        district: DistrictType?
    ) {
        map.setDistrict(at: x, y: y, district: district)
    }
    
    /// Paint multiple cells in a brush pattern
    func paintWithBrush(
        _ map: TerrainMap,
        x: Int,
        y: Int,
        district: DistrictType?,
        brushSize: Int
    ) {
        let radius = brushSize / 2
        
        for dy in -radius...radius {
            for dx in -radius...radius {
                map.setDistrict(at: x + dx, y: y + dy, district: district)
            }
        }
    }
    
    /// Flood fill from a starting point
    func floodFill(
        _ map: TerrainMap,
        startX: Int,
        startY: Int,
        targetDistrict: DistrictType?
    ) {
        guard let startNode = map.getNode(at: startX, y: startY) else { return }
        let originalDistrict = startNode.district
        
        // Don't fill if already the target district
        if originalDistrict == targetDistrict {
            return
        }
        
        var queue: [(Int, Int)] = [(startX, startY)]
        var visited = Set<String>()
        
        while !queue.isEmpty {
            let (x, y) = queue.removeFirst()
            let key = "\(x),\(y)"
            
            if visited.contains(key) {
                continue
            }
            
            guard let node = map.getNode(at: x, y: y),
                  node.district == originalDistrict else {
                continue
            }
            
            visited.insert(key)
            map.setDistrict(at: x, y: y, district: targetDistrict)
            
            // Add 4-connected neighbors
            queue.append((x - 1, y))
            queue.append((x + 1, y))
            queue.append((x, y - 1))
            queue.append((x, y + 1))
        }
    }
    
    /// Paint a rectangle area
    func paintRectangle(
        _ map: TerrainMap,
        from: (x: Int, y: Int),
        to: (x: Int, y: Int),
        district: DistrictType?
    ) {
        let minX = min(from.x, to.x)
        let maxX = max(from.x, to.x)
        let minY = min(from.y, to.y)
        let maxY = max(from.y, to.y)
        
        for y in minY...maxY {
            for x in minX...maxX {
                map.setDistrict(at: x, y: y, district: district)
            }
        }
    }
}

