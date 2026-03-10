/// Current state of the city simulation
/// Additional city-wide metrics could be added here
public struct CityState {
    /// Total population
    public var population: Int
    /// Population per square kilometer
    public var density: Double
    /// Economic development level (0-1)
    public var economicLevel: Double
    /// City age in simulation years
    public var age: Int

    /// Additional properties that could be added:
    /// - gdp: Double
    /// - trafficCongestion: Double
    /// - pollutionLevel: Double
    /// - housingDemand: Double
    /// - employmentRate: Double

    /// Flag indicating if rules need regeneration
    public var needsRuleRegeneration: Bool = true

    /// Marks that rules should be regenerated on next iteration
    public mutating func markDirty() {
        needsRuleRegeneration = true
    }

    public init(population: Int, density: Double, economicLevel: Double, age: Int) {
        self.population = population
        self.density = density
        self.economicLevel = economicLevel
        self.age = age
    }
}
