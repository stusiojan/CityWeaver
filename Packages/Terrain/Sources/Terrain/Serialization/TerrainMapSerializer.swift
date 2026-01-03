import Foundation

/// Serializer for saving and loading TerrainMap to/from JSON
@MainActor
public struct TerrainMapSerializer: Sendable {
    
    public init() {}
    
    /// Serializable representation of TerrainMap
    private struct SerializableTerrainMap: Codable {
        let header: ASCHeader
        let nodes: [[SerializableNode]]
        
        struct SerializableNode: Codable {
            let x: Double
            let y: Double
            let z: Double
            let slope: Double
            let urbanizationFactor: Double
            let district: DistrictType?
        }
    }
    
    /// Export TerrainMap to JSON file
    /// - Parameters:
    ///   - map: TerrainMap to export
    ///   - url: Destination file URL
    /// - Throws: Error if encoding or writing fails
    public func export(_ map: TerrainMap, to url: URL) throws {
        // Convert TerrainMap to serializable format
        let serializableNodes: [[SerializableTerrainMap.SerializableNode]] = map.nodes.map { row in
            row.map { node in
                SerializableTerrainMap.SerializableNode(
                    x: node.coordinates.x,
                    y: node.coordinates.y,
                    z: node.coordinates.z,
                    slope: node.slope,
                    urbanizationFactor: node.urbanizationFactor,
                    district: node.district
                )
            }
        }
        
        let serializableMap = SerializableTerrainMap(
            header: map.header,
            nodes: serializableNodes
        )
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(serializableMap)
        
        // Write to file
        try data.write(to: url)
    }
    
    /// Import TerrainMap from JSON file
    /// - Parameter url: Source file URL
    /// - Returns: Reconstructed TerrainMap
    /// - Throws: Error if reading or decoding fails
    public func `import`(from url: URL) throws -> TerrainMap {
        // Read file
        let data = try Data(contentsOf: url)
        
        // Decode JSON
        let decoder = JSONDecoder()
        let serializableMap = try decoder.decode(SerializableTerrainMap.self, from: data)
        
        // Convert back to TerrainMap
        let nodes: [[TerrainNode]] = serializableMap.nodes.map { row in
            row.map { serializableNode in
                TerrainNode(
                    coordinates: TerrainNode.Coordinates(
                        x: serializableNode.x,
                        y: serializableNode.y,
                        z: serializableNode.z
                    ),
                    slope: serializableNode.slope,
                    urbanizationFactor: serializableNode.urbanizationFactor,
                    district: serializableNode.district
                )
            }
        }
        
        return TerrainMap(
            header: serializableMap.header,
            nodes: nodes
        )
    }
}

