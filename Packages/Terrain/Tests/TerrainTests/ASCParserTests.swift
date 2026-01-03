import Testing
import Foundation

@testable import Terrain

@Suite("ASCParser Tests")
struct ASCParserTests {

    @Test("Parse valid ASC header")
    func testParseValidHeader() throws {
        let testASC = """
            ncols         10
            nrows         10
            xllcenter     100.0
            yllcenter     200.0
            cellsize      1.0
            nodata_value  -9999
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            1 2 3 4 5 6 7 8 9 10
            """

        // Write to temp file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.asc")
        try testASC.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = ASCParser()
        let (header, heights) = try parser.load(from: tempURL)

        #expect(header.ncols == 10)
        #expect(header.nrows == 10)
        #expect(header.xllcenter == 100.0)
        #expect(header.yllcenter == 200.0)
        #expect(header.cellsize == 1.0)
        #expect(header.nodataValue == -9999)
        #expect(heights.count == 10)
        #expect(heights[0].count == 10)
    }

    @Test("Handle NODATA values")
    func testHandleNodataValues() throws {
        let testASC = """
            ncols         3
            nrows         3
            xllcenter     0.0
            yllcenter     0.0
            cellsize      1.0
            nodata_value  -9999
            1 2 3
            -9999 5 6
            7 8 -9999
            """

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "test_nodata.asc")
        try testASC.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let parser = ASCParser()
        let (_, heights) = try parser.load(from: tempURL)

        // NODATA values should be replaced with 0
        #expect(heights[1][0] == 0.0)
        #expect(heights[2][2] == 0.0)
        #expect(heights[0][0] == 1.0)
    }
}
