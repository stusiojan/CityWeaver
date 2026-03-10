import Terrain

/// Generates local constraint rules from city state and terrain
@MainActor
class LocalConstraintGenerator {
    /// Generates rules based on current city state
    /// - Parameters:
    ///   - cityState: Current state of the city
    ///   - terrainMap: Terrain data
    ///   - config: Rule configuration
    /// - Returns: Array of local constraint rules
    func generateRules(
        from cityState: CityState, terrainMap: Terrain.TerrainMap, config: RuleConfiguration
    ) -> [LocalConstraintRule] {
        var rules: [LocalConstraintRule] = []

        // Always include boundary constraint
        rules.append(BoundaryConstraintRule(config: config))

        // Add terrain constraint
        rules.append(TerrainConstraintRule(config: config))

        // Add proximity constraint
        rules.append(ProximityConstraintRule(config: config))

        // Add angle constraint for mature cities
        if cityState.age > 0 {
            rules.append(AngleConstraintRule(config: config))
        }

        // Add district boundary rule
        rules.append(DistrictBoundaryRule(config: config))

        // Sort by priority
        return rules.sorted { $0.priority < $1.priority }
    }
}
