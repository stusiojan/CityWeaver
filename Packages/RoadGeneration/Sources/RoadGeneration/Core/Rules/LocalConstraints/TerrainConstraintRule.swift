import CoreGraphics
import Terrain

/// Validates terrain suitability
struct TerrainConstraintRule: LocalConstraintRule {
    var priority: Int = 15
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    @MainActor func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
    {
        let gridX = Int(qa.startPoint.x)
        let gridY = Int(qa.startPoint.y)
        guard let node = context.terrainMap.getNode(at: gridX, y: gridY) else {
            return ConstraintResult(state: .failed, adjustedQuery: qa, reason: "No terrain data")
        }

        if node.slope > config.maxBuildableSlope {
            return ConstraintResult(state: .failed, adjustedQuery: qa, reason: "Slope too steep")
        }

        if node.urbanizationFactor < config.minUrbanizationFactor {
            return ConstraintResult(
                state: .failed, adjustedQuery: qa, reason: "Low urbanization factor")
        }

        return ConstraintResult(state: .succeed, adjustedQuery: qa)
    }
}
