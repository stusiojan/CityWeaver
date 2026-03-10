import SwiftUI
import Terrain

/// Reusable form for parametric terrain generation
struct TerrainGeneratorFormView: View {
    var onGenerate: (Terrain.TerrainMap) -> Void

    // MARK: - Terrain Shape

    enum TerrainType: String, CaseIterable, Identifiable {
        case flat = "Flat"
        case slope = "Slope"
        case hilly = "Hilly"

        var id: String { rawValue }
    }

    @State private var terrainType: TerrainType = .flat
    @State private var cols: Int = 200
    @State private var rows: Int = 200
    @State private var cellsize: Double = 1

    // Flat
    @State private var flatHeight: Double = 0

    // Slope
    @State private var slopeFromHeight: Double = 0
    @State private var slopeToHeight: Double = 100
    @State private var slopeDirection: TerrainGenerator.SlopeDirection = .northToSouth

    // Hilly
    @State private var hillyBaseHeight: Double = 100
    @State private var hillyAmplitude: Double = 50
    @State private var hillyFrequency: Double = 0.05

    // MARK: - Districts

    @State private var applyDistricts = false

    enum DistrictLayoutMode: String, CaseIterable, Identifiable {
        case single = "Single District"
        case grid = "Grid Layout"

        var id: String { rawValue }
    }

    @State private var districtLayoutMode: DistrictLayoutMode = .single
    @State private var singleDistrictType: DistrictType = .residential
    @State private var gridDistricts: [DistrictType] = [.business, .residential, .oldTown, .industrial]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            terrainTypeSection
            dimensionsSection
            typeParametersSection

            Divider()

            districtsSection

            Button("Generate", systemImage: "wand.and.stars", action: generate)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    // MARK: - Sections

    private var terrainTypeSection: some View {
        Picker("Type", selection: $terrainType) {
            ForEach(TerrainType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dimensionsSection: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Columns:")
                TextField("Cols", value: $cols, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("Rows:")
                TextField("Rows", value: $rows, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("Cell size:")
                HStack {
                    TextField("Size", value: $cellsize, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                    Text("m")
                }
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private var typeParametersSection: some View {
        switch terrainType {
        case .flat:
            flatParametersSection
        case .slope:
            slopeParametersSection
        case .hilly:
            hillyParametersSection
        }
    }

    private var flatParametersSection: some View {
        HStack {
            Text("Height:")
            TextField("Height", value: $flatHeight, format: .number.precision(.fractionLength(1)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
        }
        .font(.caption)
    }

    private var slopeParametersSection: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("From height:")
                TextField("From", value: $slopeFromHeight, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("To height:")
                TextField("To", value: $slopeToHeight, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("Direction:")
                Picker("Direction", selection: $slopeDirection) {
                    Text("N → S").tag(TerrainGenerator.SlopeDirection.northToSouth)
                    Text("S → N").tag(TerrainGenerator.SlopeDirection.southToNorth)
                    Text("W → E").tag(TerrainGenerator.SlopeDirection.westToEast)
                    Text("E → W").tag(TerrainGenerator.SlopeDirection.eastToWest)
                }
                .labelsHidden()
            }
        }
        .font(.caption)
    }

    private var hillyParametersSection: some View {
        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Base height:")
                TextField("Base", value: $hillyBaseHeight, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("Amplitude:")
                TextField("Amp", value: $hillyAmplitude, format: .number.precision(.fractionLength(1)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
            GridRow {
                Text("Frequency:")
                TextField("Freq", value: $hillyFrequency, format: .number.precision(.fractionLength(3)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
            }
        }
        .font(.caption)
    }

    private var districtsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Apply city zones", isOn: $applyDistricts)
                .font(.caption)

            if applyDistricts {
                Picker("Layout", selection: $districtLayoutMode) {
                    ForEach(DistrictLayoutMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .font(.caption)

                if districtLayoutMode == .single {
                    Picker("District", selection: $singleDistrictType) {
                        ForEach(DistrictType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .font(.caption)
                } else {
                    gridDistrictSelector
                }
            }
        }
    }

    private var gridDistrictSelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Grid districts:")
                .font(.caption)

            ForEach(DistrictType.allCases, id: \.self) { type in
                Toggle(type.displayName, isOn: Binding(
                    get: { gridDistricts.contains(type) },
                    set: { included in
                        if included {
                            gridDistricts.append(type)
                        } else {
                            gridDistricts.removeAll { $0 == type }
                        }
                    }
                ))
                .font(.caption)
            }
        }
    }

    // MARK: - Generation

    private func generate() {
        let map: TerrainMap
        switch terrainType {
        case .flat:
            map = TerrainGenerator.flat(cols: cols, rows: rows, height: flatHeight, cellsize: cellsize)
        case .slope:
            map = TerrainGenerator.slope(
                cols: cols, rows: rows,
                fromHeight: slopeFromHeight, toHeight: slopeToHeight,
                direction: slopeDirection, cellsize: cellsize
            )
        case .hilly:
            map = TerrainGenerator.hilly(
                cols: cols, rows: rows,
                baseHeight: hillyBaseHeight, amplitude: hillyAmplitude,
                frequency: hillyFrequency, cellsize: cellsize
            )
        }

        if applyDistricts {
            switch districtLayoutMode {
            case .single:
                DistrictLayout.paintAll(on: map, district: singleDistrictType)
            case .grid:
                if !gridDistricts.isEmpty {
                    DistrictLayout.paintGrid(on: map, districts: gridDistricts)
                }
            }
        }

        onGenerate(map)
    }
}

#Preview {
    TerrainGeneratorFormView { _ in }
        .padding()
        .frame(width: 350)
}
