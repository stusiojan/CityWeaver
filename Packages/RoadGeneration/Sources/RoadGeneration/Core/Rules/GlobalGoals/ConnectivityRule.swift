import CoreGraphics
import Terrain

/// Connects districts with main roads
struct ConnectivityRule: GlobalGoalRule {
    var priority: Int = 8
    var applicabilityScope: RuleScope = .citywide
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return context.queryAttributes.isMainRoad
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        // Simplified - would need actual district center calculations
        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        // Main roads continue straight and branch less frequently
        let newRoadAttributes = RoadAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length,
            roadType: ra.roadType
        )

        let newQueryAttributes = QueryAttributes(
            startPoint: endPoint,
            angle: ra.angle,
            length: ra.length,
            roadType: ra.roadType,
            isMainRoad: true
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
