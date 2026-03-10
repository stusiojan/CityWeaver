import CoreGraphics
import Terrain

/// Context for road generation containing all necessary state
/// Additional contextual information could be added here
struct GenerationContext {
    /// Current location being evaluated
    let currentLocation: CGPoint
    /// Terrain data
    let terrainMap: Terrain.TerrainMap
    /// Current city state
    let cityState: CityState
    /// Already generated road segments
    let existingInfrastructure: [RoadSegment]
    /// The query being evaluated
    let queryAttributes: QueryAttributes

    /// Additional properties that could be added:
    /// - timeOfDay: TimeInterval
    /// - season: Season
    /// - weatherConditions: Weather
    /// - nearbyBuildings: [Building]
}
