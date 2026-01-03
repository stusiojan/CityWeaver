import SwiftUI
import Terrain

/// Level of Detail manager for terrain rendering
struct TerrainLODManager {
    /// Calculate appropriate cell aggregation level based on zoom
    /// - Parameter scale: Current zoom scale
    /// - Returns: Aggregation factor (1 = no aggregation, 2 = 2x2 cells, etc.)
    static func calculateLOD(scale: CGFloat) -> Int {
        switch scale {
        case ...0.5:
            return 10  // Very zoomed out: aggregate 10x10 cells
        case 0.5...1.0:
            return 5   // Zoomed out: aggregate 5x5 cells
        case 1.0...2.0:
            return 2   // Normal: aggregate 2x2 cells
        default:
            return 1   // Zoomed in: show individual cells
        }
    }
    
    /// Calculate render bounds with padding for smooth scrolling
    static func calculateVisibleBounds(
        viewSize: CGSize,
        offset: CGSize,
        scale: CGFloat,
        cellSize: CGFloat,
        mapDimensions: (rows: Int, cols: Int)
    ) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
        let padding = 10  // Extra cells to render beyond visible area
        
        let minX = max(0, Int(-offset.width / (cellSize * scale)) - padding)
        let maxX = min(mapDimensions.cols, Int((viewSize.width - offset.width) / (cellSize * scale)) + padding)
        let minY = max(0, Int(-offset.height / (cellSize * scale)) - padding)
        let maxY = min(mapDimensions.rows, Int((viewSize.height - offset.height) / (cellSize * scale)) + padding)
        
        return (minX, maxX, minY, maxY)
    }
}

/// Chunk-based terrain rendering for better performance
@MainActor
final class TerrainChunkManager: ObservableObject {
    private let chunkSize = 100
    @Published var visibleChunks: Set<ChunkCoordinate> = []
    
    struct ChunkCoordinate: Hashable {
        let x: Int
        let y: Int
    }
    
    func updateVisibleChunks(
        viewBounds: (minX: Int, maxX: Int, minY: Int, maxY: Int)
    ) {
        var newChunks: Set<ChunkCoordinate> = []
        
        let minChunkX = viewBounds.minX / chunkSize
        let maxChunkX = (viewBounds.maxX + chunkSize - 1) / chunkSize
        let minChunkY = viewBounds.minY / chunkSize
        let maxChunkY = (viewBounds.maxY + chunkSize - 1) / chunkSize
        
        for chunkY in minChunkY...maxChunkY {
            for chunkX in minChunkX...maxChunkX {
                newChunks.insert(ChunkCoordinate(x: chunkX, y: chunkY))
            }
        }
        
        if newChunks != visibleChunks {
            visibleChunks = newChunks
        }
    }
}

