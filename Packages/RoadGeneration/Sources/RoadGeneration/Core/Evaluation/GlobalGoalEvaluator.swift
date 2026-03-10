import Terrain

/// Evaluates global goals using rule collection
@MainActor
class GlobalGoalEvaluator {
    private var rules: [GlobalGoalRule]

    init(rules: [GlobalGoalRule]) {
        self.rules = rules
    }

    /// Updates the rule set
    func updateRules(_ newRules: [GlobalGoalRule]) {
        self.rules = newRules.sorted { $0.priority < $1.priority }
    }

    /// Generates proposals from all applicable rules
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
    {
        var allProposals: [RoadProposal] = []

        for rule in rules {
            if rule.applies(to: context) {
                let proposals = rule.generateProposals(qa, ra, context: context)
                allProposals.append(contentsOf: proposals)
            }
        }

        return allProposals
    }
}
