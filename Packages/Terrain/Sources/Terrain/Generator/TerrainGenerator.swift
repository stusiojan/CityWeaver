import Foundation

/// Parametric terrain generator for creating test terrains
public enum TerrainGenerator {

    /// Direction for slope generation
    public enum SlopeDirection: Sendable {
        case northToSouth
        case eastToWest
        case southToNorth
        case westToEast
    }

    // MARK: - Public API

    /// Creates flat terrain at uniform height
    /// - Parameters:
    ///   - cols: Number of columns
    ///   - rows: Number of rows
    ///   - height: Uniform elevation value (default 0)
    ///   - cellsize: Size of each grid cell in meters (default 1)
    /// - Returns: A TerrainMap with flat terrain
    @MainActor
    public static func flat(
        cols: Int,
        rows: Int,
        height: Double = 0,
        cellsize: Double = 1
    ) -> TerrainMap {
        let heights = Array(repeating: Array(repeating: height, count: cols), count: rows)
        return buildTerrainMap(from: heights, cellsize: cellsize)
    }

    /// Creates terrain with a linear gradient slope
    /// - Parameters:
    ///   - cols: Number of columns
    ///   - rows: Number of rows
    ///   - fromHeight: Starting elevation
    ///   - toHeight: Ending elevation
    ///   - direction: Direction of the gradient (default northToSouth)
    ///   - cellsize: Size of each grid cell in meters (default 1)
    /// - Returns: A TerrainMap with linearly sloped terrain
    @MainActor
    public static func slope(
        cols: Int,
        rows: Int,
        fromHeight: Double,
        toHeight: Double,
        direction: SlopeDirection = .northToSouth,
        cellsize: Double = 1
    ) -> TerrainMap {
        var heights = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                let t: Double
                switch direction {
                case .northToSouth:
                    t = rows > 1 ? Double(row) / Double(rows - 1) : 0
                case .southToNorth:
                    t = rows > 1 ? Double(rows - 1 - row) / Double(rows - 1) : 0
                case .westToEast:
                    t = cols > 1 ? Double(col) / Double(cols - 1) : 0
                case .eastToWest:
                    t = cols > 1 ? Double(cols - 1 - col) / Double(cols - 1) : 0
                }
                heights[row][col] = fromHeight + (toHeight - fromHeight) * t
            }
        }

        return buildTerrainMap(from: heights, cellsize: cellsize)
    }

    /// Creates hilly terrain using sine waves
    /// - Parameters:
    ///   - cols: Number of columns
    ///   - rows: Number of rows
    ///   - baseHeight: Base elevation (default 100)
    ///   - amplitude: Height variation amplitude (default 50)
    ///   - frequency: Wave frequency (default 0.05)
    ///   - cellsize: Size of each grid cell in meters (default 1)
    /// - Returns: A TerrainMap with hilly terrain
    @MainActor
    public static func hilly(
        cols: Int,
        rows: Int,
        baseHeight: Double = 100,
        amplitude: Double = 50,
        frequency: Double = 0.05,
        cellsize: Double = 1
    ) -> TerrainMap {
        var heights = Array(repeating: Array(repeating: 0.0, count: cols), count: rows)

        for row in 0..<rows {
            for col in 0..<cols {
                heights[row][col] = sin(Double(col) * frequency) * sin(Double(row) * frequency) * amplitude + baseHeight
            }
        }

        return buildTerrainMap(from: heights, cellsize: cellsize)
    }

    // MARK: - Private Helpers

    /// Builds a TerrainMap from a 2D heights array, computing slope and urbanization factor per node
    @MainActor
    private static func buildTerrainMap(from heights: [[Double]], cellsize: Double) -> TerrainMap {
        let rows = heights.count
        let cols = heights[0].count

        let header = ASCHeader(
            ncols: cols,
            nrows: rows,
            xllcenter: 0,
            yllcenter: 0,
            cellsize: cellsize,
            nodataValue: -9999
        )

        var nodes: [[TerrainNode]] = []
        nodes.reserveCapacity(rows)

        for row in 0..<rows {
            var rowNodes: [TerrainNode] = []
            rowNodes.reserveCapacity(cols)

            for col in 0..<cols {
                let slopeValue = calculateSlope(at: col, y: row, heights: heights, cellsize: cellsize)
                let urbanization = max(0.0, 1.0 - slopeValue * 2.0)

                let node = TerrainNode(
                    coordinates: TerrainNode.Coordinates(
                        x: Double(col) * cellsize,
                        y: Double(row) * cellsize,
                        z: heights[row][col]
                    ),
                    slope: slopeValue,
                    urbanizationFactor: urbanization
                )
                rowNodes.append(node)
            }
            nodes.append(rowNodes)
        }

        return TerrainMap(header: header, nodes: nodes)
    }

    /// Calculate slope using Horn's method (3x3 Sobel kernel), matching TerrainCalculator's algorithm
    private static func calculateSlope(
        at x: Int,
        y: Int,
        heights: [[Double]],
        cellsize: Double
    ) -> Double {
        let rows = heights.count
        let cols = heights[0].count

        func getHeight(_ x: Int, _ y: Int) -> Double {
            let clampedY = min(max(y, 0), rows - 1)
            let clampedX = min(max(x, 0), cols - 1)
            return heights[clampedY][clampedX]
        }

        let a = getHeight(x - 1, y - 1)
        let b = getHeight(x, y - 1)
        let c = getHeight(x + 1, y - 1)
        let d = getHeight(x - 1, y)
        let f = getHeight(x + 1, y)
        let g = getHeight(x - 1, y + 1)
        let h = getHeight(x, y + 1)
        let i = getHeight(x + 1, y + 1)

        let dzdx = ((c + 2 * f + i) - (a + 2 * d + g)) / (8 * cellsize)
        let dzdy = ((g + 2 * h + i) - (a + 2 * b + c)) / (8 * cellsize)

        let slopeRadians = atan(sqrt(dzdx * dzdx + dzdy * dzdy))
        let normalizedSlope = min(1.0, slopeRadians / (.pi / 4))

        return max(0.0, normalizedSlope)
    }
}
