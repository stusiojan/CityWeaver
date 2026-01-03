import Core
import Shared
import RGA
import Terrain
import SwiftUI

struct ContentView: View {
    /// Holds the state of the currently generated roads.
    @State private var roads: [RGA.RoadSegment] = []
    
    var body: some View {
        TabView {
            Tab("Terrain", systemImage: "map") {
                TerrainEditorView()
            }
            
            Tab("Roads", systemImage: "road.lanes") {
                roadGeneratorView
            }
        }
    }
    
    private var roadGeneratorView: some View {
        VStack(spacing: 0) {
            // --- Control Panel ---
            HStack {
                Button("Generate Roads") {
                    // Generate a new set of roads and update the state
                    // This will cause the Canvas to re-draw.
                    withAnimation {
                        self.roads = RGA.exampleUsage()
                    }
                }
                .padding()
                .font(.headline)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .background(Color(.darkGray))
            
            // --- Drawing Canvas ---
            Canvas { context, size in
                // Iterate over each road segment and draw it
                for segment in roads {
                    let attrs = segment.attributes
                    let start = attrs.startPoint
                    
                    // Calculate the end point based on start, angle, and length
                    let end = CGPoint(
                        x: start.x + cos(attrs.angle) * attrs.length,
                        y: start.y + sin(attrs.angle) * attrs.length
                    )
                    
                    // Create a path for the line
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    
                    // Stroke the path with style based on road type
                    context.stroke(
                        path,
                        with: .color(roadTypeToColor(attrs.roadType)),
                        style: StrokeStyle(
                            lineWidth: roadTypeToWidth(attrs.roadType),
                            lineCap: .round
                        )
                    )
                }
            }
            // Add a border and background to the canvas area
            .background(Color(.gray))
            .overlay(
                Rectangle()
                    .stroke(Color.gray, lineWidth: 1)
            )
            .ignoresSafeArea() // Allow canvas to fill remaining space
        }
        .onAppear {
            // Generate an initial set of roads when the view first appears
            self.roads = RGA.exampleUsage()
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
