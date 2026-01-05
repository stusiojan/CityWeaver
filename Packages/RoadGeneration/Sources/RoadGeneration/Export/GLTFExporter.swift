import Foundation
import Terrain

/// Exports road networks and terrain to glTF 2.0 format
/// glTF (GL Transmission Format) is a modern 3D format with better material support
public struct GLTFExporter: Sendable {
    
    /// Configuration for GLTF export
    public struct ExportOptions: Sendable {
        /// Width of road segments in meters
        public let roadWidth: Double
        /// Height of road surface above terrain
        public let roadElevation: Double
        /// Whether to include terrain mesh
        public let includeTerrain: Bool
        /// Terrain downsampling factor
        public let terrainDownsample: Int
        /// Vertical scale multiplier for terrain
        public let terrainVerticalScale: Double
        /// Embed binary data in JSON (vs separate .bin file)
        public let embedBinary: Bool
        
        public init(
            roadWidth: Double = 4.0,
            roadElevation: Double = 0.1,
            includeTerrain: Bool = true,
            terrainDownsample: Int = 1,
            terrainVerticalScale: Double = 1.0,
            embedBinary: Bool = true
        ) {
            self.roadWidth = roadWidth
            self.roadElevation = roadElevation
            self.includeTerrain = includeTerrain
            self.terrainDownsample = terrainDownsample
            self.terrainVerticalScale = terrainVerticalScale
            self.embedBinary = embedBinary
        }
    }
    
    public init() {}
    
    /// Export road network and optional terrain to glTF format
    /// - Parameters:
    ///   - segments: Array of road segments
    ///   - terrainMap: Optional terrain map for elevation data
    ///   - options: Export configuration options
    /// - Returns: Tuple of glTF JSON content and optional binary buffer
    @MainActor
    public func export(
        segments: [RoadSegment],
        terrainMap: Terrain.TerrainMap?,
        options: ExportOptions = ExportOptions()
    ) -> (gltf: String, bin: Data?) {
        
        var meshes: [[String: Any]] = []
        var materials: [[String: Any]] = []
        var bufferData = Data()
        var accessors: [[String: Any]] = []
        var bufferViews: [[String: Any]] = []
        
        // Add road material
        materials.append([
            "name": "RoadMaterial",
            "pbrMetallicRoughness": [
                "baseColorFactor": [0.3, 0.3, 0.3, 1.0],
                "metallicFactor": 0.1,
                "roughnessFactor": 0.9
            ]
        ])
        
        // Generate road meshes
        for (index, segment) in segments.enumerated() {
            let (vertices, indices) = generateRoadGeometry(
                segment: segment,
                terrainMap: terrainMap,
                options: options
            )
            
            let (meshData, accessorData, viewData) = createMeshBuffers(
                vertices: vertices,
                indices: indices,
                startOffset: bufferData.count
            )
            
            bufferData.append(meshData)
            accessors.append(contentsOf: accessorData)
            bufferViews.append(contentsOf: viewData)
            
            let primitiveCount = accessors.count
            meshes.append([
                "name": "Road_\(index + 1)",
                "primitives": [[
                    "attributes": [
                        "POSITION": primitiveCount - 2
                    ],
                    "indices": primitiveCount - 1,
                    "material": 0
                ]]
            ])
        }
        
        // Add terrain if requested
        if options.includeTerrain, let terrainMap = terrainMap {
            materials.append([
                "name": "TerrainMaterial",
                "pbrMetallicRoughness": [
                    "baseColorFactor": [0.6, 0.5, 0.4, 1.0],
                    "metallicFactor": 0.0,
                    "roughnessFactor": 1.0
                ]
            ])
            
            let (vertices, indices) = generateTerrainGeometry(
                terrainMap: terrainMap,
                options: options
            )
            
            let (meshData, accessorData, viewData) = createMeshBuffers(
                vertices: vertices,
                indices: indices,
                startOffset: bufferData.count
            )
            
            bufferData.append(meshData)
            accessors.append(contentsOf: accessorData)
            bufferViews.append(contentsOf: viewData)
            
            let primitiveCount = accessors.count
            meshes.append([
                "name": "Terrain",
                "primitives": [[
                    "attributes": [
                        "POSITION": primitiveCount - 2
                    ],
                    "indices": primitiveCount - 1,
                    "material": 1
                ]]
            ])
        }
        
        // Create nodes for each mesh
        let nodes: [[String: Any]] = meshes.indices.map { index in
            ["mesh": index, "name": "Node_\(index)"]
        }
        
        // Build glTF structure
        var gltfDict: [String: Any] = [
            "asset": [
                "version": "2.0",
                "generator": "CityWeaver"
            ],
            "scene": 0,
            "scenes": [[
                "nodes": Array(0..<nodes.count)
            ]],
            "nodes": nodes,
            "meshes": meshes,
            "materials": materials,
            "accessors": accessors,
            "bufferViews": bufferViews
        ]
        
        // Handle buffer encoding
        let binData: Data?
        if options.embedBinary {
            let base64 = bufferData.base64EncodedString()
            gltfDict["buffers"] = [[
                "byteLength": bufferData.count,
                "uri": "data:application/octet-stream;base64,\(base64)"
            ]]
            binData = nil
        } else {
            gltfDict["buffers"] = [[
                "byteLength": bufferData.count,
                "uri": "roads.bin"
            ]]
            binData = bufferData
        }
        
        // Convert to JSON
        let jsonData = try? JSONSerialization.data(withJSONObject: gltfDict, options: [.prettyPrinted, .sortedKeys])
        let gltfString = jsonData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        
        return (gltf: gltfString, bin: binData)
    }
    
    /// Generate road geometry
    @MainActor private func generateRoadGeometry(
        segment: RoadSegment,
        terrainMap: Terrain.TerrainMap?,
        options: ExportOptions
    ) -> (vertices: [Float], indices: [UInt16]) {
        let attrs = segment.attributes
        let halfWidth = Float(options.roadWidth / 2.0)
        
        let startX = Float(attrs.startPoint.x)
        let startY = Float(attrs.startPoint.y)
        let endX = startX + Float(cos(attrs.angle) * attrs.length)
        let endY = startY + Float(sin(attrs.angle) * attrs.length)
        
        let perpAngle = attrs.angle + .pi / 2
        let offsetX = Float(cos(perpAngle)) * halfWidth
        let offsetY = Float(sin(perpAngle)) * halfWidth
        
        let startZ = Float(getElevation(x: Double(startX), y: Double(startY), terrainMap: terrainMap) + options.roadElevation)
        let endZ = Float(getElevation(x: Double(endX), y: Double(endY), terrainMap: terrainMap) + options.roadElevation)
        
        // 8 vertices for rectangular prism
        let vertices: [Float] = [
            startX - offsetX, startZ, startY - offsetY,
            startX + offsetX, startZ, startY + offsetY,
            endX + offsetX, endZ, endY + offsetY,
            endX - offsetX, endZ, endY - offsetY,
            startX - offsetX, startZ - 0.05, startY - offsetY,
            startX + offsetX, startZ - 0.05, startY + offsetY,
            endX + offsetX, endZ - 0.05, endY + offsetY,
            endX - offsetX, endZ - 0.05, endY - offsetY
        ]
        
        // 12 triangles (2 per face * 6 faces)
        let indices: [UInt16] = [
            0, 1, 2,  0, 2, 3,  // Top
            4, 7, 6,  4, 6, 5,  // Bottom
            0, 3, 7,  0, 7, 4,  // Side 1
            1, 0, 4,  1, 4, 5,  // Side 2
            2, 1, 5,  2, 5, 6,  // Side 3
            3, 2, 6,  3, 6, 7   // Side 4
        ]
        
        return (vertices: vertices, indices: indices)
    }
    
    /// Generate terrain geometry
    @MainActor
    private func generateTerrainGeometry(
        terrainMap: Terrain.TerrainMap,
        options: ExportOptions
    ) -> (vertices: [Float], indices: [UInt16]) {
        let dims = terrainMap.dimensions
        let step = options.terrainDownsample
        
        var vertices: [Float] = []
        var indices: [UInt16] = []
        
        // Generate vertices
        for y in stride(from: 0, to: dims.rows, by: step) {
            for x in stride(from: 0, to: dims.cols, by: step) {
                if let node = terrainMap.getNode(at: x, y: y) {
                    vertices.append(Float(node.coordinates.x))
                    vertices.append(Float(node.coordinates.z * options.terrainVerticalScale))
                    vertices.append(Float(node.coordinates.y))
                }
            }
        }
        
        // Generate indices
        let cols = (dims.cols + step - 1) / step
        for y in 0..<((dims.rows + step - 1) / step - 1) {
            for x in 0..<(cols - 1) {
                let i0 = UInt16(y * cols + x)
                let i1 = i0 + 1
                let i2 = i0 + UInt16(cols)
                let i3 = i2 + 1
                
                indices.append(contentsOf: [i0, i1, i3, i0, i3, i2])
            }
        }
        
        return (vertices: vertices, indices: indices)
    }
    
    /// Create buffer data for mesh
    private func createMeshBuffers(
        vertices: [Float],
        indices: [UInt16],
        startOffset: Int
    ) -> (data: Data, accessors: [[String: Any]], bufferViews: [[String: Any]]) {
        var bufferData = Data()
        
        // Vertex buffer
        let vertexData = vertices.withUnsafeBytes { Data($0) }
        bufferData.append(vertexData)
        
        // Index buffer (align to 4 bytes)
        let padding = (4 - (bufferData.count % 4)) % 4
        bufferData.append(Data(count: padding))
        let indexOffset = bufferData.count
        let indexData = indices.withUnsafeBytes { Data($0) }
        bufferData.append(indexData)
        
        // Buffer views
        let vertexBufferView: [String: Any] = [
            "buffer": 0,
            "byteOffset": startOffset,
            "byteLength": vertexData.count,
            "target": 34962  // ARRAY_BUFFER
        ]
        
        let indexBufferView: [String: Any] = [
            "buffer": 0,
            "byteOffset": startOffset + indexOffset,
            "byteLength": indexData.count,
            "target": 34963  // ELEMENT_ARRAY_BUFFER
        ]
        
        // Calculate bounding box
        let minX = vertices.enumerated().filter { $0.offset % 3 == 0 }.map { $0.element }.min() ?? 0
        let minY = vertices.enumerated().filter { $0.offset % 3 == 1 }.map { $0.element }.min() ?? 0
        let minZ = vertices.enumerated().filter { $0.offset % 3 == 2 }.map { $0.element }.min() ?? 0
        let maxX = vertices.enumerated().filter { $0.offset % 3 == 0 }.map { $0.element }.max() ?? 0
        let maxY = vertices.enumerated().filter { $0.offset % 3 == 1 }.map { $0.element }.max() ?? 0
        let maxZ = vertices.enumerated().filter { $0.offset % 3 == 2 }.map { $0.element }.max() ?? 0
        
        // Accessors
        let vertexAccessor: [String: Any] = [
            "bufferView": 0,  // Will be adjusted by caller
            "componentType": 5126,  // FLOAT
            "count": vertices.count / 3,
            "type": "VEC3",
            "min": [minX, minY, minZ],
            "max": [maxX, maxY, maxZ]
        ]
        
        let indexAccessor: [String: Any] = [
            "bufferView": 1,  // Will be adjusted by caller
            "componentType": 5123,  // UNSIGNED_SHORT
            "count": indices.count,
            "type": "SCALAR"
        ]
        
        return (data: bufferData, accessors: [vertexAccessor, indexAccessor], bufferViews: [vertexBufferView, indexBufferView])
    }
    
    /// Get elevation from terrain map or return default
    @MainActor private func getElevation(x: Double, y: Double, terrainMap: Terrain.TerrainMap?) -> Double {
        guard let terrainMap = terrainMap else { return 0.0 }
        let node = terrainMap.getNode(at: (x: x, y: y))
        return node?.coordinates.z ?? 0.0
    }
    
    /// Save glTF files to disk
    /// - Parameters:
    ///   - gltf: glTF JSON content
    ///   - bin: Optional binary buffer data
    ///   - directory: Directory to save files
    ///   - basename: Base name for files
    public func saveToFiles(
        gltf: String,
        bin: Data?,
        directory: URL,
        basename: String = "roads"
    ) throws {
        let gltfURL = directory.appending(path: "\(basename).gltf")
        try gltf.write(to: gltfURL, atomically: true, encoding: .utf8)
        
        if let bin = bin {
            let binURL = directory.appending(path: "\(basename).bin")
            try bin.write(to: binURL)
        }
    }
}

