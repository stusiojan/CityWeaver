import Foundation

/// Represents a single point in the terrain grid (1x1m resolution)
public struct TerrainNode: Sendable, Codable {
    /// World coordinates (x, y, z) position
    public let coordinates: Coordinates
    
    /// Terrain steepness (0-1, where 0 is flat and 1 is 45° or steeper)
    public let slope: Double
    
    /// Buildability factor (0-1, where 1 is most suitable for construction)
    public let urbanizationFactor: Double
    
    /// District classification (set by user)
    public var district: DistrictType?
    
    public struct Coordinates: Sendable, Codable {
        public let x: Double
        public let y: Double
        public let z: Double
        
        public init(x: Double, y: Double, z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }
    
    public init(
        coordinates: Coordinates,
        slope: Double,
        urbanizationFactor: Double,
        district: DistrictType? = nil
    ) {
        self.coordinates = coordinates
        self.slope = slope
        self.urbanizationFactor = urbanizationFactor
        self.district = district
    }
}

