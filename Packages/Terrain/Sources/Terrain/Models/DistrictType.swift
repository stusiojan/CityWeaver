import Foundation

/// Enum representing different types of city districts
public enum DistrictType: String, CaseIterable, Codable, Sendable {
    case business
    case oldTown
    case residential
    case industrial
    case park
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .business: "Business"
        case .oldTown: "Old Town"
        case .residential: "Residential"
        case .industrial: "Industrial"
        case .park: "Park"
        }
    }
}

