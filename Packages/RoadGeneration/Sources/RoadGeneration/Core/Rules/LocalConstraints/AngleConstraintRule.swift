import CoreGraphics
import Terrain

/// Validates intersection angles based on road type
struct AngleConstraintRule: LocalConstraintRule {
    var priority: Int = 20
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return !context.existingInfrastructure.isEmpty
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let minAngle = qa.isMainRoad ? config.mainRoadAngleMin : config.internalRoadAngleMin
        let maxAngle = qa.isMainRoad ? config.mainRoadAngleMax : config.internalRoadAngleMax

        // Check angles with nearby existing roads
        for segment in context.existingInfrastructure {
            // Calculate endpoint of existing segment
            let existingEnd = CGPoint(
                x: segment.attributes.startPoint.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: segment.attributes.startPoint.y + sin(segment.attributes.angle) * segment.attributes.length
            )

            // Check if this is a continuation (proposed start ≈ existing endpoint)
            let continuationDistance = sqrt(
                pow(existingEnd.x - qa.startPoint.x, 2) + pow(existingEnd.y - qa.startPoint.y, 2)
            )
            if continuationDistance < 1.0 {
                // This is a connected continuation — skip angle check for this segment
                continue
            }

            // Skip siblings — segments that share the same origin (branched from same point)
            let siblingDistance = sqrt(
                pow(segment.attributes.startPoint.x - qa.startPoint.x, 2)
                + pow(segment.attributes.startPoint.y - qa.startPoint.y, 2)
            )
            if siblingDistance < 1.0 {
                continue
            }

            // Only check intersection angle when the two segments' paths actually come close.
            // This prevents false rejections of parallel roads in the same corridor (chain continuations)
            // that happen to have nearby start/endpoints but never intersect.
            let proposedEnd = CGPoint(
                x: qa.startPoint.x + cos(qa.angle) * qa.length,
                y: qa.startPoint.y + sin(qa.angle) * qa.length
            )
            let segmentDistance = Self.minimumSegmentDistance(
                p1: qa.startPoint, p2: proposedEnd,
                q1: segment.attributes.startPoint, q2: existingEnd
            )

            if segmentDistance < config.minimumRoadDistance {
                let angleDiff = abs(qa.angle - segment.attributes.angle)
                let normalizedAngle = min(angleDiff, 2 * .pi - angleDiff)

                let epsilon = 2 * Double.pi / 180  // 2° floating-point tolerance
                if normalizedAngle < (minAngle - epsilon) || normalizedAngle > (maxAngle + epsilon) {
                    return ConstraintResult(
                        state: .failed, adjustedQuery: qa, reason: "Invalid intersection angle")
                }
            }
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }

    /// Minimum distance between two line segments [p1→p2] and [q1→q2].
    /// Returns 0 if segments intersect, otherwise the shortest distance
    /// between any point on one segment and any point on the other.
    private static func minimumSegmentDistance(
        p1: CGPoint, p2: CGPoint, q1: CGPoint, q2: CGPoint
    ) -> Double {
        // Check all four point-to-segment distances and segment intersection
        let d1 = pointToSegmentDistance(point: p1, segA: q1, segB: q2)
        let d2 = pointToSegmentDistance(point: p2, segA: q1, segB: q2)
        let d3 = pointToSegmentDistance(point: q1, segA: p1, segB: p2)
        let d4 = pointToSegmentDistance(point: q2, segA: p1, segB: p2)
        return min(min(d1, d2), min(d3, d4))
    }

    /// Distance from a point to the closest point on a line segment.
    private static func pointToSegmentDistance(point: CGPoint, segA: CGPoint, segB: CGPoint) -> Double {
        let dx = segB.x - segA.x
        let dy = segB.y - segA.y
        let lengthSq = dx * dx + dy * dy

        if lengthSq < 1e-10 {
            // Degenerate segment (zero length)
            return sqrt(pow(point.x - segA.x, 2) + pow(point.y - segA.y, 2))
        }

        // Project point onto the line, clamped to [0,1]
        let t = max(0, min(1, ((point.x - segA.x) * dx + (point.y - segA.y) * dy) / lengthSq))
        let projX = segA.x + t * dx
        let projY = segA.y + t * dy

        return sqrt(pow(point.x - projX, 2) + pow(point.y - projY, 2))
    }
}
