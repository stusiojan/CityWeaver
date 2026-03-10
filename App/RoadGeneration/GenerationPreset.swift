import Foundation
import RoadGeneration

/// Pre-configured parameter sets for common generation scenarios
enum GenerationPreset: String, CaseIterable, Identifiable {
    case quickTest = "Quick Test"
    case smallVillage = "Small Village"
    case mediumCity = "Medium City"
    case largeCity = "Large City"

    var id: String { rawValue }

    var cityState: CityState {
        switch self {
        case .quickTest:
            CityState(population: 5_000, density: 800, economicLevel: 0.4, age: 5)
        case .smallVillage:
            CityState(population: 15_000, density: 1_000, economicLevel: 0.5, age: 20)
        case .mediumCity:
            CityState(population: 50_000, density: 1_500, economicLevel: 0.6, age: 50)
        case .largeCity:
            CityState(population: 200_000, density: 3_000, economicLevel: 0.8, age: 100)
        }
    }

    var ruleConfiguration: RuleConfiguration {
        var config = RuleConfiguration()
        switch self {
        case .quickTest:
            config.minimumRoadDistance = 5.0
            config.maxBuildableSlope = 0.5
        case .smallVillage:
            config.minimumRoadDistance = 8.0
        case .mediumCity:
            break // defaults are fine
        case .largeCity:
            config.minimumRoadDistance = 12.0
            config.intersectionMinSpacing = 60.0
        }
        return config
    }

    var initialRoadLength: Double {
        switch self {
        case .quickTest: 10
        case .smallVillage: 15
        case .mediumCity: 20
        case .largeCity: 30
        }
    }

    /// Suggested terrain map size for this preset
    var recommendedMapInfo: String {
        switch self {
        case .quickTest: "Recommended: 50×50 or larger"
        case .smallVillage: "Recommended: 100×100 or larger"
        case .mediumCity: "Recommended: 200×200 or larger"
        case .largeCity: "Recommended: 500×500 or larger"
        }
    }
}
