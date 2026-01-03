import Foundation

/// Header metadata from an ASC file
public struct ASCHeader: Sendable, Codable {
    public let ncols: Int
    public let nrows: Int
    public let xllcenter: Double
    public let yllcenter: Double
    public let cellsize: Double
    public let nodataValue: Double
    
    public init(
        ncols: Int,
        nrows: Int,
        xllcenter: Double,
        yllcenter: Double,
        cellsize: Double,
        nodataValue: Double
    ) {
        self.ncols = ncols
        self.nrows = nrows
        self.xllcenter = xllcenter
        self.yllcenter = yllcenter
        self.cellsize = cellsize
        self.nodataValue = nodataValue
    }
}

