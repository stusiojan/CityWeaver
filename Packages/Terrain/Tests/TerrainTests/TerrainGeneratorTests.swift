import Testing
import Foundation

@testable import Terrain

@Suite("TerrainGenerator Tests")
struct TerrainGeneratorTests {

    @Test("Flat terrain has correct dimensions")
    @MainActor
    func flatTerrainDimensions() {
        let map = TerrainGenerator.flat(cols: 10, rows: 8)

        #expect(map.dimensions.rows == 8)
        #expect(map.dimensions.cols == 10)
        #expect(map.header.ncols == 10)
        #expect(map.header.nrows == 8)
    }

    @Test("Flat terrain has zero slope everywhere")
    @MainActor
    func flatTerrainZeroSlope() {
        let map = TerrainGenerator.flat(cols: 5, rows: 5, height: 42)

        for row in map.nodes {
            for node in row {
                #expect(node.slope == 0.0)
            }
        }
    }

    @Test("Flat terrain has urbanizationFactor of 1.0")
    @MainActor
    func flatTerrainUrbanization() {
        let map = TerrainGenerator.flat(cols: 5, rows: 5, height: 10)

        for row in map.nodes {
            for node in row {
                #expect(node.urbanizationFactor == 1.0)
            }
        }
    }

    @Test("Flat terrain has correct height")
    @MainActor
    func flatTerrainHeight() {
        let map = TerrainGenerator.flat(cols: 3, rows: 3, height: 55.5)

        for row in map.nodes {
            for node in row {
                #expect(node.coordinates.z == 55.5)
            }
        }
    }

    @Test("Slope terrain has increasing heights north to south")
    @MainActor
    func slopeTerrainNorthToSouth() {
        let map = TerrainGenerator.slope(cols: 5, rows: 10, fromHeight: 0, toHeight: 100)

        // Heights should increase from first row to last row
        for col in 0..<5 {
            var previousHeight = -Double.infinity
            for row in 0..<10 {
                let height = map.nodes[row][col].coordinates.z
                #expect(height >= previousHeight)
                previousHeight = height
            }
        }

        // First row should be at fromHeight, last at toHeight
        #expect(map.nodes[0][0].coordinates.z == 0.0)
        #expect(map.nodes[9][0].coordinates.z == 100.0)
    }

    @Test("Slope terrain east to west has increasing heights")
    @MainActor
    func slopeTerrainEastToWest() {
        let map = TerrainGenerator.slope(
            cols: 10,
            rows: 5,
            fromHeight: 0,
            toHeight: 50,
            direction: .eastToWest
        )

        // Heights should decrease from left to right (east to west means high on east/right)
        for row in 0..<5 {
            var previousHeight = Double.infinity
            for col in 0..<10 {
                let height = map.nodes[row][col].coordinates.z
                #expect(height <= previousHeight)
                previousHeight = height
            }
        }
    }

    @Test("Hilly terrain has non-uniform heights")
    @MainActor
    func hillyTerrainVariation() {
        let map = TerrainGenerator.hilly(cols: 20, rows: 20, amplitude: 50, frequency: 0.3)

        var minHeight = Double.infinity
        var maxHeight = -Double.infinity

        for row in map.nodes {
            for node in row {
                minHeight = min(minHeight, node.coordinates.z)
                maxHeight = max(maxHeight, node.coordinates.z)
            }
        }

        // Should have meaningful height variation
        #expect(maxHeight - minHeight > 1.0)
    }

    @Test("Hilly terrain base height is centered correctly")
    @MainActor
    func hillyTerrainBaseHeight() {
        let map = TerrainGenerator.hilly(cols: 10, rows: 10, baseHeight: 200, amplitude: 10)

        // All heights should be within baseHeight +/- amplitude
        for row in map.nodes {
            for node in row {
                #expect(node.coordinates.z >= 190.0)
                #expect(node.coordinates.z <= 210.0)
            }
        }
    }

    @Test("paintAll covers every node")
    @MainActor
    func paintAllCoversEverything() {
        let map = TerrainGenerator.flat(cols: 8, rows: 6)
        DistrictLayout.paintAll(on: map, district: .residential)

        for row in map.nodes {
            for node in row {
                #expect(node.district == .residential)
            }
        }
    }

    @Test("paintRect covers the right area")
    @MainActor
    func paintRectCoversArea() {
        let map = TerrainGenerator.flat(cols: 10, rows: 10)
        DistrictLayout.paintRect(
            on: map,
            district: .business,
            origin: (x: 2, y: 3),
            size: (width: 4, height: 3)
        )

        // Inside the rect
        for y in 3..<6 {
            for x in 2..<6 {
                #expect(map.nodes[y][x].district == .business)
            }
        }

        // Outside the rect
        #expect(map.nodes[0][0].district == nil)
        #expect(map.nodes[9][9].district == nil)
    }

    @Test("paintGrid creates distinct zones")
    @MainActor
    func paintGridDistinctZones() {
        let map = TerrainGenerator.flat(cols: 10, rows: 10)
        let districts: [DistrictType] = [.business, .residential, .industrial, .park]
        DistrictLayout.paintGrid(on: map, districts: districts)

        // With 4 districts, grid is 2x2
        // Top-left quadrant should be business
        #expect(map.nodes[0][0].district == .business)

        // Top-right quadrant should be residential
        #expect(map.nodes[0][9].district == .residential)

        // Bottom-left quadrant should be industrial
        #expect(map.nodes[9][0].district == .industrial)

        // Bottom-right quadrant should be park
        #expect(map.nodes[9][9].district == .park)
    }
}
