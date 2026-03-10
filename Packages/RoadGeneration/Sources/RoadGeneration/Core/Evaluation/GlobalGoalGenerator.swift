import Terrain

/// Generates global goal rules from city state and terrain
@MainActor
class GlobalGoalGenerator {
    /// Generates rules based on current city state
    /// - Parameters:
    ///   - cityState: Current state of the city
    ///   - terrainMap: Terrain data
    ///   - config: Rule configuration
    /// - Returns: Array of global goal rules
    func generateRules(
        from cityState: CityState, terrainMap: Terrain.TerrainMap, config: RuleConfiguration
    ) -> [GlobalGoalRule] {
        var rules: [GlobalGoalRule] = []

        // Always include district pattern rule
        rules.append(DistrictPatternRule(config: config))

        // Add coastal growth if city is near water
        rules.append(CoastalGrowthRule(config: config))

        // Add connectivity rule for established cities
        if cityState.age > 5 {
            rules.append(ConnectivityRule(config: config))
        }

        // Sort by priority
        return rules.sorted { $0.priority < $1.priority }
    }
}
