import SwiftUI
import Terrain

/// Optimized canvas with image-based rendering for large terrains
struct OptimizedTerrainCanvasView: View {
    let terrainMap: TerrainMap
    @Binding var selectedDistrict: DistrictType
    @Binding var activeTool: PaintTool
    @Binding var brushSize: Int
    let painter: DistrictPainter
    let onPaintEnd: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var updateTrigger = UUID()
    @State private var cachedImage: Image?
    @State private var needsRedraw = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Pre-rendered terrain image
                if let image = cachedImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                }
            }
            .gesture(dragGesture(geometry: geometry))
            .gesture(magnificationGesture)
            .task {
                if needsRedraw {
                    await renderTerrainImage(size: geometry.size)
                    needsRedraw = false
                }
            }
            .onChange(of: updateTrigger) {
                needsRedraw = true
            }
        }
    }
    
    /// Render terrain to cached image for performance
    private func renderTerrainImage(size: CGSize) async {
        let dimensions = terrainMap.dimensions
        
        // Limit render size for performance
        let maxDimension: CGFloat = 2048
        let renderWidth = min(CGFloat(dimensions.cols), maxDimension)
        let renderHeight = min(CGFloat(dimensions.rows), maxDimension)
        
        let renderer = ImageRenderer(content: TerrainStaticView(
            terrainMap: terrainMap,
            size: CGSize(width: renderWidth, height: renderHeight)
        ))
        
        renderer.scale = 1.0
        
        if let cgImage = renderer.cgImage {
            await MainActor.run {
                #if canImport(AppKit)
                let nsImage = NSImage(cgImage: cgImage, size: CGSize(width: renderWidth, height: renderHeight))
                cachedImage = Image(nsImage: nsImage)
                #else
                cachedImage = Image(uiImage: UIImage(cgImage: cgImage))
                #endif
            }
        }
    }
    
    /// Drag gesture for painting
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dimensions = terrainMap.dimensions
                let scale = min(geometry.size.width / CGFloat(dimensions.cols),
                              geometry.size.height / CGFloat(dimensions.rows))
                
                let gridX = Int((value.location.x - offset.width) / scale)
                let gridY = Int((value.location.y - offset.height) / scale)
                
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
                    
                case .fill:
                    break
                }
            }
            .onEnded { value in
                if activeTool == .fill {
                    let dimensions = terrainMap.dimensions
                    let scale = min(geometry.size.width / CGFloat(dimensions.cols),
                                  geometry.size.height / CGFloat(dimensions.rows))
                    
                    let gridX = Int((value.location.x - offset.width) / scale)
                    let gridY = Int((value.location.y - offset.height) / scale)
                    
                    painter.floodFill(
                        terrainMap,
                        startX: gridX,
                        startY: gridY,
                        targetDistrict: selectedDistrict
                    )
                    updateTrigger = UUID()
                    onPaintEnd()
                } else if activeTool == .brush || activeTool == .eraser {
                    onPaintEnd()
                }
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = max(0.5, min(5.0, value))
            }
    }
}

/// Static view for pre-rendering terrain
private struct TerrainStaticView: View {
    let terrainMap: TerrainMap
    let size: CGSize
    
    var body: some View {
        Canvas { context, canvasSize in
            let dimensions = terrainMap.dimensions
            let cellWidth = size.width / CGFloat(dimensions.cols)
            let cellHeight = size.height / CGFloat(dimensions.rows)
            
            for y in 0..<dimensions.rows {
                for x in 0..<dimensions.cols {
                    guard let node = terrainMap.getNode(at: x, y: y) else { continue }
                    
                    let rect = CGRect(
                        x: CGFloat(x) * cellWidth,
                        y: CGFloat(y) * cellHeight,
                        width: cellWidth,
                        height: cellHeight
                    )
                    
                    let color: Color
                    if let district = node.district {
                        color = districtColor(district).opacity(0.7)
                    } else {
                        color = heightColor(node.coordinates.z)
                    }
                    
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func districtColor(_ district: DistrictType) -> Color {
        switch district {
        case .business: .blue
        case .oldTown: .orange
        case .residential: .green
        case .industrial: .gray
        case .park: Color(red: 0.2, green: 0.6, blue: 0.2)
        }
    }
    
    private func heightColor(_ height: Double) -> Color {
        let normalized = (height - 250.0) / 50.0
        let clamped = max(0, min(1, normalized))
        
        if clamped < 0.5 {
            let t = clamped * 2
            return Color(red: 0, green: t, blue: 1 - t)
        } else {
            let t = (clamped - 0.5) * 2
            return Color(red: t, green: 1 - t, blue: 0)
        }
    }
}

