import CoreGraphics
import Foundation

/// A proposal to create a new road segment in the priority queue
/// Additional metadata like creation timestamp or source could be added
struct RoadQuery: Comparable {
    /// Priority timestamp - lower values processed first
    let time: Int
    /// Final geometric properties of the proposed road
    let roadAttributes: RoadAttributes
    /// Query data for validation
    let queryAttributes: QueryAttributes

    /// Additional properties that could be added:
    /// - sourceSegmentId: UUID?
    /// - generationReason: String
    /// - estimatedBuildTime: TimeInterval

    static func < (lhs: RoadQuery, rhs: RoadQuery) -> Bool {
        return lhs.time < rhs.time
    }

    static func == (lhs: RoadQuery, rhs: RoadQuery) -> Bool {
        return lhs.time == rhs.time
    }
}
