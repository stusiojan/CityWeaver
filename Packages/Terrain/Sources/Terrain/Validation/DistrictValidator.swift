import Foundation

/// Validation error types for district assignments
public enum ValidationError: Sendable, Equatable {
    case districtNotConnected(DistrictType, fragmentCount: Int)
    case overlappingDistricts(x: Int, y: Int)
    case emptyDistrict(DistrictType)
    
    public var description: String {
        switch self {
        case .districtNotConnected(let district, let fragmentCount):
            "\(district.displayName) is fragmented into \(fragmentCount) separate areas"
        case .overlappingDistricts(let x, let y):
            "Overlapping districts at position (\(x), \(y))"
        case .emptyDistrict(let district):
            "\(district.displayName) has no assigned nodes"
        }
    }
}

/// Result of district validation
public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let errors: [ValidationError]
    
    public init(isValid: Bool, errors: [ValidationError]) {
        self.isValid = isValid
        self.errors = errors
    }
}

/// Validator for district assignments in terrain map
@MainActor
public struct DistrictValidator: Sendable {
    
    public init() {}
    
    /// Validate the district assignments in a terrain map
    /// - Parameter map: TerrainMap to validate
    /// - Returns: ValidationResult with any errors found
    public func validate(_ map: TerrainMap) -> ValidationResult {
        var errors: [ValidationError] = []
        
        // Check each district type
        for districtType in DistrictType.allCases {
            let nodes = map.getNodes(for: districtType)
            
            if nodes.isEmpty {
                // Skip empty districts - they're optional
                continue
            }
            
            // Check connectivity (all nodes should form a single connected region)
            let fragmentCount = countFragments(nodes: nodes, mapDimensions: map.dimensions)
            if fragmentCount > 1 {
                errors.append(.districtNotConnected(districtType, fragmentCount: fragmentCount))
            }
        }
        
        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors
        )
    }
    
    /// Count the number of disconnected fragments for a district
    private func countFragments(
        nodes: [(x: Int, y: Int, node: TerrainNode)],
        mapDimensions: (rows: Int, cols: Int)
    ) -> Int {
        guard !nodes.isEmpty else { return 0 }
        
        var visited = Set<String>()
        var fragmentCount = 0
        
        // Create a set of positions for quick lookup
        let positionSet = Set(nodes.map { "\($0.x),\($0.y)" })
        
        for node in nodes {
            let key = "\(node.x),\(node.y)"
            
            if !visited.contains(key) {
                // Start a new flood fill from this unvisited node
                floodFill(
                    start: (node.x, node.y),
                    positionSet: positionSet,
                    visited: &visited
                )
                fragmentCount += 1
            }
        }
        
        return fragmentCount
    }
    
    /// Flood fill to mark all connected nodes as visited
    private func floodFill(
        start: (x: Int, y: Int),
        positionSet: Set<String>,
        visited: inout Set<String>
    ) {
        var queue: [(Int, Int)] = [start]
        
        while !queue.isEmpty {
            let (x, y) = queue.removeFirst()
            let key = "\(x),\(y)"
            
            if visited.contains(key) {
                continue
            }
            
            if !positionSet.contains(key) {
                continue
            }
            
            visited.insert(key)
            
            // Check 4-connected neighbors (up, down, left, right)
            let neighbors = [
                (x - 1, y),
                (x + 1, y),
                (x, y - 1),
                (x, y + 1)
            ]
            
            for neighbor in neighbors {
                let neighborKey = "\(neighbor.0),\(neighbor.1)"
                if !visited.contains(neighborKey) && positionSet.contains(neighborKey) {
                    queue.append(neighbor)
                }
            }
        }
    }
}

