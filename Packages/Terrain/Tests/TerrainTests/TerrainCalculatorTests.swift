import Testing

@testable import Terrain

@Suite("TerrainCalculator Tests")
struct TerrainCalculatorTests {

    @Test("Calculate slope for flat terrain")
    func testFlatTerrainSlope() {
        let heights = [
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0],
        ]

        let calculator = TerrainCalculator()
        let slope = calculator.calculateSlope(at: 1, y: 1, heights: heights, cellsize: 1.0)

        #expect(slope == 0.0)
    }

    @Test("Calculate slope for sloped terrain")
    func testSlopedTerrain() {
        let heights = [
            [10.0, 10.0, 10.0],
            [10.0, 15.0, 10.0],
            [10.0, 10.0, 10.0],
        ]

        let calculator = TerrainCalculator()
        let slope = calculator.calculateSlope(at: 1, y: 1, heights: heights, cellsize: 1.0)

        // Horne's algorithm in such cases treats central point as a noise
        #expect(slope == 0.0)
    }

    @Test("Calculate urbanization factor")
    func testUrbanizationFactor() {
        let calculator = TerrainCalculator()

        // Flat terrain should have high urbanization factor
        let flatUrban = calculator.calculateUrbanizationFactor(from: 0.0)
        #expect(flatUrban == 1.0)

        // Moderate slope
        let moderateUrban = calculator.calculateUrbanizationFactor(from: 0.3)
        #expect(moderateUrban > 0.0)
        #expect(moderateUrban < 1.0)

        // Steep slope
        let steepUrban = calculator.calculateUrbanizationFactor(from: 0.8)
        #expect(steepUrban == 0.0)
    }
}
