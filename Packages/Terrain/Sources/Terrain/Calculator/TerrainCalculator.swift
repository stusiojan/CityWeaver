import Foundation

/// Calculator for terrain-related metrics like slope and urbanization factor
public struct TerrainCalculator: Sendable {
    
    public init() {}
    
    /// Calculate slope at a specific grid position using Horn's method (Sobel operator)
    /// - Parameters:
    ///   - x: Column index
    ///   - y: Row index
    ///   - heights: 2D array of elevation values
    ///   - cellsize: Size of each grid cell in meters
    /// - Returns: Slope value normalized to 0-1 (where 1 = 45° or steeper)
    public func calculateSlope(
        at x: Int,
        y: Int,
        heights: [[Double]],
        cellsize: Double
    ) -> Double {
        let rows = heights.count
        let cols = heights[0].count
        
        // Helper to safely get height at position
        func getHeight(_ x: Int, _ y: Int) -> Double {
            guard y >= 0, y < rows, x >= 0, x < cols else {
                return heights[y.clamped(to: 0..<rows)][x.clamped(to: 0..<cols)]
            }
            return heights[y][x]
        }
        
        // Get 8 neighbors for Horn's method
        let a = getHeight(x - 1, y - 1)  // top-left
        let b = getHeight(x, y - 1)      // top
        let c = getHeight(x + 1, y - 1)  // top-right
        let d = getHeight(x - 1, y)      // left
        let f = getHeight(x + 1, y)      // right
        let g = getHeight(x - 1, y + 1)  // bottom-left
        let h = getHeight(x, y + 1)      // bottom
        let i = getHeight(x + 1, y + 1)  // bottom-right
        
        // Calculate gradients using Sobel operator
        let dzdx = ((c + 2 * f + i) - (a + 2 * d + g)) / (8 * cellsize)
        let dzdy = ((g + 2 * h + i) - (a + 2 * b + c)) / (8 * cellsize)
        
        // Calculate slope in radians
        let slopeRadians = atan(sqrt(dzdx * dzdx + dzdy * dzdy))
        
        // Normalize to 0-1 range (45 degrees = 1.0)
        let normalizedSlope = min(1.0, slopeRadians / (.pi / 4))
        
        return max(0.0, normalizedSlope)
    }
    
    /// Calculate urbanization factor based on slope
    /// Flatter terrain is more suitable for construction
    /// - Parameter slope: Slope value (0-1)
    /// - Returns: Urbanization factor (0-1, where 1 is most suitable)
    public func calculateUrbanizationFactor(from slope: Double) -> Double {
        // Simple formula: flatter = better for building
        // Can be extended with other factors (water proximity, soil type, etc.)
        return max(0.0, 1.0 - slope * 2.0)
    }
}

// Helper extension for clamping values
private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1)
    }
}

