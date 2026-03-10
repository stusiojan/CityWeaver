import Foundation

/// Utilities for painting district types onto generated terrain maps
public enum DistrictLayout {

    /// Paints a rectangular region with a district type
    /// - Parameters:
    ///   - terrainMap: The terrain map to modify
    ///   - district: The district type to paint
    ///   - origin: Top-left corner of the rectangle (x, y)
    ///   - size: Width and height of the rectangle
    @MainActor
    public static func paintRect(
        on terrainMap: TerrainMap,
        district: DistrictType,
        origin: (x: Int, y: Int),
        size: (width: Int, height: Int)
    ) {
        let (rows, cols) = terrainMap.dimensions

        let minX = max(0, origin.x)
        let minY = max(0, origin.y)
        let maxX = min(cols, origin.x + size.width)
        let maxY = min(rows, origin.y + size.height)

        for y in minY..<maxY {
            for x in minX..<maxX {
                terrainMap.setDistrict(at: x, y: y, district: district)
            }
        }
    }

    /// Paints a grid layout of districts, dividing the map into NxN cells
    /// where N = ceil(sqrt(districts.count))
    /// - Parameters:
    ///   - terrainMap: The terrain map to modify
    ///   - districts: Array of district types to lay out in grid order
    @MainActor
    public static func paintGrid(
        on terrainMap: TerrainMap,
        districts: [DistrictType]
    ) {
        guard !districts.isEmpty else { return }

        let (rows, cols) = terrainMap.dimensions
        let n = Int(ceil(sqrt(Double(districts.count))))

        let cellWidth = cols / n
        let cellHeight = rows / n

        for (index, district) in districts.enumerated() {
            let gridCol = index % n
            let gridRow = index / n
            guard gridRow < n else { break }

            let originX = gridCol * cellWidth
            let originY = gridRow * cellHeight

            // Last cell in each dimension absorbs remaining pixels
            let width = (gridCol == n - 1) ? (cols - originX) : cellWidth
            let height = (gridRow == n - 1) ? (rows - originY) : cellHeight

            paintRect(
                on: terrainMap,
                district: district,
                origin: (x: originX, y: originY),
                size: (width: width, height: height)
            )
        }
    }

    /// Paints the entire map with a single district type
    /// - Parameters:
    ///   - terrainMap: The terrain map to modify
    ///   - district: The district type to paint everywhere
    @MainActor
    public static func paintAll(
        on terrainMap: TerrainMap,
        district: DistrictType
    ) {
        let (rows, cols) = terrainMap.dimensions
        for y in 0..<rows {
            for x in 0..<cols {
                terrainMap.setDistrict(at: x, y: y, district: district)
            }
        }
    }
}
