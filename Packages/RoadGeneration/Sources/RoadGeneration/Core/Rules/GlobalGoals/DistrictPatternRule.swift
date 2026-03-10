import CoreGraphics
import Terrain

/// Generates roads based on district-specific patterns
struct DistrictPatternRule: GlobalGoalRule {
    var priority: Int = 10
    var applicabilityScope: RuleScope = .segmentSpecific
    var config: RuleConfiguration

    func applies(to context: GenerationContext) -> Bool {
        return true
    }

    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        guard let node = context.terrainMap.getNode(at: Int(ra.startPoint.x), y: Int(ra.startPoint.y)) else {
            return []
        }

        let district = node.district ?? .residential  // Default to residential if no district set
        let probability = config.branchingProbability[district] ?? 0.5
        let lengthMultiplier = config.roadLengthMultiplier[district] ?? 0.8
        let angles = config.branchingAngles[district] ?? [0, .pi / 4, -.pi / 4]

        var proposals: [RoadProposal] = []

        let endPoint = CGPoint(
            x: ra.startPoint.x + cos(ra.angle) * ra.length,
            y: ra.startPoint.y + sin(ra.angle) * ra.length
        )

        for (index, angleOffset) in angles.enumerated() {
            if Double.random(in: 0...1) > probability {
                continue
            }

            let newAngle = ra.angle + angleOffset
            let newLength = max(ra.length * lengthMultiplier, config.minimumRoadDistance)

            let newRoadAttributes = RoadAttributes(
                startPoint: endPoint,
                angle: newAngle,
                length: newLength,
                roadType: ra.roadType
            )

            let newQueryAttributes = QueryAttributes(
                startPoint: endPoint,
                angle: newAngle,
                length: newLength,
                roadType: ra.roadType,
                isMainRoad: qa.isMainRoad
            )

            let delay = index == 0 ? config.defaultDelay : config.branchDelay

            proposals.append(
                RoadProposal(
                    roadAttributes: newRoadAttributes,
                    queryAttributes: newQueryAttributes,
                    delay: delay
                ))
        }

        return proposals
    }
}
