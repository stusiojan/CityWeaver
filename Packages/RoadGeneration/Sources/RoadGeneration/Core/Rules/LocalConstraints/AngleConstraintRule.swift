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

            // For non-connected nearby segments, check intersection angle
            // Check distance from both startPoint and endpoint of existing segment
            let distanceFromStart = sqrt(
                pow(segment.attributes.startPoint.x - qa.startPoint.x, 2)
                    + pow(segment.attributes.startPoint.y - qa.startPoint.y, 2)
            )
            let distanceFromEnd = sqrt(
                pow(existingEnd.x - qa.startPoint.x, 2) + pow(existingEnd.y - qa.startPoint.y, 2)
            )
            let distance = min(distanceFromStart, distanceFromEnd)

            if distance < config.intersectionMinSpacing {
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
}
