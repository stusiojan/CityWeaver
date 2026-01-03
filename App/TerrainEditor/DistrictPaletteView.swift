import SwiftUI
import Terrain

/// UI for selecting districts and painting tools
struct DistrictPaletteView: View {
    @Binding var selectedDistrict: DistrictType
    @Binding var activeTool: PaintTool
    @Binding var brushSize: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // Tool selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ForEach(PaintTool.allCases, id: \.self) { tool in
                        Button {
                            activeTool = tool
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: tool.systemImage)
                                    .font(.title2)
                                Text(tool.displayName)
                                    .font(.caption)
                            }
                            .frame(width: 60, height: 60)
                            .background(activeTool == tool ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(activeTool == tool ? .white : .primary)
                            .clipShape(.rect(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Brush size slider (only for brush tool)
            if activeTool == .brush {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brush Size: \(brushSize)×\(brushSize)")
                        .font(.headline)
                    
                    Slider(value: Binding(
                        get: { Double(brushSize) },
                        set: { brushSize = Int($0) }
                    ), in: 1...20, step: 1)
                }
            }
            
            Divider()
            
            // District selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Districts")
                    .font(.headline)
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(DistrictType.allCases, id: \.self) { district in
                        Button {
                            selectedDistrict = district
                        } label: {
                            HStack {
                                Circle()
                                    .fill(districtColor(district))
                                    .frame(width: 20, height: 20)
                                
                                Text(district.displayName)
                                    .font(.subheadline)
                                
                                Spacer()
                            }
                            .padding(8)
                            .background(selectedDistrict == district ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(.rect(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    /// Get color for district type
    private func districtColor(_ district: DistrictType) -> Color {
        switch district {
        case .business: .blue
        case .oldTown: .orange
        case .residential: .green
        case .industrial: .gray
        case .park: Color(red: 0.2, green: 0.6, blue: 0.2)
        }
    }
}

#Preview {
    DistrictPaletteView(
        selectedDistrict: .constant(.residential),
        activeTool: .constant(.brush),
        brushSize: .constant(1)
    )
    .frame(width: 300)
}

