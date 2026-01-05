import SwiftUI
import RoadGeneration

/// View for configuring city state parameters
struct CityStateConfigView: View {
    @Binding var population: Int
    @Binding var density: Double
    @Binding var economicLevel: Double
    @Binding var age: Int
    
    /// Preset configurations
    enum Preset: String, CaseIterable {
        case smallTown = "Small Town"
        case growingCity = "Growing City"
        case metropolis = "Metropolis"
        case megacity = "Megacity"
        
        var configuration: (population: Int, density: Double, economicLevel: Double, age: Int) {
            switch self {
            case .smallTown:
                return (10_000, 800, 0.4, 5)
            case .growingCity:
                return (50_000, 1_500, 0.6, 15)
            case .metropolis:
                return (200_000, 3_000, 0.8, 30)
            case .megacity:
                return (1_000_000, 5_000, 0.9, 50)
            }
        }
    }
    
    @State private var showingPresets = false
    @State private var populationString: String = ""
    
    var body: some View {
        Form {
            Section("Quick Presets") {
                HStack {
                    ForEach(Preset.allCases, id: \.self) { preset in
                        Button(preset.rawValue) {
                            applyPreset(preset)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            
            Section("Population") {
                HStack {
                    Text("Population:")
                    Spacer()
                    TextField("Population", value: $population, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .multilineTextAlignment(.trailing)
                }
                
                Slider(value: Binding(
                    get: { Double(population) },
                    set: { population = Int($0) }
                ), in: 1_000...2_000_000, step: 1_000)
                
                Text("\(population, format: .number) people")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Density") {
                HStack {
                    Text("Density:")
                    Spacer()
                    TextField("Density", value: $density, format: .number.precision(.fractionLength(0)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .multilineTextAlignment(.trailing)
                    Text("per km²")
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: $density, in: 100...10_000, step: 100)
                
                Text(densityDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Economic Development") {
                HStack {
                    Text("Economic Level:")
                    Spacer()
                    TextField("Level", value: $economicLevel, format: .number.precision(.fractionLength(2)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                }
                
                Slider(value: $economicLevel, in: 0...1, step: 0.05)
                
                HStack {
                    Text("Low")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Medium")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("High")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Section("City Age") {
                HStack {
                    Text("Age:")
                    Spacer()
                    TextField("Age", value: $age, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .multilineTextAlignment(.trailing)
                    Text("years")
                        .foregroundStyle(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(age) },
                    set: { age = Int($0) }
                ), in: 0...100, step: 1)
                
                Text(ageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Actions") {
                HStack {
                    Button("Save Configuration", systemImage: "square.and.arrow.down") {
                        saveConfiguration()
                    }
                    
                    Button("Load Configuration", systemImage: "square.and.arrow.up") {
                        loadConfiguration()
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults", systemImage: "arrow.counterclockwise") {
                        resetToDefaults()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var densityDescription: String {
        switch density {
        case ..<500:
            return "Rural area"
        case 500..<1500:
            return "Suburban area"
        case 1500..<3000:
            return "Urban area"
        case 3000..<6000:
            return "Dense urban area"
        default:
            return "Very dense urban area"
        }
    }
    
    private var ageDescription: String {
        switch age {
        case 0:
            return "New settlement"
        case 1..<10:
            return "Young city"
        case 10..<30:
            return "Established city"
        case 30..<60:
            return "Mature city"
        default:
            return "Historic city"
        }
    }
    
    private func applyPreset(_ preset: Preset) {
        let config = preset.configuration
        withAnimation {
            population = config.population
            density = config.density
            economicLevel = config.economicLevel
            age = config.age
        }
    }
    
    private func resetToDefaults() {
        withAnimation {
            applyPreset(.growingCity)
        }
    }
    
    private func saveConfiguration() {
        let config = [
            "population": population,
            "density": density,
            "economicLevel": economicLevel,
            "age": age
        ] as [String: Any]
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "city_state.json"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
                    try data.write(to: url)
                } catch {
                    print("Failed to save configuration: \(error)")
                }
            }
        }
    }
    
    private func loadConfiguration() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    let config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    
                    withAnimation {
                        if let pop = config?["population"] as? Int {
                            population = pop
                        }
                        if let dens = config?["density"] as? Double {
                            density = dens
                        }
                        if let econ = config?["economicLevel"] as? Double {
                            economicLevel = econ
                        }
                        if let cityAge = config?["age"] as? Int {
                            age = cityAge
                        }
                    }
                } catch {
                    print("Failed to load configuration: \(error)")
                }
            }
        }
    }
}

#Preview {
    CityStateConfigView(
        population: .constant(50_000),
        density: .constant(1_500),
        economicLevel: .constant(0.6),
        age: .constant(15)
    )
    .frame(width: 600, height: 700)
}

