import Core
import Shared
import RoadGeneration
import Terrain
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Terrain Editor", systemImage: "map") {
                TerrainEditorView()
            }
            
            Tab("Road Generation", systemImage: "road.lanes") {
                RoadGeneratorView()
            }
            
            Tab("Simple Demo", systemImage: "play.circle") {
                SimpleDemoView()
            }
        }
    }
}

/// Simple demo view showing the POC functionality
struct SimpleDemoView: View {
    /// Holds the state of the currently generated roads.
    @State private var roads: [RoadGeneration.RoadSegment] = []
    @State private var terrainMap: Terrain.TerrainMap?
    @State private var showingVisualization = false
    @State private var visualizationType: VisualizationType = .canvas2D
    
    enum VisualizationType {
        case canvas2D
        case scene3D
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Control Panel
            HStack {
                Button("Generate Example Roads") {
                    generateExampleRoads()
                }
                .buttonStyle(.borderedProminent)
                
                if !roads.isEmpty {
                    Picker("Visualization", selection: $visualizationType) {
                        Text("2D Canvas").tag(VisualizationType.canvas2D)
                        Text("3D Scene").tag(VisualizationType.scene3D)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    
                    Button("Clear") {
                        roads.removeAll()
                        terrainMap = nil
                    }
                    .foregroundStyle(.red)
                }
                
                Spacer()
                
                if !roads.isEmpty {
                    Text("\(roads.count) segments generated")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            
            // Visualization Area
            Group {
                if roads.isEmpty {
                    ContentUnavailableView(
                        "No Roads Generated",
                        systemImage: "road.lanes",
                        description: Text("Click 'Generate Example Roads' to see a quick demo")
                    )
                } else {
                    switch visualizationType {
                    case .canvas2D:
                        canvas2DView
                    case .scene3D:
                        RoadNetwork3DView(terrainMap: terrainMap, roads: roads)
                    }
                }
            }
        }
    }
    
    private var canvas2DView: some View {
        Canvas { context, size in
            drawRoads2D(context: context, size: size)
        }
        .background(Color(.controlBackgroundColor))
    }
    
    private func generateExampleRoads() {
        withAnimation {
            roads = RoadGeneration.exampleUsage()
            
            // Create a sample terrain map for 3D view
            let header = Terrain.ASCHeader(
                ncols: 1000,
                nrows: 1000,
                xllcenter: 0,
                yllcenter: 0,
                cellsize: 1,
                nodataValue: -9999
            )
            
            var nodes: [[Terrain.TerrainNode]] = []
            for y in 0..<1000 {
                var row: [Terrain.TerrainNode] = []
                for x in 0..<1000 {
                    let z = sin(Double(x) * 0.02) * cos(Double(y) * 0.02) * 5
                    let node = Terrain.TerrainNode(
                        coordinates: Terrain.TerrainNode.Coordinates(
                            x: Double(x),
                            y: Double(y),
                            z: z
                        ),
                        slope: Double.random(in: 0...0.5),
                        urbanizationFactor: Double.random(in: 0.3...1.0),
                        district: .residential
                    )
                    row.append(node)
                }
                nodes.append(row)
            }
            
            terrainMap = Terrain.TerrainMap(header: header, nodes: nodes)
        }
    }
    
    private func drawRoads2D(context: GraphicsContext, size: CGSize) {
        guard !roads.isEmpty else { return }
        
        // Calculate bounds
        let allPoints = roads.flatMap { segment -> [CGPoint] in
            let start = segment.attributes.startPoint
            let end = CGPoint(
                x: start.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: start.y + sin(segment.attributes.angle) * segment.attributes.length
            )
            return [start, end]
        }
        
        guard let minX = allPoints.map({ $0.x }).min(),
              let maxX = allPoints.map({ $0.x }).max(),
              let minY = allPoints.map({ $0.y }).min(),
              let maxY = allPoints.map({ $0.y }).max() else { return }
        
        let dataWidth = maxX - minX
        let dataHeight = maxY - minY
        let scale = min(size.width / dataWidth, size.height / dataHeight) * 0.9
        let offsetX = (size.width - dataWidth * scale) / 2 - minX * scale
        let offsetY = (size.height - dataHeight * scale) / 2 - minY * scale
        
        // Draw roads
        for segment in roads {
            let start = segment.attributes.startPoint
            let end = CGPoint(
                x: start.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: start.y + sin(segment.attributes.angle) * segment.attributes.length
            )
            
            let scaledStart = CGPoint(
                x: start.x * scale + offsetX,
                y: start.y * scale + offsetY
            )
            let scaledEnd = CGPoint(
                x: end.x * scale + offsetX,
                y: end.y * scale + offsetY
            )
            
            var path = Path()
            path.move(to: scaledStart)
            path.addLine(to: scaledEnd)
            
            context.stroke(
                path,
                with: .color(roadTypeToColor(segment.attributes.roadType)),
                style: StrokeStyle(
                    lineWidth: roadTypeToWidth(segment.attributes.roadType),
                    lineCap: .round
                )
            )
        }
    }
    
    // --- Helper functions for styling ---
    
    /// Returns a specific Color based on the road type.
    private func roadTypeToColor(_ type: String) -> Color {
        switch type {
        case "highway":
            return .blue.opacity(0.8)
        case "residential":
            return .green.opacity(0.8)
        case "street":
            return .gray.opacity(0.8)
        default:
            return .black.opacity(0.8)
        }
    }
    
    /// Returns a specific line width based on the road type.
    private func roadTypeToWidth(_ type: String) -> Double {
        switch type {
        case "highway":
            return 6.0
        case "residential":
            return 2.0
        case "street":
            return 3.5
        default:
            return 1.0
        }
    }
}

#Preview {
    ContentView()
}
