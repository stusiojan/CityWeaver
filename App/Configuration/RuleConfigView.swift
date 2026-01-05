import SwiftUI
import RoadGeneration
import Terrain

/// View for configuring road generation rules
struct RuleConfigView: View {
    @Binding var config: RuleConfiguration
    
    @State private var selectedTab: ConfigTab = .boundaries
    
    enum ConfigTab: String, CaseIterable {
        case boundaries = "Boundaries"
        case angles = "Angles"
        case distances = "Distances"
        case terrain = "Terrain"
        case goals = "Goals"
        case timing = "Timing"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Configuration Section", selection: $selectedTab) {
                ForEach(ConfigTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Content area
            ScrollView {
                Group {
                    switch selectedTab {
                    case .boundaries:
                        boundariesSection
                    case .angles:
                        anglesSection
                    case .distances:
                        distancesSection
                    case .terrain:
                        terrainSection
                    case .goals:
                        goalsSection
                    case .timing:
                        timingSection
                    }
                }
                .padding()
            }
            
            // Actions
            HStack {
                Button("Reset to Defaults", systemImage: "arrow.counterclockwise") {
                    resetToDefaults()
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Button("Save Profile", systemImage: "square.and.arrow.down") {
                    saveProfile()
                }
                
                Button("Load Profile", systemImage: "square.and.arrow.up") {
                    loadProfile()
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
    }
    
    // MARK: - Sections
    
    private var boundariesSection: some View {
        Form {
            Section("City Bounds") {
                HStack {
                    Text("Origin X:")
                    Spacer()
                    TextField("X", value: Binding(
                        get: { Double(config.cityBounds.origin.x) },
                        set: { newValue in
                            config.cityBounds = CGRect(
                                origin: CGPoint(x: CGFloat(newValue), y: config.cityBounds.origin.y),
                                size: config.cityBounds.size
                            )
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }
                
                HStack {
                    Text("Origin Y:")
                    Spacer()
                    TextField("Y", value: Binding(
                        get: { Double(config.cityBounds.origin.y) },
                        set: { newValue in
                            config.cityBounds = CGRect(
                                origin: CGPoint(x: config.cityBounds.origin.x, y: CGFloat(newValue)),
                                size: config.cityBounds.size
                            )
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }
                
                HStack {
                    Text("Width:")
                    Spacer()
                    TextField("Width", value: Binding(
                        get: { Double(config.cityBounds.width) },
                        set: { newValue in
                            config.cityBounds = CGRect(
                                origin: config.cityBounds.origin,
                                size: CGSize(width: CGFloat(newValue), height: config.cityBounds.height)
                            )
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }
                
                HStack {
                    Text("Height:")
                    Spacer()
                    TextField("Height", value: Binding(
                        get: { Double(config.cityBounds.height) },
                        set: { newValue in
                            config.cityBounds = CGRect(
                                origin: config.cityBounds.origin,
                                size: CGSize(width: config.cityBounds.width, height: CGFloat(newValue))
                            )
                        }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var anglesSection: some View {
        Form {
            Section("Main Road Angles") {
                VStack(alignment: .leading) {
                    Text("Minimum Angle: \(Int(config.mainRoadAngleMin * 180 / .pi))°")
                    Slider(value: $config.mainRoadAngleMin, in: 0...(.pi), step: .pi/36)
                }
                
                VStack(alignment: .leading) {
                    Text("Maximum Angle: \(Int(config.mainRoadAngleMax * 180 / .pi))°")
                    Slider(value: $config.mainRoadAngleMax, in: 0...(.pi), step: .pi/36)
                }
                
                Text("Main roads require more controlled intersection angles for safety")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Internal Road Angles") {
                VStack(alignment: .leading) {
                    Text("Minimum Angle: \(Int(config.internalRoadAngleMin * 180 / .pi))°")
                    Slider(value: $config.internalRoadAngleMin, in: 0...(.pi), step: .pi/36)
                }
                
                VStack(alignment: .leading) {
                    Text("Maximum Angle: \(Int(config.internalRoadAngleMax * 180 / .pi))°")
                    Slider(value: $config.internalRoadAngleMax, in: 0...(.pi), step: .pi/36)
                }
                
                Text("Internal roads can have wider angle ranges")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    private var distancesSection: some View {
        Form {
            Section("Road Spacing") {
                VStack(alignment: .leading) {
                    Text("Minimum Road Distance: \(config.minimumRoadDistance, format: .number.precision(.fractionLength(1)))m")
                    Slider(value: $config.minimumRoadDistance, in: 1...50, step: 1)
                }
                
                Text("Minimum distance between parallel roads")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Intersection Spacing") {
                VStack(alignment: .leading) {
                    Text("Minimum Spacing: \(config.intersectionMinSpacing, format: .number.precision(.fractionLength(0)))m")
                    Slider(value: $config.intersectionMinSpacing, in: 10...200, step: 10)
                }
                
                Text("Minimum distance between intersections on same road")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    private var terrainSection: some View {
        Form {
            Section("Slope Constraints") {
                VStack(alignment: .leading) {
                    Text("Max Buildable Slope: \(config.maxBuildableSlope, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $config.maxBuildableSlope, in: 0.1...1.0, step: 0.05)
                }
                
                Text("Maximum terrain slope for road construction (0 = flat, 1 = 45°)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Urbanization") {
                VStack(alignment: .leading) {
                    Text("Min Urbanization Factor: \(config.minUrbanizationFactor, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $config.minUrbanizationFactor, in: 0...1, step: 0.05)
                }
                
                Text("Minimum terrain suitability for development (0 = unsuitable, 1 = ideal)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    private var goalsSection: some View {
        Form {
            Section("District-Specific Goals") {
                ForEach(Terrain.DistrictType.allCases, id: \.self) { district in
                    DisclosureGroup(district.displayName) {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading) {
                                Text("Branching Probability: \(config.branchingProbability[district] ?? 0.5, format: .number.precision(.fractionLength(2)))")
                                Slider(value: Binding(
                                    get: { config.branchingProbability[district] ?? 0.5 },
                                    set: { config.branchingProbability[district] = $0 }
                                ), in: 0...1, step: 0.05)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Length Multiplier: \(config.roadLengthMultiplier[district] ?? 0.8, format: .number.precision(.fractionLength(2)))")
                                Slider(value: Binding(
                                    get: { config.roadLengthMultiplier[district] ?? 0.8 },
                                    set: { config.roadLengthMultiplier[district] = $0 }
                                ), in: 0.3...2.0, step: 0.1)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            
            Section("Coastal Development") {
                VStack(alignment: .leading) {
                    Text("Growth Bias: \(config.coastalGrowthBias, format: .number.precision(.fractionLength(2)))")
                    Slider(value: $config.coastalGrowthBias, in: 0...1, step: 0.05)
                }
                
                Text("Preference for growth along coastal areas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    private var timingSection: some View {
        Form {
            Section("Generation Timing") {
                VStack(alignment: .leading) {
                    Text("Default Delay: \(config.defaultDelay) ticks")
                    Stepper(value: $config.defaultDelay, in: 1...10) {
                        EmptyView()
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Branch Delay: \(config.branchDelay) ticks")
                    Stepper(value: $config.branchDelay, in: 1...20) {
                        EmptyView()
                    }
                }
                
                Text("Delay controls the priority of road generation in the queue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Actions
    
    private func resetToDefaults() {
        withAnimation {
            config = RuleConfiguration()
        }
    }
    
    private func saveProfile() {
        // Create a simplified dictionary for JSON serialization
        let profile: [String: Any] = [
            "maxBuildableSlope": config.maxBuildableSlope,
            "minUrbanizationFactor": config.minUrbanizationFactor,
            "minimumRoadDistance": config.minimumRoadDistance,
            "intersectionMinSpacing": config.intersectionMinSpacing,
            "mainRoadAngleMin": config.mainRoadAngleMin,
            "mainRoadAngleMax": config.mainRoadAngleMax,
            "defaultDelay": config.defaultDelay,
            "branchDelay": config.branchDelay
        ]
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "rule_config.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted])
                    try data.write(to: url)
                } catch {
                    print("Failed to save profile: \(error)")
                }
            }
        }
    }
    
    private func loadProfile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let profile = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    withAnimation {
                        if let slope = profile?["maxBuildableSlope"] as? Double {
                            config.maxBuildableSlope = slope
                        }
                        if let urbanization = profile?["minUrbanizationFactor"] as? Double {
                            config.minUrbanizationFactor = urbanization
                        }
                        if let distance = profile?["minimumRoadDistance"] as? Double {
                            config.minimumRoadDistance = distance
                        }
                        if let spacing = profile?["intersectionMinSpacing"] as? Double {
                            config.intersectionMinSpacing = spacing
                        }
                        if let angleMin = profile?["mainRoadAngleMin"] as? Double {
                            config.mainRoadAngleMin = angleMin
                        }
                        if let angleMax = profile?["mainRoadAngleMax"] as? Double {
                            config.mainRoadAngleMax = angleMax
                        }
                        if let delay = profile?["defaultDelay"] as? Int {
                            config.defaultDelay = delay
                        }
                        if let branchDelay = profile?["branchDelay"] as? Int {
                            config.branchDelay = branchDelay
                        }
                    }
                } catch {
                    print("Failed to load profile: \(error)")
                }
            }
        }
    }
}

#Preview {
    RuleConfigView(config: .constant(RuleConfiguration()))
        .frame(width: 700, height: 600)
}

