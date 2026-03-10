import CoreGraphics
import Terrain

/// Prevents roads from being too close to each other
struct ProximityConstraintRule: LocalConstraintRule {
    var priority: Int = 25
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return !context.existingInfrastructure.isEmpty
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let proposedEnd = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        for segment in context.existingInfrastructure {
            let existingEnd = CGPoint(
                x: segment.attributes.startPoint.x + cos(segment.attributes.angle)
                    * segment.attributes.length,
                y: segment.attributes.startPoint.y + sin(segment.attributes.angle)
                    * segment.attributes.length
            )

            let distance = sqrt(
                pow(proposedEnd.x - existingEnd.x, 2) + pow(proposedEnd.y - existingEnd.y, 2)
            )

            if distance < config.minimumRoadDistance {
                return ConstraintResult(
                    state: .failed, adjustedQuery: qa, reason: "Too close to existing road")
            }
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}
