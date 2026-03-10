import CoreGraphics
import Foundation

/// Geometric properties of a road segment
/// Additional attributes like width, surface type, or elevation could be added here
public struct RoadAttributes: Codable, Sendable {
    /// Starting point of the road segment
    public let startPoint: CGPoint
    /// Direction angle in radians
    public let angle: Double
    /// Length of the road segment
    public let length: Double
    /// Type of road (highway, residential, etc.)
    public let roadType: String

    public init(startPoint: CGPoint, angle: Double, length: Double, roadType: String) {
        self.startPoint = startPoint
        self.angle = angle
        self.length = length
        self.roadType = roadType
    }

    /// Additional properties that could be added:
    /// - width: Double
    /// - surfaceType: RoadSurfaceType
    /// - elevation: Double
    /// - speedLimit: Int
    /// - lanes: Int
}
