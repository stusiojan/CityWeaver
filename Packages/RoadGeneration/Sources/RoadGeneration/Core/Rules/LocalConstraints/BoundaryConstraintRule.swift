import CoreGraphics
import Terrain

/// Validates that roads stay within city boundaries
struct BoundaryConstraintRule: LocalConstraintRule {
    var priority: Int = 10
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true  // Always applies
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let endPoint = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        if !config.cityBounds.contains(qa.startPoint) || !config.cityBounds.contains(endPoint) {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Outside city bounds")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}
