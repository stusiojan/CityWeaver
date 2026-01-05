import SceneKit
import Terrain
import RoadGeneration

/// Helper class to build SceneKit scenes from terrain and road data
@MainActor
struct SceneBuilder {
    
    /// Configuration for scene building
    struct BuildOptions {
        let roadWidth: Double
        let roadHeight: Double
        let terrainVerticalScale: Double
        let terrainDownsample: Int
        let showGrid: Bool
        
        static let `default` = BuildOptions(
            roadWidth: 4.0,
            roadHeight: 0.2,
            terrainVerticalScale: 1.0,
            terrainDownsample: 1,
            showGrid: false
        )
    }
    
    /// Build a complete scene with terrain and roads
    func buildScene(
        terrainMap: Terrain.TerrainMap?,
        roads: [RoadSegment],
        options: BuildOptions = .default
    ) -> SCNScene {
        let scene = SCNScene()
        
        // Add terrain if available
        if let terrainMap = terrainMap {
            if let terrainNode = buildTerrainNode(terrainMap: terrainMap, options: options) {
                scene.rootNode.addChildNode(terrainNode)
            }
        }
        
        // Add roads
        let roadsNode = buildRoadsNode(roads: roads, terrainMap: terrainMap, options: options)
        scene.rootNode.addChildNode(roadsNode)
        
        // Add grid if requested
        if options.showGrid {
            let gridNode = buildGridNode(size: 1000)
            scene.rootNode.addChildNode(gridNode)
        }
        
        // Add lighting
        setupLighting(in: scene)
        
        // Add camera
        setupCamera(in: scene, roads: roads, terrainMap: terrainMap)
        
        return scene
    }
    
    /// Build terrain mesh node
    func buildTerrainNode(terrainMap: Terrain.TerrainMap, options: BuildOptions) -> SCNNode? {
        let dims = terrainMap.dimensions
        let step = options.terrainDownsample
        
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []
        
        // Generate vertices and normals
        for y in stride(from: 0, to: dims.rows, by: step) {
            for x in stride(from: 0, to: dims.cols, by: step) {
                if let node = terrainMap.getNode(at: x, y: y) {
                    let vertex = SCNVector3(
                        Float(node.coordinates.x),
                        Float(node.coordinates.z * options.terrainVerticalScale),
                        Float(node.coordinates.y)
                    )
                    vertices.append(vertex)
                    
                    // Calculate normal (simplified - pointing up)
                    normals.append(SCNVector3(0, 1, 0))
                }
            }
        }
        
        // Generate indices for triangles
        let cols = (dims.cols + step - 1) / step
        for y in 0..<((dims.rows + step - 1) / step - 1) {
            for x in 0..<(cols - 1) {
                let i0 = Int32(y * cols + x)
                let i1 = i0 + 1
                let i2 = i0 + Int32(cols)
                let i3 = i2 + 1
                
                // Two triangles per quad
                indices.append(contentsOf: [i0, i1, i3])
                indices.append(contentsOf: [i0, i3, i2])
            }
        }
        
        // Create geometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        
        // Apply material
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(red: 0.6, green: 0.5, blue: 0.4, alpha: 1.0)
        material.specular.contents = NSColor(white: 0.1, alpha: 1.0)
        material.shininess = 0.1
        geometry.materials = [material]
        
        let terrainNode = SCNNode(geometry: geometry)
        terrainNode.name = "Terrain"
        
        return terrainNode
    }
    
    /// Build roads node with all road segments
    func buildRoadsNode(roads: [RoadSegment], terrainMap: Terrain.TerrainMap?, options: BuildOptions) -> SCNNode {
        let roadsNode = SCNNode()
        roadsNode.name = "Roads"
        
        for (index, segment) in roads.enumerated() {
            let roadNode = buildRoadSegmentNode(segment: segment, terrainMap: terrainMap, options: options)
            roadNode.name = "Road_\(index)"
            roadsNode.addChildNode(roadNode)
        }
        
        return roadsNode
    }
    
    /// Build a single road segment node
    func buildRoadSegmentNode(segment: RoadSegment, terrainMap: Terrain.TerrainMap?, options: BuildOptions) -> SCNNode {
        let attrs = segment.attributes
        let halfWidth = Float(options.roadWidth / 2.0)
        
        // Calculate road endpoints
        let startX = Float(attrs.startPoint.x)
        let startY = Float(attrs.startPoint.y)
        let endX = startX + Float(cos(attrs.angle) * attrs.length)
        let endY = startY + Float(sin(attrs.angle) * attrs.length)
        
        // Calculate perpendicular offset for road width
        let perpAngle = attrs.angle + .pi / 2
        let offsetX = Float(cos(perpAngle)) * halfWidth
        let offsetY = Float(sin(perpAngle)) * halfWidth
        
        // Get elevation from terrain
        let startZ = Float(getElevation(x: Double(startX), y: Double(startY), terrainMap: terrainMap) * options.terrainVerticalScale)
        let endZ = Float(getElevation(x: Double(endX), y: Double(endY), terrainMap: terrainMap) * options.terrainVerticalScale)
        let roadHeight = Float(options.roadHeight)
        
        // Create vertices for rectangular prism
        let vertices: [SCNVector3] = [
            // Top surface
            SCNVector3(startX - offsetX, startZ + roadHeight, startY - offsetY),
            SCNVector3(startX + offsetX, startZ + roadHeight, startY + offsetY),
            SCNVector3(endX + offsetX, endZ + roadHeight, endY + offsetY),
            SCNVector3(endX - offsetX, endZ + roadHeight, endY - offsetY),
            // Bottom surface
            SCNVector3(startX - offsetX, startZ, startY - offsetY),
            SCNVector3(startX + offsetX, startZ, startY + offsetY),
            SCNVector3(endX + offsetX, endZ, endY + offsetY),
            SCNVector3(endX - offsetX, endZ, endY - offsetY)
        ]
        
        // Define indices for triangles
        let indices: [Int32] = [
            // Top
            0, 1, 2,  0, 2, 3,
            // Bottom
            4, 7, 6,  4, 6, 5,
            // Sides
            0, 3, 7,  0, 7, 4,
            1, 0, 4,  1, 4, 5,
            2, 1, 5,  2, 5, 6,
            3, 2, 6,  3, 6, 7
        ]
        
        // Create normals (simplified)
        let normals = vertices.map { _ in SCNVector3(0, 1, 0) }
        
        // Create geometry
        let vertexSource = SCNGeometrySource(vertices: vertices)
        let normalSource = SCNGeometrySource(normals: normals)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        
        let geometry = SCNGeometry(sources: [vertexSource, normalSource], elements: [element])
        
        // Apply material based on road type
        let material = SCNMaterial()
        switch attrs.roadType {
        case "main", "highway":
            material.diffuse.contents = NSColor(red: 0.2, green: 0.2, blue: 0.25, alpha: 1.0)
        case "residential":
            material.diffuse.contents = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        default:
            material.diffuse.contents = NSColor(red: 0.25, green: 0.25, blue: 0.25, alpha: 1.0)
        }
        material.specular.contents = NSColor(white: 0.2, alpha: 1.0)
        material.shininess = 0.3
        geometry.materials = [material]
        
        return SCNNode(geometry: geometry)
    }
    
    /// Build a grid helper node
    func buildGridNode(size: Int) -> SCNNode {
        let gridNode = SCNNode()
        gridNode.name = "Grid"
        
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(white: 0.5, alpha: 0.2)
        
        // Create grid lines
        for i in stride(from: -size/2, to: size/2, by: 100) {
            // Horizontal lines
            let hLine = SCNBox(width: CGFloat(size), height: 0.1, length: 0.5, chamferRadius: 0)
            hLine.materials = [material]
            let hNode = SCNNode(geometry: hLine)
            hNode.position = SCNVector3(0, 0, Float(i))
            gridNode.addChildNode(hNode)
            
            // Vertical lines
            let vLine = SCNBox(width: 0.5, height: 0.1, length: CGFloat(size), chamferRadius: 0)
            vLine.materials = [material]
            let vNode = SCNNode(geometry: vLine)
            vNode.position = SCNVector3(Float(i), 0, 0)
            gridNode.addChildNode(vNode)
        }
        
        return gridNode
    }
    
    /// Setup scene lighting
    func setupLighting(in scene: SCNScene) {
        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(white: 0.4, alpha: 1.0)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)
        
        // Directional light (sun)
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = NSColor(white: 0.8, alpha: 1.0)
        directionalLight.castsShadow = true
        directionalLight.shadowMode = .deferred
        let directionalNode = SCNNode()
        directionalNode.light = directionalLight
        directionalNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(directionalNode)
    }
    
    /// Setup camera positioned to view the scene
    func setupCamera(in scene: SCNScene, roads: [RoadSegment], terrainMap: Terrain.TerrainMap?) {
        let camera = SCNCamera()
        camera.zFar = 10000
        camera.zNear = 0.1
        
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        
        // Calculate scene bounds
        var minX: Float = 0, maxX: Float = 1000
        var minY: Float = 0, maxY: Float = 1000
        var minZ: Float = 0, maxZ: Float = 100
        
        if let terrainMap = terrainMap {
            let dims = terrainMap.dimensions
            if let firstNode = terrainMap.getNode(at: 0, y: 0) {
                minX = Float(firstNode.coordinates.x)
                minY = Float(firstNode.coordinates.y)
            }
            if let lastNode = terrainMap.getNode(at: dims.cols - 1, y: dims.rows - 1) {
                maxX = Float(lastNode.coordinates.x)
                maxY = Float(lastNode.coordinates.y)
            }
        } else if !roads.isEmpty {
            let allPoints = roads.flatMap { segment -> [(x: Float, y: Float)] in
                let start = (x: Float(segment.attributes.startPoint.x), y: Float(segment.attributes.startPoint.y))
                let end = (
                    x: Float(segment.attributes.startPoint.x + cos(segment.attributes.angle) * segment.attributes.length),
                    y: Float(segment.attributes.startPoint.y + sin(segment.attributes.angle) * segment.attributes.length)
                )
                return [start, end]
            }
            minX = allPoints.map({ $0.x }).min() ?? 0
            maxX = allPoints.map({ $0.x }).max() ?? 1000
            minY = allPoints.map({ $0.y }).min() ?? 0
            maxY = allPoints.map({ $0.y }).max() ?? 1000
        }
        
        // Position camera to view entire scene
        let centerX = (minX + maxX) / 2
        let centerY = (minY + maxY) / 2
        let centerZ = (minZ + maxZ) / 2
        let sceneSize = max(maxX - minX, maxY - minY)
        let distance = sceneSize * 0.8
        
        cameraNode.position = SCNVector3(centerX, distance * 0.7, centerY - distance)
        cameraNode.look(at: SCNVector3(centerX, centerZ, centerY))
        
        scene.rootNode.addChildNode(cameraNode)
    }
    
    /// Get elevation from terrain map
    private func getElevation(x: Double, y: Double, terrainMap: Terrain.TerrainMap?) -> Double {
        guard let terrainMap = terrainMap else { return 0.0 }
        let node = terrainMap.getNode(at: (x: x, y: y))
        return node?.coordinates.z ?? 0.0
    }
}

