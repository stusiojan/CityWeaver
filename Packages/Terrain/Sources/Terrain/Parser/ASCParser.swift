import Foundation

/// Errors that can occur during ASC file parsing
public enum ASCParserError: Error, LocalizedError {
    case fileNotFound
    case invalidHeader
    case invalidGridData
    case nodataValueNotSupported
    case invalidFileFormat

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            "ASC file not found"
        case .invalidHeader:
            "Invalid or incomplete header in ASC file"
        case .invalidGridData:
            "Invalid grid data format"
        case .nodataValueNotSupported:
            "NODATA values in grid are not yet fully supported"
        case .invalidFileFormat:
            "Invalid ASC file format"
        }
    }
}

/// Parser for ASC (ASCII Grid) files containing elevation data
public struct ASCParser: Sendable {

    public init() {}

    /// Load and parse an ASC file
    /// - Parameter url: URL to the ASC file
    /// - Returns: Tuple containing header metadata and 2D array of heights
    /// - Throws: ASCParserError if parsing fails
    public func load(from url: URL) throws -> (ASCHeader, [[Double]]) {
        // Read file contents
        guard let fileContents = try? String(contentsOf: url, encoding: .utf8) else {
            throw ASCParserError.fileNotFound
        }

        let lines = fileContents.components(separatedBy: .newlines)
        guard lines.count > 6 else {
            throw ASCParserError.invalidFileFormat
        }

        // Find where header ends and data begins
        var headerLines: [String] = []
        var dataStartIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces).lowercased()

            // Check if this looks like a header line
            if trimmed.starts(with: "ncols") || trimmed.starts(with: "nrows")
                || trimmed.starts(with: "xllcenter") || trimmed.starts(with: "xllcorner")
                || trimmed.starts(with: "yllcenter") || trimmed.starts(with: "yllcorner")
                || trimmed.starts(with: "cellsize") || trimmed.starts(with: "nodata_value")
            {
                headerLines.append(line)
            } else if !trimmed.isEmpty && headerLines.count >= 6 {
                // This looks like the start of data
                dataStartIndex = index
                break
            }
        }

        // Parse header
        let header = try parseHeader(headerLines)

        // Parse grid data (remaining lines)
        let gridLines = Array(lines.dropFirst(dataStartIndex)).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let heights = try parseGrid(gridLines, header: header)

        return (header, heights)
    }

    /// Parse the 6-line header section
    private func parseHeader(_ lines: [String]) throws -> ASCHeader {
        var ncols: Int?
        var nrows: Int?
        var xll: Double?
        var yll: Double?
        var cellsize: Double?
        var nodataValue: Double?

        // Parse only non-empty lines
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        for line in nonEmptyLines {
            let components = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard components.count >= 2 else { continue }

            let key = components[0].lowercased()
            let value = components[1]

            switch key {
            case "ncols":
                ncols = Int(value)
            case "nrows":
                nrows = Int(value)
            case "xllcenter", "xllcorner":
                xll = Double(value)
            case "yllcenter", "yllcorner":
                yll = Double(value)
            case "cellsize":
                cellsize = Double(value)
            case "nodata_value":
                nodataValue = Double(value)
            default:
                break
            }
        }

        guard let ncols, let nrows, let xll, let yll,
            let cellsize, let nodataValue
        else {
            throw ASCParserError.invalidHeader
        }

        return ASCHeader(
            ncols: ncols,
            nrows: nrows,
            xllcenter: xll,
            yllcenter: yll,
            cellsize: cellsize,
            nodataValue: nodataValue
        )
    }

    /// Parse the grid data section
    private func parseGrid(_ lines: [String], header: ASCHeader) throws -> [[Double]] {
        var heights: [[Double]] = []

        for line in lines {
            let values = line.trimmingCharacters(in: .whitespaces)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .compactMap { Double($0) }

            guard !values.isEmpty else { continue }

            // Replace NODATA values with 0 or handle them appropriately
            let processedValues = values.map { value in
                value == header.nodataValue ? 0.0 : value
            }

            heights.append(processedValues)
        }

        // Validate dimensions
        guard heights.count == header.nrows else {
            throw ASCParserError.invalidGridData
        }

        for row in heights {
            guard row.count == header.ncols else {
                throw ASCParserError.invalidGridData
            }
        }

        return heights
    }
}
