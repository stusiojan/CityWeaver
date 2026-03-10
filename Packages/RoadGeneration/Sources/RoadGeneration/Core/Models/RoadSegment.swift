import CoreGraphics
import Foundation

/// A confirmed, immutable road segment that has passed all validation
/// Additional metadata like construction date or usage statistics could be added
public struct RoadSegment: Codable, Sendable {
    /// Unique identifier for the segment
    public let id: UUID
    /// Final geometric properties
    public let attributes: RoadAttributes
    /// Timestamp when segment was created
    public let createdAt: Int

    /// Additional properties that could be added:
    /// - trafficFlow: Double
    /// - maintenanceSchedule: [Date]
    /// - connectedSegments: Set<UUID>
    /// - buildCost: Double

    public init(attributes: RoadAttributes, createdAt: Int) {
        self.id = UUID()
        self.attributes = attributes
        self.createdAt = createdAt
    }
}
