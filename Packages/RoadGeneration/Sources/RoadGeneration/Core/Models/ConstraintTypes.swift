import Terrain

/// Result state from local constraint validation
enum ConstraintState {
    case succeed
    case failed
}

// Using DistrictType from Terrain package
// Note: Terrain.DistrictType has: business, oldTown, residential, industrial, park
// We extend it here to add mappings for RGA-specific types
extension Terrain.DistrictType {
    /// Map to RGA district patterns (coastal and undefined map to existing types)
    var rgaPattern: Terrain.DistrictType {
        return self
    }

    /// Check if this is a coastal-like district
    var isCoastal: Bool {
        // In future, this could be determined by proximity to water
        return false
    }
}

/// Scope of rule application
enum RuleScope {
    case citywide
    case district(Terrain.DistrictType)
    case segmentSpecific
}

/// Result from constraint evaluation with optional adjustments
struct ConstraintResult {
    let state: ConstraintState
    let adjustedQuery: QueryAttributes
    let reason: String?

    init(state: ConstraintState, adjustedQuery: QueryAttributes, reason: String? = nil) {
        self.state = state
        self.adjustedQuery = adjustedQuery
        self.reason = reason
    }
}

/// Proposal for a new road segment
struct RoadProposal {
    let roadAttributes: RoadAttributes
    let queryAttributes: QueryAttributes
    let delay: Int
}
