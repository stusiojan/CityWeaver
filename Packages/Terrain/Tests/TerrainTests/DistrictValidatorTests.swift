import Testing
@testable import Terrain

@Suite("DistrictValidator Tests")
@MainActor
struct DistrictValidatorTests {
    
    @Test("Validate connected district")
    func testConnectedDistrict() async {
        let header = ASCHeader(
            ncols: 3,
            nrows: 3,
            xllcenter: 0.0,
            yllcenter: 0.0,
            cellsize: 1.0,
            nodataValue: -9999
        )
        
        let heights = [
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0]
        ]
        
        let builder = TerrainMapBuilder()
        let map = builder.buildTerrainMap(header: header, heights: heights)
        
        // Create a connected district
        map.setDistrict(at: 0, y: 0, district: .residential)
        map.setDistrict(at: 1, y: 0, district: .residential)
        map.setDistrict(at: 1, y: 1, district: .residential)
        
        let validator = DistrictValidator()
        let result = validator.validate(map)
        
        #expect(result.isValid)
        #expect(result.errors.isEmpty)
    }
    
    @Test("Detect fragmented district")
    func testFragmentedDistrict() async {
        let header = ASCHeader(
            ncols: 3,
            nrows: 3,
            xllcenter: 0.0,
            yllcenter: 0.0,
            cellsize: 1.0,
            nodataValue: -9999
        )
        
        let heights = [
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0],
            [10.0, 10.0, 10.0]
        ]
        
        let builder = TerrainMapBuilder()
        let map = builder.buildTerrainMap(header: header, heights: heights)
        
        // Create two disconnected fragments
        map.setDistrict(at: 0, y: 0, district: .residential)
        map.setDistrict(at: 2, y: 2, district: .residential)
        
        let validator = DistrictValidator()
        let result = validator.validate(map)
        
        #expect(!result.isValid)
        #expect(result.errors.count > 0)
        
        if case .districtNotConnected(let district, let count) = result.errors.first {
            #expect(district == .residential)
            #expect(count == 2)
        } else {
            Issue.record("Expected districtNotConnected error")
        }
    }
}

