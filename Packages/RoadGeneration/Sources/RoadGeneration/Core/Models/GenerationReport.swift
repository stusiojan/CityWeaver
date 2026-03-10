import Foundation

/// Diagnostic report returned alongside generated road segments
public struct GenerationReport: Sendable {
    /// Total number of proposals evaluated by constraint rules
    public let totalProposalsEvaluated: Int
    /// Number of proposals that passed all constraints
    public let totalAccepted: Int
    /// Number of proposals rejected by constraints
    public let totalFailed: Int
    /// Breakdown of failures by constraint rule name
    public let failuresByConstraint: [String: Int]
    /// Wall-clock time for the generation pass
    public let processingTimeSeconds: TimeInterval
    /// Human-readable summary of the generation run
    public let diagnosticMessage: String
    /// Actionable suggestions when the result is poor (e.g. 0 roads)
    public let suggestedFixes: [String]

    /// Builds a report from raw counters collected during generation
    public static func build(
        evaluated: Int,
        accepted: Int,
        failures: [String: Int],
        processingTime: TimeInterval
    ) -> GenerationReport {
        let failed = evaluated - accepted
        var suggestions: [String] = []

        if accepted == 0 {
            suggestions.append("Check that the initial road start point is inside cityBounds")
        }

        // Analyse dominant failure reason
        if let (topReason, topCount) = failures.max(by: { $0.value < $1.value }), topCount > 0 {
            let ratio = Double(topCount) / Double(max(failed, 1))
            if ratio > 0.4 {
                switch topReason {
                case "Outside city bounds":
                    suggestions.append(
                        "Most failures are boundary violations — verify cityBounds matches terrain size"
                    )
                case "Slope too steep":
                    suggestions.append(
                        "Many roads rejected for steep slope — try increasing maxBuildableSlope"
                    )
                case "Too close to existing road":
                    suggestions.append(
                        "Many proximity failures — try decreasing minimumRoadDistance"
                    )
                case "Low urbanization factor":
                    suggestions.append(
                        "Low urbanization rejections — try decreasing minUrbanizationFactor"
                    )
                default:
                    break
                }
            }
        }

        let message: String
        if accepted == 0 {
            message = "No roads generated. \(evaluated) proposals evaluated, all rejected."
        } else {
            let acceptRate = Double(accepted) / Double(max(evaluated, 1)) * 100
            message = "\(accepted) roads generated from \(evaluated) proposals (accept rate: \(String(format: "%.1f", acceptRate))%). Time: \(String(format: "%.3f", processingTime))s"
        }

        return GenerationReport(
            totalProposalsEvaluated: evaluated,
            totalAccepted: accepted,
            totalFailed: failed,
            failuresByConstraint: failures,
            processingTimeSeconds: processingTime,
            diagnosticMessage: message,
            suggestedFixes: suggestions
        )
    }
}
