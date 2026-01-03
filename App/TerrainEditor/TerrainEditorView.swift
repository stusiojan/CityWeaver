import SwiftUI
import Terrain
import UniformTypeIdentifiers

/// Main terrain editor view with file loading and district painting
struct TerrainEditorView: View {
    @State private var terrainMap: TerrainMap?
    @State private var selectedDistrict: DistrictType = .residential
    @State private var activeTool: PaintTool = .brush
    @State private var brushSize: Int = 1
    @State private var isFileImporterPresented = false
    @State private var isLoading = false
    @State private var loadingProgress: String = ""
    @State private var errorMessage: String?
    @State private var validationResult: ValidationResult?
    @State private var showValidationAlert = false
    @State private var isExporting = false
    @StateObject private var undoManager = TerrainUndoManager()
    
    private let painter = DistrictPainter()
    private let validator = DistrictValidator()
    private let serializer = TerrainMapSerializer()
    
    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            HStack {
                if terrainMap == nil {
                    Button("Load .asc File") {
                        isFileImporterPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    // Undo/Redo buttons
                    Button("Undo", systemImage: "arrow.uturn.backward") {
                        performUndo()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!undoManager.canUndo)
                    .keyboardShortcut("z", modifiers: .command)
                    
                    Button("Redo", systemImage: "arrow.uturn.forward") {
                        performRedo()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!undoManager.canRedo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    
                    Divider()
                        .frame(height: 20)
                    
                    Button("Validate", systemImage: "checkmark.circle") {
                        validateDistricts()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("v", modifiers: .command)
                    
                    Button("Export", systemImage: "square.and.arrow.up") {
                        exportTerrainMap()
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("s", modifiers: .command)
                    
                    Button("Load New File") {
                        isFileImporterPresented = true
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                    Text(loadingProgress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            // Main content
            if let terrainMap {
                HSplitView {
                    // Left: Palette
                    DistrictPaletteView(
                        selectedDistrict: $selectedDistrict,
                        activeTool: $activeTool,
                        brushSize: $brushSize
                    )
                    .frame(minWidth: 250, maxWidth: 350)
                    
                    // Right: Canvas
                    VStack(spacing: 0) {
                        // Instructions
                        HStack {
                            Image(systemName: "info.circle")
                            Text("Use selected tool to paint districts. Shortcuts: B=Brush, F=Fill, R=Rectangle, E=Eraser, ⌘Z=Undo, ⇧⌘Z=Redo")
                                .font(.caption)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.accentColor.opacity(0.1))
                        
                        TerrainCanvasView(
                            terrainMap: terrainMap,
                            selectedDistrict: $selectedDistrict,
                            activeTool: $activeTool,
                            brushSize: $brushSize,
                            painter: painter,
                            onPaintEnd: recordUndoSnapshot
                        )
                    }
                }
            } else {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No Terrain Loaded")
                        .font(.title)
                    
                    Text("Load an .asc file to begin editing terrain districts")
                        .foregroundStyle(.secondary)
                    
                    Button("Load .asc File") {
                        isFileImporterPresented = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [UTType(filenameExtension: "asc") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await loadASCFile(result)
            }
        }
        .alert("Validation Results", isPresented: $showValidationAlert) {
            Button("OK") {
                showValidationAlert = false
            }
        } message: {
            if let result = validationResult {
                if result.isValid {
                    Text("All districts are valid! ✓")
                } else {
                    Text(result.errors.map { $0.description }.joined(separator: "\n"))
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    /// Load ASC file and build terrain map
    private func loadASCFile(_ result: Result<[URL], Error>) async {
        await MainActor.run {
            isLoading = true
            loadingProgress = "Loading file..."
            errorMessage = nil
        }
        
        do {
            guard let url = try result.get().first else { return }
            
            await MainActor.run {
                loadingProgress = "Parsing ASC file..."
            }
            
            let parser = ASCParser()
            let (header, heights) = try parser.load(from: url)
            
            await MainActor.run {
                loadingProgress = "Building terrain map..."
            }
            
            let builder = TerrainMapBuilder()
            let map = builder.buildTerrainMap(header: header, heights: heights)
            
            await MainActor.run {
                terrainMap = map
                undoManager.clear()
                isLoading = false
                loadingProgress = ""
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load terrain: \(error.localizedDescription)"
                isLoading = false
                loadingProgress = ""
            }
        }
    }
    
    /// Validate district assignments
    private func validateDistricts() {
        guard let map = terrainMap else { return }
        
        validationResult = validator.validate(map)
        showValidationAlert = true
    }
    
    /// Export terrain map to JSON
    private func exportTerrainMap() {
        guard let map = terrainMap else { return }
        
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "terrain_map.json"
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try serializer.export(map, to: url)
                } catch {
                    errorMessage = "Failed to export: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Record undo snapshot after painting action
    private func recordUndoSnapshot() {
        guard let map = terrainMap else { return }
        undoManager.recordSnapshot(map)
    }
    
    /// Perform undo
    private func performUndo() {
        guard let map = terrainMap else { return }
        undoManager.undo(map)
    }
    
    /// Perform redo
    private func performRedo() {
        guard let map = terrainMap else { return }
        undoManager.redo(map)
    }
}

#Preview {
    TerrainEditorView()
        .frame(width: 1200, height: 800)
}

