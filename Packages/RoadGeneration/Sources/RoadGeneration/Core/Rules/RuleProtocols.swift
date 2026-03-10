import Terrain

/// Protocol for local constraint rules that validate road proposals
@MainActor
protocol LocalConstraintRule {
    /// Priority for rule evaluation (lower = higher priority)
    var priority: Int { get }
    /// Scope of applicability
    var applicabilityScope: RuleScope { get }
    /// Configuration reference
    var config: RuleConfiguration { get set }

    /// Check if rule applies to given context
    func applies(to context: GenerationContext) -> Bool

    /// Evaluate the constraint
    func evaluate(_ qa: QueryAttributes, context: GenerationContext) -> ConstraintResult
}

/// Protocol for global goal rules that generate new road proposals
@MainActor
protocol GlobalGoalRule {
    /// Priority for rule evaluation (lower = higher priority)
    var priority: Int { get }
    /// Scope of applicability
    var applicabilityScope: RuleScope { get }
    /// Configuration reference
    var config: RuleConfiguration { get set }

    /// Check if rule applies to given context
    func applies(to context: GenerationContext) -> Bool

    /// Generate new road proposals
    func generateProposals(_ qa: QueryAttributes, _ ra: RoadAttributes, context: GenerationContext)
        -> [RoadProposal]
}
