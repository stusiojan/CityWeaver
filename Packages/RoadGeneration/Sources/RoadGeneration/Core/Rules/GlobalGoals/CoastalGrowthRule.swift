import CoreGraphics
import Terrain

/// Biases road growth along coastlines or rivers
struct CoastalGrowthRule: GlobalGoalRule {
    var priority: Int = 5
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        // Check if we're near coastal area (using extension property)
        guard let node = context.terrainMap.getNode(at: Int(context.currentLocation.x), y: Int(context.currentLocation.y)) else {
            return false
        }
        return node.district?.isCoastal ?? false
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        // Bias growth to follow coastline (simplified - would need actual coastline data)
        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        // Generate road that continues along coast
        let newRoadAttributes = RoadAttributes(
            startPoint: endPoint,
            angle: ra.angle,  // Keep same direction along coast
            length: ra.length * 0.9,
            roadType: ra.roadType
        )

        let newQueryAttributes = QueryAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length * 0.9,
            roadType: ra.roadType,
            isMainRoad: qa.isMainRoad
        )

        proposals.append(
            RoadProposal(
                roadAttributes: newRoadAttributes,
                queryAttributes: newQueryAttributes,
                delay: config.defaultDelay
            ))

        return proposals
    }
}
