import SwiftUI
import RoadGeneration
import Terrain

/// Main view for road generation with full controls
@MainActor
struct RoadGeneratorView: View {
    // Terrain data
    @State private var terrainMap: Terrain.TerrainMap?
    @State private var terrainFileName: String = "No terrain loaded"
    
    // City state configuration
    @State private var population: Int = 50_000
    @State private var density: Double = 1_500
    @State private var economicLevel: Double = 0.6
    @State private var age: Int = 15
    
    // Rule configuration
    @State private var ruleConfig = RuleConfiguration()
    
    // Initial road parameters
    @State private var initialX: Double = 500
    @State private var initialY: Double = 500
    @State private var initialAngle: Double = 0
    @State private var initialLength: Double = 100
    
    // Generation state
    @State private var isGenerating = false
    @State private var generatedRoads: [RoadSegment] = []
    @State private var generationTime: TimeInterval = 0
    @State private var showingConfigSheet = false
    @State private var configSheetType: ConfigSheetType = .cityState
    
    // Export state
    @State private var showingExportOptions = false
    
    enum ConfigSheetType {
        case cityState
        case rules
    }
    
    var body: some View {
        HSplitView {
            // Control Panel (left side)
            VStack(alignment: .leading, spacing: 16) {
                // Terrain section
                GroupBox("Terrain Data") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(terrainFileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            Button("Load ASC File", systemImage: "map") {
                                loadASCFile()
                            }
                            
                            Button("Load JSON", systemImage: "doc") {
                                loadJSONFile()
                            }
                        }
                        
                        if let terrain = terrainMap {
                            let dims = terrain.dimensions
                            Text("\(dims.cols) × \(dims.rows) nodes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // City State Configuration
                GroupBox("City State") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Population: \(population, format: .number)")
                        Text("Density: \(density, format: .number.precision(.fractionLength(0))) /km²")
                        Text("Economic Level: \(economicLevel, format: .number.precision(.fractionLength(2)))")
                        Text("Age: \(age) years")
                        
                        Button("Configure City State", systemImage: "slider.horizontal.3") {
                            configSheetType = .cityState
                            showingConfigSheet = true
                        }
                    }
                    .font(.caption)
                }
                
                // Rule Configuration
                GroupBox("Generation Rules") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Slope: \(ruleConfig.maxBuildableSlope, format: .number.precision(.fractionLength(2)))")
                        Text("Min Urbanization: \(ruleConfig.minUrbanizationFactor, format: .number.precision(.fractionLength(2)))")
                        Text("Min Road Distance: \(ruleConfig.minimumRoadDistance, format: .number.precision(.fractionLength(1)))m")
                        
                        Button("Configure Rules", systemImage: "gearshape") {
                            configSheetType = .rules
                            showingConfigSheet = true
                        }
                    }
                    .font(.caption)
                }
                
                // Initial Road Parameters
                GroupBox("Initial Road") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Start X:")
                            Spacer()
                            TextField("X", value: $initialX, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        HStack {
                            Text("Start Y:")
                            Spacer()
                            TextField("Y", value: $initialY, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }
                        
                        HStack {
                            Text("Angle:")
                            Spacer()
                            TextField("Angle", value: $initialAngle, format: .number.precision(.fractionLength(2)))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("rad")
                                .font(.caption)
                        }
                        
                        HStack {
                            Text("Length:")
                            Spacer()
                            TextField("Length", value: $initialLength, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("m")
                                .font(.caption)
                        }
                    }
                    .font(.caption)
                }
                
                // Generation Controls
                VStack(spacing: 12) {
                    Button(action: generateRoads) {
                        Label(isGenerating ? "Generating..." : "Generate Roads", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(terrainMap == nil || isGenerating)
                    
                    if !generatedRoads.isEmpty {
                        Button("Clear Roads", systemImage: "trash") {
                            generatedRoads.removeAll()
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                // Statistics
                if !generatedRoads.isEmpty {
                    GroupBox("Statistics") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Segments: \(generatedRoads.count)")
                            Text("Generation Time: \(generationTime, format: .number.precision(.fractionLength(3)))s")
                            
                            let totalLength = generatedRoads.reduce(0) { $0 + $1.attributes.length }
                            Text("Total Length: \(totalLength, format: .number.precision(.fractionLength(1)))m")
                        }
                        .font(.caption)
                    }
                }
                
                // Export Options
                if !generatedRoads.isEmpty {
                    Button("Export Roads", systemImage: "square.and.arrow.up") {
                        showingExportOptions = true
                    }
                }
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 300, idealWidth: 350, maxWidth: 400)
            
            // Visualization Area (right side)
            VStack {
                if generatedRoads.isEmpty {
                    ContentUnavailableView(
                        "No Roads Generated",
                        systemImage: "road.lanes",
                        description: Text("Load terrain data and click 'Generate Roads' to begin")
                    )
                } else {
                    // Simple 2D visualization
                    Canvas { context, size in
                        drawRoads(context: context, size: size)
                    }
                    .background(Color(.controlBackgroundColor))
                }
            }
        }
        .sheet(isPresented: $showingConfigSheet) {
            NavigationStack {
                Group {
                    if configSheetType == .cityState {
                        CityStateConfigView(
                            population: $population,
                            density: $density,
                            economicLevel: $economicLevel,
                            age: $age
                        )
                    } else {
                        RuleConfigView(config: $ruleConfig)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingConfigSheet = false
                        }
                    }
                }
            }
            .frame(minWidth: 600, minHeight: 500)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView(roads: generatedRoads, terrainMap: terrainMap)
        }
    }
    
    // MARK: - Actions
    
    private func loadASCFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "asc")!]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let parser = Terrain.ASCParser()
                        let (header, heights) = try parser.load(from: url)
                        
                        // Use appropriate builder based on size
                        let nodeCount = header.nrows * header.ncols
                        if nodeCount > 1_000_000 {
                            let builder = Terrain.OptimizedTerrainMapBuilder()
                            terrainMap = await builder.buildDownsampledTerrainMap(
                                header: header,
                                heights: heights,
                                downsampleFactor: 4
                            ) { progress, message in
                                print("\(message): \(progress)")
                            }
                        } else {
                            let builder = Terrain.TerrainMapBuilder()
                            terrainMap = builder.buildTerrainMap(header: header, heights: heights)
                        }
                        
                        terrainFileName = url.lastPathComponent
                    } catch {
                        print("Failed to load ASC file: \(error)")
                    }
                }
            }
        }
    }
    
    private func loadJSONFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let serializer = Terrain.TerrainMapSerializer()
                        terrainMap = try serializer.import(from: url)
                        terrainFileName = url.lastPathComponent
                    } catch {
                        print("Failed to load JSON file: \(error)")
                    }
                }
            }
        }
    }
    
    private func generateRoads() {
        print("=== generateRoads called ===")
        guard let terrainMap = terrainMap else {
            print("❌ No terrain map available")
            return
        }
        
        print("✓ Terrain map exists: \(terrainMap.dimensions)")
        isGenerating = true
        print("✓ Set isGenerating = true")
        
        Task { @MainActor in
            print("🔄 Task started on MainActor")
            let startTime = Date()
            
            // Create city state
            let cityState = CityState(
                population: population,
                density: density,
                economicLevel: economicLevel,
                age: age
            )
            print("✓ Created city state: pop=\(cityState.population), age=\(cityState.age)")
            
            // Create generator
            let generator = RoadGenerator(
                cityState: cityState,
                terrainMap: terrainMap,
                config: ruleConfig
            )
            print("✓ Created generator")
            
            // Create initial road
            let initialRoad = RoadAttributes(
                startPoint: CGPoint(x: initialX, y: initialY),
                angle: initialAngle,
                length: initialLength,
                roadType: "main"
            )
            
            let initialQuery = QueryAttributes(
                startPoint: CGPoint(x: initialX, y: initialY),
                angle: initialAngle,
                length: initialLength,
                roadType: "main",
                isMainRoad: true
            )
            print("✓ Initial road: start=(\(initialX), \(initialY)), angle=\(initialAngle), length=\(initialLength)")
            
            // Generate roads
            print("🚀 Starting road generation...")
            let roads = generator.generateRoadNetwork(
                initialRoad: initialRoad,
                initialQuery: initialQuery
            )
            print("✅ Generation complete! Generated \(roads.count) road segments")
            
            generatedRoads = roads
            generationTime = Date().timeIntervalSince(startTime)
            isGenerating = false
            
            print("✓ Updated state: generatedRoads.count=\(generatedRoads.count), time=\(generationTime)s")
            print("=== generateRoads finished ===")
        }
    }
    
    private func drawRoads(context: GraphicsContext, size: CGSize) {
        guard !generatedRoads.isEmpty else { return }
        
        // Calculate bounds
        let allPoints = generatedRoads.flatMap { segment -> [CGPoint] in
            let start = segment.attributes.startPoint
            let end = CGPoint(
                x: start.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: start.y + sin(segment.attributes.angle) * segment.attributes.length
            )
            return [start, end]
        }
        
        guard let minX = allPoints.map({ $0.x }).min(),
              let maxX = allPoints.map({ $0.x }).max(),
              let minY = allPoints.map({ $0.y }).min(),
              let maxY = allPoints.map({ $0.y }).max() else { return }
        
        let dataWidth = maxX - minX
        let dataHeight = maxY - minY
        let scale = min(size.width / dataWidth, size.height / dataHeight) * 0.9
        let offsetX = (size.width - dataWidth * scale) / 2 - minX * scale
        let offsetY = (size.height - dataHeight * scale) / 2 - minY * scale
        
        // Draw roads
        for segment in generatedRoads {
            let start = segment.attributes.startPoint
            let end = CGPoint(
                x: start.x + cos(segment.attributes.angle) * segment.attributes.length,
                y: start.y + sin(segment.attributes.angle) * segment.attributes.length
            )
            
            let scaledStart = CGPoint(
                x: start.x * scale + offsetX,
                y: start.y * scale + offsetY
            )
            let scaledEnd = CGPoint(
                x: end.x * scale + offsetX,
                y: end.y * scale + offsetY
            )
            
            var path = Path()
            path.move(to: scaledStart)
            path.addLine(to: scaledEnd)
            
            let color: Color = segment.attributes.roadType == "main" ? .blue : .gray
            context.stroke(path, with: .color(color), lineWidth: 2)
        }
    }
}

/// Export options sheet
struct ExportOptionsView: View {
    let roads: [RoadSegment]
    let terrainMap: Terrain.TerrainMap?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Export Format") {
                    Button("Export as JSON", systemImage: "doc.text") {
                        exportJSON()
                    }
                    
                    Button("Export as OBJ (Blender)", systemImage: "cube") {
                        exportOBJ()
                    }
                    
                    Button("Export as glTF", systemImage: "cube.transparent") {
                        exportGLTF()
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Export Roads")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private func exportJSON() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "road_network.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        let serializer = RoadNetworkSerializer()
                        let cityState = RoadNetworkSerializer.CityStateSnapshot(
                            population: 50_000,
                            density: 1_500,
                            economicLevel: 0.6,
                            age: 15
                        )
                        let config = RoadNetworkSerializer.ConfigurationSnapshot(
                            maxBuildableSlope: 0.3,
                            minUrbanizationFactor: 0.2,
                            minimumRoadDistance: 10.0
                        )
                        let data = try serializer.export(roads, cityState: cityState, configuration: config)
                        try data.write(to: url)
                        print("Exported JSON to \(url.path)")
                    } catch {
                        print("Failed to export JSON: \(error)")
                    }
                }
            }
        }
    }
    
    private func exportOBJ() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "obj")!]
        panel.nameFieldStringValue = "road_network.obj"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    let exporter = OBJExporter()
                    let options = OBJExporter.ExportOptions(includeTerrain: terrainMap != nil)
                    let (obj, mtl) = exporter.export(segments: roads, terrainMap: terrainMap, options: options)
                    
                    do {
                        let directory = url.deletingLastPathComponent()
                        let basename = url.deletingPathExtension().lastPathComponent
                        try exporter.saveToFiles(obj: obj, mtl: mtl, directory: directory, basename: basename)
                        print("Exported OBJ to \(directory.path)")
                    } catch {
                        print("Failed to export OBJ: \(error)")
                    }
                }
            }
        }
    }
    
    private func exportGLTF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "gltf")!]
        panel.nameFieldStringValue = "road_network.gltf"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    let exporter = GLTFExporter()
                    let options = GLTFExporter.ExportOptions(includeTerrain: terrainMap != nil, embedBinary: true)
                    let (gltf, bin) = exporter.export(segments: roads, terrainMap: terrainMap, options: options)
                    
                    do {
                        let directory = url.deletingLastPathComponent()
                        let basename = url.deletingPathExtension().lastPathComponent
                        try exporter.saveToFiles(gltf: gltf, bin: bin, directory: directory, basename: basename)
                        print("Exported glTF to \(directory.path)")
                    } catch {
                        print("Failed to export glTF: \(error)")
                    }
                }
            }
        }
    }
}

#Preview {
    RoadGeneratorView()
        .frame(width: 1200, height: 800)
}

