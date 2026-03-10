import CoreGraphics
import Terrain

/// Handles district boundary transitions
struct DistrictBoundaryRule: LocalConstraintRule {
    var priority: Int = 30
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        guard let startNode = context.terrainMap.getNode(at: Int(qa.startPoint.x), y: Int(qa.startPoint.y)) else {
            return ConstraintResult(state: .succeed, adjustedQuery: qa)
        }

        let endPoint = CGPoint(
            x: qa.startPoint.x + cos(qa.angle) * qa.length,
            y: qa.startPoint.y + sin(qa.angle) * qa.length
        )

        guard let endNode = context.terrainMap.getNode(at: Int(endPoint.x), y: Int(endPoint.y)) else {
            return ConstraintResult(state: .succeed, adjustedQuery: qa)
        }

        // Reject roads that end in areas without a defined district
        if endNode.district == nil {
            return ConstraintResult(state: .failed, adjustedQuery: qa, reason: "No district defined")
        }

        // Hard transition - roads cannot cross district boundaries (except main roads)
        if startNode.district != endNode.district && !qa.isMainRoad {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Cannot cross district boundary")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}
