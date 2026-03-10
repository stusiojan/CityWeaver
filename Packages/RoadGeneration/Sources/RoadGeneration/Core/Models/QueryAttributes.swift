import CoreGraphics

/// Data associated with a road building request
/// Similar to RoadAttributes but represents a proposal rather than final geometry
/// Additional validation data or metadata could be added here
public struct QueryAttributes {
    /// Starting point of the proposed road
    public let startPoint: CGPoint
    /// Direction angle in radians
    public let angle: Double
    /// Proposed length of the road segment
    public let length: Double
    /// Type of road being proposed
    public let roadType: String
    /// Whether this is a main road in the district
    public let isMainRoad: Bool

    /// Additional properties that could be added:
    /// - priority: Int
    /// - requesterType: RoadRequesterType
    /// - buildCost: Double
    /// - environmentalImpact: Double
    /// - populationDensityRequirement: Double

    public init(
        startPoint: CGPoint, angle: Double, length: Double, roadType: String,
        isMainRoad: Bool = false
    ) {
        self.startPoint = startPoint
        self.angle = angle
        self.length = length
        self.roadType = roadType
        self.isMainRoad = isMainRoad
    }
}
