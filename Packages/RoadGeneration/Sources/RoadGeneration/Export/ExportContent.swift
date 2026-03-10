/// Determines what data to include in an export
public enum ExportContent: String, CaseIterable, Sendable {
    case roadsOnly = "Roads Only"
    case terrainOnly = "Terrain Only"
    case roadsAndTerrain = "Roads & Terrain"
}
