import Foundation

/// Optimized builder for large terrain maps with progressive loading
public actor OptimizedTerrainMapBuilder {
    private let calculator: TerrainCalculator
    private let chunkSize = 100
    
    public init() {
        self.calculator = TerrainCalculator()
    }
    
    /// Build terrain map progressively with progress reporting
    /// - Parameters:
    ///   - header: ASC file header
    ///   - heights: 2D array of elevation values
    ///   - progress: Closure called with progress (0.0 to 1.0)
    /// - Returns: TerrainMap with calculated nodes
    public func buildTerrainMapProgressive(
        header: ASCHeader,
        heights: [[Double]],
        progress: @Sendable @escaping (Double, String) -> Void
    ) async -> TerrainMap {
        await progress(0.0, "Starting terrain processing...")
        
        var nodes: [[TerrainNode]] = []
        nodes.reserveCapacity(header.nrows)
        
        let totalRows = header.nrows
        
        for y in 0..<header.nrows {
            var row: [TerrainNode] = []
            row.reserveCapacity(header.ncols)
            
            for x in 0..<header.ncols {
                let height = heights[y][x]
                
                // Calculate world coordinates
                let worldX = header.xllcenter + Double(x) * header.cellsize
                let worldY = header.yllcenter + Double(y) * header.cellsize
                let worldZ = height
                
                let coordinates = TerrainNode.Coordinates(
                    x: worldX,
                    y: worldY,
                    z: worldZ
                )
                
                // Calculate slope
                let slope = calculator.calculateSlope(
                    at: x,
                    y: y,
                    heights: heights,
                    cellsize: header.cellsize
                )
                
                // Calculate urbanization factor
                let urbanizationFactor = calculator.calculateUrbanizationFactor(from: slope)
                
                // Create node
                let node = TerrainNode(
                    coordinates: coordinates,
                    slope: slope,
                    urbanizationFactor: urbanizationFactor,
                    district: nil
                )
                
                row.append(node)
            }
            
            nodes.append(row)
            
            // Report progress every 10 rows to avoid overhead
            if y % 10 == 0 {
                let progressValue = Double(y) / Double(totalRows)
                await progress(progressValue, "Processing row \(y)/\(totalRows)...")
            }
            
            // Yield to allow other tasks to run
            if y % 50 == 0 {
                await Task.yield()
            }
        }
        
        await progress(1.0, "Finalizing terrain map...")
        
        return await MainActor.run {
            TerrainMap(header: header, nodes: nodes)
        }
    }
    
    /// Build terrain map with downsampling for large datasets
    /// - Parameters:
    ///   - header: ASC file header
    ///   - heights: 2D array of elevation values
    ///   - downsampleFactor: Factor to reduce resolution (e.g., 2 = half resolution)
    ///   - progress: Progress callback
    /// - Returns: Downsampled TerrainMap
    public func buildDownsampledTerrainMap(
        header: ASCHeader,
        heights: [[Double]],
        downsampleFactor: Int = 1,
        progress: @Sendable @escaping (Double, String) -> Void
    ) async -> TerrainMap {
        guard downsampleFactor > 1 else {
            return await buildTerrainMapProgressive(header: header, heights: heights, progress: progress)
        }
        
        await progress(0.0, "Downsampling terrain data...")
        
        let newRows = header.nrows / downsampleFactor
        let newCols = header.ncols / downsampleFactor
        
        var nodes: [[TerrainNode]] = []
        nodes.reserveCapacity(newRows)
        
        for y in 0..<newRows {
            var row: [TerrainNode] = []
            row.reserveCapacity(newCols)
            
            for x in 0..<newCols {
                let sourceY = y * downsampleFactor
                let sourceX = x * downsampleFactor
                
                // Average heights in the downsample window
                var heightSum = 0.0
                var count = 0
                for dy in 0..<downsampleFactor {
                    for dx in 0..<downsampleFactor {
                        let sy = sourceY + dy
                        let sx = sourceX + dx
                        if sy < header.nrows && sx < header.ncols {
                            heightSum += heights[sy][sx]
                            count += 1
                        }
                    }
                }
                let avgHeight = heightSum / Double(count)
                
                // Calculate world coordinates for downsampled cell
                let worldX = header.xllcenter + Double(sourceX) * header.cellsize
                let worldY = header.yllcenter + Double(sourceY) * header.cellsize
                
                let coordinates = TerrainNode.Coordinates(
                    x: worldX,
                    y: worldY,
                    z: avgHeight
                )
                
                // Simplified slope calculation for downsampled data
                let slope = calculator.calculateSlope(
                    at: sourceX,
                    y: sourceY,
                    heights: heights,
                    cellsize: header.cellsize * Double(downsampleFactor)
                )
                
                let urbanizationFactor = calculator.calculateUrbanizationFactor(from: slope)
                
                let node = TerrainNode(
                    coordinates: coordinates,
                    slope: slope,
                    urbanizationFactor: urbanizationFactor,
                    district: nil
                )
                
                row.append(node)
            }
            
            nodes.append(row)
            
            if y % 10 == 0 {
                let progressValue = Double(y) / Double(newRows)
                await progress(progressValue, "Processing downsampled row \(y)/\(newRows)...")
                await Task.yield()
            }
        }
        
        await progress(1.0, "Terrain map ready!")
        
        // Create adjusted header
        let adjustedHeader = ASCHeader(
            ncols: newCols,
            nrows: newRows,
            xllcenter: header.xllcenter,
            yllcenter: header.yllcenter,
            cellsize: header.cellsize * Double(downsampleFactor),
            nodataValue: header.nodataValue
        )
        
        return await MainActor.run {
            TerrainMap(header: adjustedHeader, nodes: nodes)
        }
    }
}

