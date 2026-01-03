import SwiftUI
import Terrain

/// Interactive canvas for displaying and editing terrain map
struct TerrainCanvasView: View {
    let terrainMap: TerrainMap
    @Binding var selectedDistrict: DistrictType
    @Binding var activeTool: PaintTool
    @Binding var brushSize: Int
    let painter: DistrictPainter
    let onPaintEnd: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var rectangleStart: CGPoint?
    @State private var rectangleEnd: CGPoint?
    @State private var updateTrigger = UUID()
    
    // Viewport optimization
    @State private var visibleRect: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let dimensions = terrainMap.dimensions
                let cellSize = min(size.width / CGFloat(dimensions.cols),
                                 size.height / CGFloat(dimensions.rows))
                
                // Calculate visible range for optimization
                let visibleMinX = max(0, Int(-offset.width / (cellSize * scale)))
                let visibleMaxX = min(dimensions.cols, Int((size.width - offset.width) / (cellSize * scale)) + 1)
                let visibleMinY = max(0, Int(-offset.height / (cellSize * scale)))
                let visibleMaxY = min(dimensions.rows, Int((size.height - offset.height) / (cellSize * scale)) + 1)
                
                // Draw terrain grid
                for y in visibleMinY..<visibleMaxY {
                    for x in visibleMinX..<visibleMaxX {
                        guard let node = terrainMap.getNode(at: x, y: y) else { continue }
                        
                        let rect = CGRect(
                            x: CGFloat(x) * cellSize * scale + offset.width,
                            y: CGFloat(y) * cellSize * scale + offset.height,
                            width: cellSize * scale,
                            height: cellSize * scale
                        )
                        
                        // Determine cell color
                        let color: Color
                        if let district = node.district {
                            color = districtColor(district).opacity(0.7)
                        } else {
                            // Height-based heatmap
                            color = heightColor(node.coordinates.z)
                        }
                        
                        context.fill(Path(rect), with: .color(color))
                        
                        // Draw grid lines (only when zoomed in)
                        if scale > 2.0 {
                            context.stroke(
                                Path(rect),
                                with: .color(.gray.opacity(0.3)),
                                lineWidth: 0.5
                            )
                        }
                    }
                }
                
                // Draw rectangle selection preview
                if let start = rectangleStart, let end = rectangleEnd {
                    let rect = CGRect(
                        x: min(start.x, end.x),
                        y: min(start.y, end.y),
                        width: abs(end.x - start.x),
                        height: abs(end.y - start.y)
                    )
                    context.stroke(
                        Path(rect),
                        with: .color(.blue),
                        lineWidth: 2
                    )
                }
            }
            .id(updateTrigger)
            .gesture(dragGesture(geometry: geometry))
            .gesture(magnificationGesture)
            .onAppear {
                // Center the view
                let dimensions = terrainMap.dimensions
                let cellSize = min(geometry.size.width / CGFloat(dimensions.cols),
                                 geometry.size.height / CGFloat(dimensions.rows))
                scale = cellSize / 10 // Initial zoom level
            }
        }
    }
    
    /// Drag gesture for painting or panning
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dimensions = terrainMap.dimensions
                let cellSize = min(geometry.size.width / CGFloat(dimensions.cols),
                                 geometry.size.height / CGFloat(dimensions.rows))
                
                let gridX = Int((value.location.x - offset.width) / (cellSize * scale))
                let gridY = Int((value.location.y - offset.height) / (cellSize * scale))
                
                switch activeTool {
                case .brush:
                    painter.paintWithBrush(
                        terrainMap,
                        x: gridX,
                        y: gridY,
                        district: selectedDistrict,
                        brushSize: brushSize
                    )
                    updateTrigger = UUID()
                    
                case .eraser:
                    painter.paintWithBrush(
                        terrainMap,
                        x: gridX,
                        y: gridY,
                        district: nil,
                        brushSize: brushSize
                    )
                    updateTrigger = UUID()
                    
                case .rectangle:
                    if rectangleStart == nil {
                        rectangleStart = value.location
                    }
                    rectangleEnd = value.location
                    updateTrigger = UUID()
                    
                case .fill:
                    // Fill will be triggered on tap
                    break
                }
            }
            .onEnded { value in
                if activeTool == .rectangle, 
                   let start = rectangleStart,
                   let end = rectangleEnd {
                    let dimensions = terrainMap.dimensions
                    let cellSize = min(geometry.size.width / CGFloat(dimensions.cols),
                                     geometry.size.height / CGFloat(dimensions.rows))
                    
                    let startGridX = Int((start.x - offset.width) / (cellSize * scale))
                    let startGridY = Int((start.y - offset.height) / (cellSize * scale))
                    let endGridX = Int((end.x - offset.width) / (cellSize * scale))
                    let endGridY = Int((end.y - offset.height) / (cellSize * scale))
                    
                    painter.paintRectangle(
                        terrainMap,
                        from: (startGridX, startGridY),
                        to: (endGridX, endGridY),
                        district: selectedDistrict
                    )
                    
                    rectangleStart = nil
                    rectangleEnd = nil
                    updateTrigger = UUID()
                    onPaintEnd()  // Record undo snapshot
                } else if activeTool == .fill {
                    let dimensions = terrainMap.dimensions
                    let cellSize = min(geometry.size.width / CGFloat(dimensions.cols),
                                     geometry.size.height / CGFloat(dimensions.rows))
                    
                    let gridX = Int((value.location.x - offset.width) / (cellSize * scale))
                    let gridY = Int((value.location.y - offset.height) / (cellSize * scale))
                    
                    painter.floodFill(
                        terrainMap,
                        startX: gridX,
                        startY: gridY,
                        targetDistrict: selectedDistrict
                    )
                    updateTrigger = UUID()
                    onPaintEnd()  // Record undo snapshot
                } else if activeTool == .brush || activeTool == .eraser {
                    // Record undo for brush/eraser after drag ends
                    onPaintEnd()
                }
            }
    }
    
    /// Magnification gesture for zooming
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.1, min(10.0, value))
            }
    }
    
    /// Get color for district
    private func districtColor(_ district: DistrictType) -> Color {
        switch district {
        case .business: .blue
        case .oldTown: .orange
        case .residential: .green
        case .industrial: .gray
        case .park: Color(red: 0.2, green: 0.6, blue: 0.2)
        }
    }
    
    /// Get color based on height (blue=low, red=high)
    private func heightColor(_ height: Double) -> Color {
        // Normalize height to 0-1 range (assuming typical elevation range)
        let normalized = (height - 250.0) / 50.0  // Adjust based on your data
        let clamped = max(0, min(1, normalized))
        
        if clamped < 0.5 {
            // Blue to green
            let t = clamped * 2
            return Color(
                red: 0,
                green: t,
                blue: 1 - t
            )
        } else {
            // Green to red
            let t = (clamped - 0.5) * 2
            return Color(
                red: t,
                green: 1 - t,
                blue: 0
            )
        }
    }
}

