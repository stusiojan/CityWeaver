import Foundation

/// Serializes and deserializes road networks to/from JSON format
public struct RoadNetworkSerializer: Sendable {
    
    /// Metadata about the road network generation
    public struct Metadata: Codable, Sendable {
        public let generatedAt: Date
        public let cityState: CityStateSnapshot
        public let configuration: ConfigurationSnapshot
        
        public init(generatedAt: Date, cityState: CityStateSnapshot, configuration: ConfigurationSnapshot) {
            self.generatedAt = generatedAt
            self.cityState = cityState
            self.configuration = configuration
        }
    }
    
    /// Snapshot of city state at generation time
    public struct CityStateSnapshot: Codable, Sendable {
        public let population: Int
        public let density: Double
        public let economicLevel: Double
        public let age: Int
        
        public init(population: Int, density: Double, economicLevel: Double, age: Int) {
            self.population = population
            self.density = density
            self.economicLevel = economicLevel
            self.age = age
        }
    }
    
    /// Snapshot of configuration at generation time
    public struct ConfigurationSnapshot: Codable, Sendable {
        public let maxBuildableSlope: Double
        public let minUrbanizationFactor: Double
        public let minimumRoadDistance: Double
        
        public init(maxBuildableSlope: Double, minUrbanizationFactor: Double, minimumRoadDistance: Double) {
            self.maxBuildableSlope = maxBuildableSlope
            self.minUrbanizationFactor = minUrbanizationFactor
            self.minimumRoadDistance = minimumRoadDistance
        }
    }
    
    /// Complete road network export structure
    public struct RoadNetworkExport: Codable, Sendable {
        public let metadata: Metadata
        public let roads: [RoadSegment]
        
        public init(metadata: Metadata, roads: [RoadSegment]) {
            self.metadata = metadata
            self.roads = roads
        }
    }
    
    public init() {}
    
    /// Export a road network to JSON data
    /// - Parameters:
    ///   - segments: Array of road segments to export
    ///   - cityState: City state at generation time
    ///   - config: Configuration used for generation
    /// - Returns: JSON data representation
    public func export(
        _ segments: [RoadSegment],
        cityState: CityStateSnapshot,
        configuration: ConfigurationSnapshot
    ) throws -> Data {
        let metadata = Metadata(
            generatedAt: Date(),
            cityState: cityState,
            configuration: configuration
        )
        
        let export = RoadNetworkExport(metadata: metadata, roads: segments)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(export)
    }
    
    /// Import a road network from JSON data
    /// - Parameter data: JSON data to decode
    /// - Returns: Tuple of road segments and metadata
    public func `import`(from data: Data) throws -> (roads: [RoadSegment], metadata: Metadata) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let export = try decoder.decode(RoadNetworkExport.self, from: data)
        return (roads: export.roads, metadata: export.metadata)
    }
    
    /// Export only the road segments (without metadata)
    /// - Parameter segments: Array of road segments to export
    /// - Returns: JSON data representation
    public func exportSimple(_ segments: [RoadSegment]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(segments)
    }
    
    /// Import only road segments (without metadata)
    /// - Parameter data: JSON data to decode
    /// - Returns: Array of road segments
    public func importSimple(from data: Data) throws -> [RoadSegment] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([RoadSegment].self, from: data)
    }
}

