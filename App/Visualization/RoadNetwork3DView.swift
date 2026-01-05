import SwiftUI
import SceneKit
import Terrain
import RoadGeneration

/// 3D visualization of road network and terrain using SceneKit
struct RoadNetwork3DView: View {
    let terrainMap: Terrain.TerrainMap?
    let roads: [RoadSegment]
    
    @State private var scene: SCNScene
    @State private var showTerrain = true
    @State private var showRoads = true
    @State private var showGrid = false
    @State private var terrainDownsample = 2
    @State private var verticalScale = 1.0
    
    init(terrainMap: Terrain.TerrainMap?, roads: [RoadSegment]) {
        self.terrainMap = terrainMap
        self.roads = roads
        
        // Build initial scene
        let builder = SceneBuilder()
        let options = SceneBuilder.BuildOptions(
            roadWidth: 4.0,
            roadHeight: 0.2,
            terrainVerticalScale: 1.0,
            terrainDownsample: 2,
            showGrid: false
        )
        _scene = State(initialValue: builder.buildScene(
            terrainMap: terrainMap,
            roads: roads,
            options: options
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 3D View
            ZStack {
                SceneKitView(scene: scene)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Overlay controls
                VStack {
                    HStack {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Show Terrain", isOn: $showTerrain)
                                    .onChange(of: showTerrain) {
                                        updateSceneVisibility()
                                    }
                                
                                Toggle("Show Roads", isOn: $showRoads)
                                    .onChange(of: showRoads) {
                                        updateSceneVisibility()
                                    }
                                
                                Toggle("Show Grid", isOn: $showGrid)
                                    .onChange(of: showGrid) {
                                        rebuildScene()
                                    }
                                
                                Divider()
                                
                                VStack(alignment: .leading) {
                                    Text("Vertical Scale: \(verticalScale, format: .number.precision(.fractionLength(1)))x")
                                        .font(.caption)
                                    Slider(value: $verticalScale, in: 0.1...5.0, step: 0.1)
                                        .onChange(of: verticalScale) {
                                            rebuildScene()
                                        }
                                }
                                
                                if terrainMap != nil {
                                    VStack(alignment: .leading) {
                                        Text("Terrain Detail: \(terrainDownsample)x")
                                            .font(.caption)
                                        Slider(value: Binding(
                                            get: { Double(terrainDownsample) },
                                            set: { terrainDownsample = Int($0) }
                                        ), in: 1...10, step: 1)
                                        .onChange(of: terrainDownsample) {
                                            rebuildScene()
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            
            // Info bar
            HStack {
                if let terrain = terrainMap {
                    let dims = terrain.dimensions
                    Text("Terrain: \(dims.cols) × \(dims.rows)")
                        .font(.caption)
                }
                
                Text("Roads: \(roads.count)")
                    .font(.caption)
                
                Spacer()
                
                Text("Controls: Drag to rotate • Scroll to zoom • Option+Drag to pan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
    }
    
    private func updateSceneVisibility() {
        scene.rootNode.childNode(withName: "Terrain", recursively: false)?.isHidden = !showTerrain
        scene.rootNode.childNode(withName: "Roads", recursively: false)?.isHidden = !showRoads
    }
    
    private func rebuildScene() {
        let builder = SceneBuilder()
        let options = SceneBuilder.BuildOptions(
            roadWidth: 4.0,
            roadHeight: 0.2,
            terrainVerticalScale: verticalScale,
            terrainDownsample: terrainDownsample,
            showGrid: showGrid
        )
        scene = builder.buildScene(
            terrainMap: terrainMap,
            roads: roads,
            options: options
        )
        updateSceneVisibility()
    }
}

/// SwiftUI wrapper for SCNView
struct SceneKitView: NSViewRepresentable {
    let scene: SCNScene
    
    func makeNSView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = scene
        scnView.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0)
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = false
        scnView.showsStatistics = true
        scnView.antialiasingMode = .multisampling4X
        
        // Configure camera control
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.minimumVerticalAngle = -90
        scnView.defaultCameraController.maximumVerticalAngle = 90
        
        return scnView
    }
    
    func updateNSView(_ nsView: SCNView, context: Context) {
        nsView.scene = scene
    }
}

#Preview {
    // Create sample data for preview
    let header = Terrain.ASCHeader(
        ncols: 100,
        nrows: 100,
        xllcenter: 0,
        yllcenter: 0,
        cellsize: 1,
        nodataValue: -9999
    )
    
    var nodes: [[Terrain.TerrainNode]] = []
    for y in 0..<100 {
        var row: [Terrain.TerrainNode] = []
        for x in 0..<100 {
            let z = sin(Double(x) * 0.1) * cos(Double(y) * 0.1) * 10
            let node = Terrain.TerrainNode(
                coordinates: Terrain.TerrainNode.Coordinates(x: Double(x), y: Double(y), z: z),
                slope: 0.1,
                urbanizationFactor: 0.8,
                district: .residential
            )
            row.append(node)
        }
        nodes.append(row)
    }
    
    let terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
    
    let roads = [
        RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 30, y: 30),
                angle: 0,
                length: 40,
                roadType: "main"
            ),
            createdAt: 0
        ),
        RoadSegment(
            attributes: RoadAttributes(
                startPoint: CGPoint(x: 70, y: 30),
                angle: .pi/2,
                length: 40,
                roadType: "residential"
            ),
            createdAt: 1
        )
    ]
    
    return RoadNetwork3DView(terrainMap: terrainMap, roads: roads)
        .frame(width: 1000, height: 700)
}

