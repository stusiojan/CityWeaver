import CoreGraphics
import Terrain

/// Central configuration for all rule parameters - single source of truth
/// All rule-related parameters should be defined here
public struct RuleConfiguration {
    // Boundary constraints
    public var cityBounds: CGRect = CGRect(
        origin: CGPoint(x: 0, y: 0), size: CGSize(width: 1000, height: 1000))

    // Angle constraints (in radians)
    /// Maximum random angle perturbation applied to branch proposals (radians).
    /// Set to 0 to disable jitter (deterministic). Recommended: 5–15° for organic patterns.
    public var angleJitter: Double = 0

    public var mainRoadAngleMin: Double = 45 * .pi / 180
    public var mainRoadAngleMax: Double = 170 * .pi / 180
    public var internalRoadAngleMin: Double = 30 * .pi / 180
    public var internalRoadAngleMax: Double = 180 * .pi / 180

    // Distance constraints
    public var minimumRoadDistance: Double = 10.0
    public var intersectionMinSpacing: Double = 30.0

    // Terrain constraints
    public var maxBuildableSlope: Double = 0.3
    public var minUrbanizationFactor: Double = 0.2

    // Global goal parameters
    public var branchingProbability: [Terrain.DistrictType: Double] = [
        .business: 0.7,
        .oldTown: 0.9,
        .residential: 0.6,
        .industrial: 0.5,
        .park: 0.3,
    ]

    public var roadLengthMultiplier: [Terrain.DistrictType: Double] = [
        .business: 1.0,
        .oldTown: 0.6,
        .residential: 0.8,
        .industrial: 1.2,
        .park: 0.5,
    ]

    public var branchingAngles: [Terrain.DistrictType: [Double]] = [
        .business: [0, .pi / 2, -.pi / 2],  // Grid pattern
        .oldTown: [0, .pi / 6, -.pi / 6, .pi / 4, -.pi / 4],  // Organic
        .residential: [0, .pi / 2, -.pi / 2],
        .industrial: [0, .pi / 2, -.pi / 2],
        .park: [0, .pi / 4, -.pi / 4],
    ]

    // Coastal development
    public var coastalGrowthBias: Double = 0.8

    // Delays
    public var defaultDelay: Int = 1
    public var branchDelay: Int = 3

    public init() {}

    /// Additional parameters that could be added:
    /// - zoneDensityFactors: [DistrictType: Double]
    /// - roadWidths: [String: Double]
    /// - trafficFlowParameters: TrafficConfig
    /// - seasonalModifiers: SeasonalConfig
}
