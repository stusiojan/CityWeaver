import Shared
import SwiftUI
import RoadGeneration
import Terrain

/// Main view for road generation with full controls
@MainActor
struct RoadGeneratorView: View {
    private let logger = CWLogger(subsystem: "App.RoadGenerator")

    // Terrain data
    @State private var terrainMap: Terrain.TerrainMap?
    @State private var terrainFileName: String = "No terrain loaded"
    @State private var terrainWarnings: [String] = []

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
    @State private var generationReport: GenerationReport?
    @State private var showingConfigSheet = false
    @State private var configSheetType: ConfigSheetType = .cityState

    // Export
    @State private var exportContent: ExportContent = .roadsAndTerrain

    // Error handling
    @State private var loadError: String?
    @State private var showingLoadError = false

    // Terrain generator
    @State private var showTerrainGenerator = false

    enum ConfigSheetType {
        case cityState
        case rules
    }

    var body: some View {
        HSplitView {
            // Control Panel (left side)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    presetsSection
                    terrainSection
                    cityStateSection
                    rulesSection
                    initialRoadSection
                    generationControls
                    statisticsSection
                    exportSection
                }
                .padding()
            }
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
                    Canvas { context, size in
                        drawRoads(context: context, size: size)
                    }
                    .background(Color(.controlBackgroundColor))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .alert("Error Loading File", isPresented: $showingLoadError) {
            Button("OK") {}
        } message: {
            Text(loadError ?? "Unknown error")
        }
    }

    // MARK: - View Sections

    private var presetsSection: some View {
        GroupBox("Presets") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(GenerationPreset.allCases) { preset in
                    Button(action: { applyPreset(preset) }) {
                        VStack(alignment: .leading) {
                            Text(preset.rawValue)
                            Text(preset.recommendedMapInfo)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var terrainSection: some View {
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

                Button("Generate Terrain", systemImage: "waveform") {
                    showTerrainGenerator.toggle()
                }

                if showTerrainGenerator {
                    Divider()
                    TerrainGeneratorFormView { map in
                        terrainMap = map
                        let dims = map.dimensions
                        terrainFileName = "Generated (\(dims.cols)×\(dims.rows))"
                        onTerrainLoaded()
                        showTerrainGenerator = false
                    }
                }

                if let terrain = terrainMap {
                    let dims = terrain.dimensions
                    Text("\(dims.cols) × \(dims.rows) nodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Terrain validation warnings
                ForEach(terrainWarnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var cityStateSection: some View {
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
    }

    private var rulesSection: some View {
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
    }

    private var initialRoadSection: some View {
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
    }

    private var generationControls: some View {
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
                    generationReport = nil
                }
                .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var statisticsSection: some View {
        if let report = generationReport {
            GroupBox("Statistics") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Segments: \(generatedRoads.count)")
                    Text("Generation Time: \(report.processingTimeSeconds, format: .number.precision(.fractionLength(3)))s")

                    if !generatedRoads.isEmpty {
                        let totalLength = generatedRoads.reduce(0) { $0 + $1.attributes.length }
                        Text("Total Length: \(totalLength, format: .number.precision(.fractionLength(1)))m")
                    }

                    Text("Evaluated: \(report.totalProposalsEvaluated)")
                    Text("Accepted: \(report.totalAccepted)")
                    Text("Rejected: \(report.totalFailed)")

                    if !report.failuresByConstraint.isEmpty {
                        Divider()
                        Text("Failures by constraint:")
                            .bold()
                        ForEach(report.failuresByConstraint.sorted(by: { $0.value > $1.value }), id: \.key) { reason, count in
                            Text("  \(reason): \(count)")
                        }
                    }

                    // Warning diagnostics
                    if generatedRoads.isEmpty || !report.suggestedFixes.isEmpty {
                        Divider()
                        Text(report.diagnosticMessage)
                            .foregroundStyle(.orange)

                        ForEach(report.suggestedFixes, id: \.self) { fix in
                            Label(fix, systemImage: "lightbulb.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if !generatedRoads.isEmpty {
            GroupBox("Export") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Content", selection: $exportContent) {
                        ForEach(ExportContent.allCases, id: \.self) { content in
                            Text(content.rawValue).tag(content)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Export JSON", systemImage: "doc.text") {
                        exportJSON()
                    }
                    Button("Export OBJ", systemImage: "cube") {
                        exportOBJ()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func applyPreset(_ preset: GenerationPreset) {
        let state = preset.cityState
        population = state.population
        density = state.density
        economicLevel = state.economicLevel
        age = state.age
        ruleConfig = preset.ruleConfiguration
        initialLength = preset.initialRoadLength

        // Auto-adjust cityBounds and start position if terrain is loaded
        if let terrain = terrainMap {
            let dims = terrain.dimensions
            ruleConfig.cityBounds = CGRect(x: 0, y: 0, width: dims.cols, height: dims.rows)
            initialX = Double(dims.cols) / 2
            initialY = Double(dims.rows) / 2
        }

        logger.event("Applied preset: \(preset.rawValue)")
    }

    private func loadASCFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "asc")!]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    do {
                        logger.event("Loading ASC file: \(url.lastPathComponent)")
                        let parser = Terrain.ASCParser()
                        let (header, heights) = try parser.load(from: url)

                        let nodeCount = header.nrows * header.ncols
                        if nodeCount > 1_000_000 {
                            let builder = Terrain.OptimizedTerrainMapBuilder()
                            terrainMap = await builder.buildDownsampledTerrainMap(
                                header: header,
                                heights: heights,
                                downsampleFactor: 4
                            ) { progress, message in
                                logger.debug("\(message): \(progress)")
                            }
                        } else {
                            let builder = Terrain.TerrainMapBuilder()
                            terrainMap = builder.buildTerrainMap(header: header, heights: heights)
                        }

                        terrainFileName = url.lastPathComponent
                        onTerrainLoaded()
                    } catch {
                        loadError = error.localizedDescription
                        showingLoadError = true
                        logger.error("Failed to load ASC file: \(error)")
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
                        logger.event("Loading JSON file: \(url.lastPathComponent)")
                        let serializer = Terrain.TerrainMapSerializer()
                        terrainMap = try serializer.import(from: url)
                        terrainFileName = url.lastPathComponent
                        onTerrainLoaded()
                    } catch {
                        loadError = error.localizedDescription
                        showingLoadError = true
                        logger.error("Failed to load JSON file: \(error)")
                    }
                }
            }
        }
    }

    /// Validates terrain after loading and auto-adjusts cityBounds
    private func onTerrainLoaded() {
        guard let terrain = terrainMap else { return }
        let dims = terrain.dimensions
        logger.info("Terrain loaded: \(dims.cols)×\(dims.rows)")

        // Auto-adjust cityBounds to match terrain
        ruleConfig.cityBounds = CGRect(x: 0, y: 0, width: dims.cols, height: dims.rows)
        initialX = Double(dims.cols) / 2
        initialY = Double(dims.rows) / 2

        // Validate terrain
        terrainWarnings.removeAll()

        // Check for districts
        let samplePoints = [
            (x: 0, y: 0),
            (x: dims.cols / 2, y: dims.rows / 2),
            (x: dims.cols - 1, y: dims.rows - 1)
        ]
        let hasDistricts = samplePoints.contains { pt in
            terrain.getNode(at: pt.x, y: pt.y)?.district != nil
        }
        if !hasDistricts {
            terrainWarnings.append("No districts defined — algorithm will use default residential pattern")
        }

        // Check for universally steep terrain
        let slopeChecks = samplePoints.compactMap { pt in
            terrain.getNode(at: pt.x, y: pt.y)?.slope
        }
        if !slopeChecks.isEmpty && slopeChecks.allSatisfy({ $0 > ruleConfig.maxBuildableSlope }) {
            terrainWarnings.append("Sampled slopes all exceed maxBuildableSlope (\(ruleConfig.maxBuildableSlope)) — roads may not generate")
        }
    }

    private func generateRoads() {
        guard let terrainMap = terrainMap else { return }

        isGenerating = true
        logger.event("Generate roads — start=(\(initialX), \(initialY)), angle=\(initialAngle), length=\(initialLength)")

        Task { @MainActor in
            let cityState = CityState(
                population: population,
                density: density,
                economicLevel: economicLevel,
                age: age
            )

            let generator = RoadGenerator(
                cityState: cityState,
                terrainMap: terrainMap,
                config: ruleConfig
            )

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

            let (roads, report) = generator.generateRoadNetwork(
                initialRoad: initialRoad,
                initialQuery: initialQuery
            )

            generatedRoads = roads
            generationReport = report
            isGenerating = false

            logger.info("Generation finished: \(roads.count) segments in \(report.processingTimeSeconds)s")
        }
    }

    // MARK: - Export

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
                            population: population,
                            density: density,
                            economicLevel: economicLevel,
                            age: age
                        )
                        let config = RoadNetworkSerializer.ConfigurationSnapshot(
                            maxBuildableSlope: ruleConfig.maxBuildableSlope,
                            minUrbanizationFactor: ruleConfig.minUrbanizationFactor,
                            minimumRoadDistance: ruleConfig.minimumRoadDistance
                        )
                        let terrainSnapshot: RoadNetworkSerializer.TerrainSnapshot? = if let terrainMap {
                            RoadNetworkSerializer.TerrainSnapshot(terrainMap: terrainMap)
                        } else {
                            nil
                        }
                        let data = try serializer.export(
                            generatedRoads,
                            cityState: cityState,
                            configuration: config,
                            content: exportContent,
                            terrainSnapshot: terrainSnapshot
                        )
                        try data.write(to: url)
                    } catch {
                        logger.error("Failed to export JSON: \(error)")
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
                    let options = OBJExporter.ExportOptions(content: exportContent)
                    let (obj, mtl) = exporter.export(segments: generatedRoads, terrainMap: terrainMap, options: options)

                    do {
                        let directory = url.deletingLastPathComponent()
                        let basename = url.deletingPathExtension().lastPathComponent
                        try exporter.saveToFiles(obj: obj, mtl: mtl, directory: directory, basename: basename)
                    } catch {
                        logger.error("Failed to export OBJ: \(error)")
                    }
                }
            }
        }
    }

    private func drawRoads(context: GraphicsContext, size: CGSize) {
        guard !generatedRoads.isEmpty else { return }

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

#Preview {
    RoadGeneratorView()
        .frame(width: 1200, height: 800)
}
