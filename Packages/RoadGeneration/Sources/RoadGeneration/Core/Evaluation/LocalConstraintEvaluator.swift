import Terrain

/// Evaluates local constraints using rule collection
@MainActor
class LocalConstraintEvaluator {
    private var rules: [LocalConstraintRule]

    init(rules: [LocalConstraintRule]) {
        self.rules = rules
    }

    /// Updates the rule set
    func updateRules(_ newRules: [LocalConstraintRule]) {
        self.rules = newRules.sorted { $0.priority < $1.priority }
    }

    /// Evaluates all applicable rules, returning the failure reason when rejected
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> (
        QueryAttributes, ConstraintState, String?
    ) {
        var currentQuery = qa

        for rule in rules {
            if rule.applies(to: context) {
                let result = rule.evaluate(currentQuery, context: context)

                if result.state == .failed {
                    return (result.adjustedQuery, .failed, result.reason)
                }

                currentQuery = result.adjustedQuery
            }
        }

        return (currentQuery, .succeed, nil)
    }
}
