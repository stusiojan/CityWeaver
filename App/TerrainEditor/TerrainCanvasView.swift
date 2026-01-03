import SwiftUI
import Terrain

#if os(macOS)
    import AppKit
#endif

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
    @State private var updateTrigger = UUID()
    @State private var lastMagnification: CGFloat = 1.0
    @State private var isPanning = false

    // Viewport optimization
    @State private var visibleRect: CGRect = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scroll wheel capture layer (full size, in background)
                Color.clear
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onScrollWheel { delta in
                        let zoomFactor = 1.0 + (delta / 100.0)
                        let newScale = max(0.1, min(10.0, scale * zoomFactor))

                        print("🖱️ Scroll wheel: delta=\(delta), newScale=\(newScale)")

                        scale = newScale
                        lastMagnification = newScale
                    }

                // Canvas layer
                Canvas { context, size in
                    print("🎨 Canvas redraw - scale: \(scale), offset: \(offset), size: \(size)")

                    let dimensions = terrainMap.dimensions

                    // Calculate cell size to fit entire map in view
                    let baseCellSize = min(
                        size.width / CGFloat(dimensions.cols),
                        size.height / CGFloat(dimensions.rows))
                    let cellSize = baseCellSize * scale

                    print(
                        "📐 Dimensions: \(dimensions.cols)x\(dimensions.rows), cellSize: \(cellSize)"
                    )

                    // Calculate visible range for optimization
                    let visibleMinX = max(0, Int(-offset.width / cellSize))
                    let visibleMaxX = min(
                        dimensions.cols, Int((size.width - offset.width) / cellSize) + 1)
                    let visibleMinY = max(0, Int(-offset.height / cellSize))
                    let visibleMaxY = min(
                        dimensions.rows, Int((size.height - offset.height) / cellSize) + 1)

                    print(
                        "👁️ Visible range: x[\(visibleMinX)..\(visibleMaxX)], y[\(visibleMinY)..\(visibleMaxY)]"
                    )

                    // Draw terrain grid
                    var cellsDrawn = 0
                    for y in visibleMinY..<visibleMaxY {
                        for x in visibleMinX..<visibleMaxX {
                            guard let node = terrainMap.getNode(at: x, y: y) else { continue }

                            let rect = CGRect(
                                x: CGFloat(x) * cellSize + offset.width,
                                y: CGFloat(y) * cellSize + offset.height,
                                width: cellSize,
                                height: cellSize
                            )
                            cellsDrawn += 1

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

                    print("✅ Drew \(cellsDrawn) cells")
                }
                .id(updateTrigger)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            print("🔍 Magnification changed: \(value), current scale: \(scale)")
                            scale = max(0.1, min(10.0, lastMagnification * value))
                        }
                        .onEnded { value in
                            print("🔍 Magnification ended: \(value), final scale: \(scale)")
                            lastMagnification = scale
                        }
                )
                .gesture(dragGesture(geometry: geometry))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
            .onAppear {
                print("🚀 Canvas appeared - geometry: \(geometry.size)")
                let dimensions = terrainMap.dimensions
                print("📊 Map dimensions: \(dimensions.cols)x\(dimensions.rows)")

                // Start at 100% scale (1.0)
                scale = 1.0
                lastMagnification = 1.0

                // Center the map
                let baseCellSize = min(
                    geometry.size.width / CGFloat(dimensions.cols),
                    geometry.size.height / CGFloat(dimensions.rows))
                let totalWidth = CGFloat(dimensions.cols) * baseCellSize
                let totalHeight = CGFloat(dimensions.rows) * baseCellSize

                offset = CGSize(
                    width: (geometry.size.width - totalWidth) / 2,
                    height: (geometry.size.height - totalHeight) / 2
                )

                print("✅ Initial setup - scale: \(scale), offset: \(offset)")
            }
        }
    }

    /// Drag gesture for painting or panning
    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dimensions = terrainMap.dimensions
                let baseCellSize = min(
                    geometry.size.width / CGFloat(dimensions.cols),
                    geometry.size.height / CGFloat(dimensions.rows))
                let cellSize = baseCellSize * scale

                let gridX = Int((value.location.x - offset.width) / cellSize)
                let gridY = Int((value.location.y - offset.height) / cellSize)

                print("🖌️ Paint at grid: (\(gridX), \(gridY)), tool: \(activeTool)")

                switch activeTool {
                case .brush:
                    painter.paintWithBrush(
                        terrainMap,
                        x: gridX,
                        y: gridY,
                        district: selectedDistrict,
                        brushSize: brushSize
                    )
                    print("✏️ Painted with brush at (\(gridX), \(gridY))")
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
                    // Fill will be triggered on tap
                    break
                }
            }
            .onEnded { value in
                if activeTool == .fill {
                    let dimensions = terrainMap.dimensions
                    let baseCellSize = min(
                        geometry.size.width / CGFloat(dimensions.cols),
                        geometry.size.height / CGFloat(dimensions.rows))
                    let cellSize = baseCellSize * scale

                    let gridX = Int((value.location.x - offset.width) / cellSize)
                    let gridY = Int((value.location.y - offset.height) / cellSize)

                    print("🪣 Fill at grid: (\(gridX), \(gridY))")

                    painter.floodFill(
                        terrainMap,
                        startX: gridX,
                        startY: gridY,
                        targetDistrict: selectedDistrict
                    )
                    updateTrigger = UUID()
                    onPaintEnd()  // Record undo snapshot
                    print("💾 Undo snapshot saved after fill")
                } else if activeTool == .brush || activeTool == .eraser {
                    // Record undo for brush/eraser after drag ends
                    onPaintEnd()
                    print("💾 Undo snapshot saved after brush/eraser")
                }
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

// MARK: - Scroll Wheel Support

#if os(macOS)
    /// View modifier for handling scroll wheel events on macOS
    private struct ScrollWheelModifier: ViewModifier {
        let onScroll: (CGFloat) -> Void

        func body(content: Content) -> some View {
            content
                .background(ScrollWheelHandler(onScroll: onScroll))
        }
    }

    /// Helper view to capture scroll wheel events
    private struct ScrollWheelHandler: NSViewRepresentable {
        let onScroll: (CGFloat) -> Void

        func makeNSView(context: Context) -> NSView {
            let view = ScrollWheelCaptureView()
            view.onScroll = onScroll

            print("🏗️ ScrollWheelHandler view created")
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            if let view = nsView as? ScrollWheelCaptureView {
                view.onScroll = onScroll
            }
        }
    }

    /// Custom NSView that captures scroll wheel events
    private class ScrollWheelCaptureView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.backgroundColor = NSColor.clear.cgColor
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func scrollWheel(with event: NSEvent) {
            print("📜 ScrollWheel event received: deltaY=\(event.scrollingDeltaY)")
            onScroll?(event.scrollingDeltaY)
        }

        override func mouseDown(with event: NSEvent) {
            // Allow event to propagate
            super.mouseDown(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            // Allow event to propagate
            super.mouseDragged(with: event)
        }

        override var acceptsFirstResponder: Bool {
            true
        }
    }

    extension View {
        fileprivate func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
            modifier(ScrollWheelModifier(onScroll: action))
        }
    }
#else
    extension View {
        fileprivate func onScrollWheel(perform action: @escaping (CGFloat) -> Void) -> some View {
            self
        }
    }
#endif
