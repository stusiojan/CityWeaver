# CityWeaver User Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Getting Started](#getting-started)
3. [Terrain Preparation](#terrain-preparation)
4. [District Painting](#district-painting)
5. [Configuring City Parameters](#configuring-city-parameters)
6. [Generating Roads](#generating-roads)
7. [Visualizing Results](#visualizing-results)
8. [Exporting](#exporting)
9. [Troubleshooting](#troubleshooting)
10. [Tips and Best Practices](#tips-and-best-practices)

---

## Introduction

CityWeaver is a procedural city road generation tool that creates realistic road networks based on terrain data, urban planning rules, and configurable city parameters. The system uses a priority queue-based algorithm with flexible constraint and goal rules to generate roads that respect terrain features, district boundaries, and urban development patterns.

**Key Features:**
- Import real-world terrain data from ASC files
- Paint and manage city districts
- Configure city parameters and generation rules
- Generate realistic road networks
- Visualize results in 2D and 3D
- Export to JSON, OBJ (Blender), and glTF formats

---

## Getting Started

### System Requirements

- macOS 15.0 or later
- Xcode 15.0 or later (for building)
- Swift 6.0 or later

### Quick Start

1. Launch CityWeaver
2. Navigate to the "Terrain Editor" tab
3. Load terrain data (ASC or JSON file)
4. Paint districts on the terrain
5. Switch to "Road Generation" tab
6. Configure city parameters
7. Click "Generate Roads"
8. View and export results

---

## Terrain Preparation

### Loading ASC Files

ASC (ASCII Grid) files are standard ESRI terrain format files containing elevation data.

**Steps:**
1. Go to "Terrain Editor" tab
2. Click "Load ASC File"
3. Select your `.asc` file
4. Wait for processing (large files may take a minute)

**File Format Example:**
```
ncols         2229
nrows         2323
xllcenter     513329.00
yllcenter     276352.00
cellsize      1.00
nodata_value  -9999
<elevation data...>
```

**Performance Tips:**
- Files < 1M nodes: Loaded instantly
- Files > 1M nodes: Automatically downsampled
- Files > 4M nodes: 4x downsampling applied (~400MB → ~25MB RAM)

### Loading Previously Saved Maps

If you've already prepared a terrain with districts:

1. Click "Load JSON"
2. Select your `terrain_map.json` file
3. Districts and elevation data load instantly

### Understanding Terrain Properties

Each terrain point has:
- **Elevation (z)**: Height above sea level
- **Slope**: Steepness (0-1, where 0=flat, 1=vertical)
- **Urbanization Factor**: Buildability (0-1, derived from slope)
- **District**: Optional city zone classification

---

## District Painting

Districts define different city zones with unique road generation patterns.

### Available Districts

- **Business**: Dense grid pattern, straight roads, 90° intersections
- **Old Town**: Organic layout, irregular angles, narrow roads
- **Residential**: Moderate density, curved streets
- **Industrial**: Wide roads, large blocks
- **Park**: Minimal roads, natural patterns

### Painting Tools

#### Brush Tool (B)
- **Purpose**: Paint individual cells or small areas
- **Size**: Adjustable 1-20 cells
- **Usage**:
  1. Select district color from palette
  2. Click "Brush" or press `B`
  3. Adjust brush size with slider
  4. Click and drag on terrain

#### Fill Tool (F)
- **Purpose**: Fill large connected areas
- **Usage**:
  1. Select district color
  2. Click "Fill" or press `F`
  3. Click on area to fill
  4. All connected cells with same properties are filled

#### Eraser (E)
- **Purpose**: Remove district assignments
- **Usage**:
  1. Click "Eraser" or press `E`
  2. Click or drag to remove districts

### Navigation

- **Pan**: Click and drag (when not painting)
- **Zoom**: Pinch (trackpad) or scroll wheel (mouse)
- **Zoom Range**: 0.1x to 10x
- **Grid**: Appears automatically when zoomed > 2.0x

### Undo/Redo

- **Undo**: `⌘Z`
- **Redo**: `⇧⌘Z`
- Unlimited undo history

### Validation

Before generating roads, validate your districts:

1. Click "Validate Districts"
2. Check for errors:
   - **Disconnected fragments**: Districts must be contiguous
   - Fix by painting connecting cells

### Saving Your Work

1. Click "Export Map"
2. Choose location
3. Saves as JSON with:
   - Terrain elevation data
   - District assignments
   - Calculated properties (slope, urbanization)

---

## Configuring City Parameters

### City State Configuration

Access: Click "Configure City State" in Road Generation tab

#### Population
- **Range**: 1,000 - 2,000,000
- **Effect**: Influences road density and branching
- **Presets**:
  - Small Town: 10,000
  - Growing City: 50,000
  - Metropolis: 200,000
  - Megacity: 1,000,000

#### Density (per km²)
- **Range**: 100 - 10,000
- **Effect**: Affects road spacing and network density
- **Categories**:
  - < 500: Rural
  - 500-1,500: Suburban
  - 1,500-3,000: Urban
  - 3,000-6,000: Dense urban
  - > 6,000: Very dense

#### Economic Level
- **Range**: 0.0 - 1.0
- **Effect**: Influences road quality and pattern regularity
- **Low (0.0-0.3)**: Irregular, organic patterns
- **Medium (0.4-0.7)**: Balanced
- **High (0.8-1.0)**: Regular grids, planned layouts

#### City Age (years)
- **Range**: 0 - 100
- **Effect**: Determines rule complexity
- **New (0)**: Simplified rules
- **Young (1-10)**: Basic angle constraints added
- **Established (10-30)**: Full constraint set
- **Mature (30-60)**: Additional connectivity rules
- **Historic (60+)**: Complex historical patterns

#### Saving/Loading Configurations

- **Save**: Exports settings to JSON
- **Load**: Imports previously saved settings
- Useful for comparing different city scenarios

### Rule Configuration

Access: Click "Configure Rules" in Road Generation tab

#### Boundaries Section
- **City Bounds**: Define generation area (origin X/Y, width, height)
- Roads will not extend beyond these bounds

#### Angles Section
- **Main Road Angles**: 60°-170° (safety requirement)
- **Internal Road Angles**: 30°-180° (more flexible)
- Adjust for different intersection styles

#### Distances Section
- **Minimum Road Distance**: 1-50m between parallel roads
- **Intersection Spacing**: 10-200m between intersections
- Affects block sizes

#### Terrain Section
- **Max Buildable Slope**: 0.1-1.0 (default 0.3 = ~17°)
- **Min Urbanization Factor**: 0.0-1.0 (default 0.2)
- Higher values = more restrictions

#### Goals Section

District-specific parameters:

**Branching Probability** (0-1):
- How often roads branch
- Business: 0.7 (frequent branching)
- Old Town: 0.9 (very frequent)
- Residential: 0.6
- Industrial: 0.5
- Park: 0.3 (minimal branching)

**Length Multiplier** (0.3-2.0):
- Relative road length
- Business: 1.0 (standard)
- Old Town: 0.6 (short, winding)
- Residential: 0.8
- Industrial: 1.2 (long, straight)
- Park: 0.5

**Coastal Growth Bias** (0-1):
- Preference for coastal development
- Higher = more roads along water

#### Timing Section
- **Default Delay**: Priority for continuing roads
- **Branch Delay**: Priority for new branches
- Higher delay = lower priority in queue

#### Saving/Loading Profiles

- Save multiple rule configurations
- Quickly switch between scenarios
- Compare generation results

---

## Generating Roads

### Initial Road Placement

The initial road serves as the seed for network generation.

**Parameters:**
- **Start X/Y**: World coordinates for road start
- **Angle**: Direction in radians (0 = east, π/2 = north)
- **Length**: Initial segment length in meters
- Tip: Place in flat, central area for best results

### Generation Process

1. **Configure all parameters**
2. **Load terrain** with districts
3. **Set initial road placement**
4. **Click "Generate Roads"**
5. **Wait for completion** (progress shown)

**What Happens:**
1. Initial road added to priority queue
2. Road validated against constraints
3. If valid, road accepted and goals generate new proposals
4. New proposals added to queue with priorities
5. Process repeats until queue empty

**Performance:**
- Small maps (< 50×50): < 1 second
- Medium maps (< 200×200): 1-5 seconds
- Large maps (< 1000×1000): 5-30 seconds

### Statistics

After generation, view:
- **Segments**: Number of road segments
- **Generation Time**: Processing duration
- **Total Length**: Combined road length

### Regeneration

To generate again with different parameters:
1. Click "Clear Roads"
2. Adjust parameters
3. Click "Generate Roads"

---

## Visualizing Results

### 2D Canvas View

**Simple Demo Tab:**
- Basic 2D visualization
- Auto-scales to fit roads
- Color-coded by road type:
  - Blue: Main/Highway
  - Gray: Residential
  - Light Gray: Street

**Features:**
- Automatic bounds calculation
- Scaled to fit window
- Real-time rendering

### 3D Visualization

Switch to "3D Scene" view for advanced visualization.

**Controls:**
- **Rotate**: Click and drag
- **Zoom**: Scroll wheel or pinch
- **Pan**: Option + drag
- **Reset**: Double-click

**Display Options:**
- **Show Terrain**: Toggle terrain mesh
- **Show Roads**: Toggle road display
- **Show Grid**: Reference grid helper
- **Vertical Scale**: 0.1-5.0x terrain height
- **Terrain Detail**: Downsampling factor (1-10x)

**Materials:**
- Roads: Dark gray with slight specular
- Terrain: Brown/tan with subtle shading
- Different road types have different tints

**Performance Tips:**
- Increase terrain downsampling for smoother rendering
- Disable terrain for road-only view
- Lower vertical scale for flat visualizations

---

## Exporting

### JSON Export

**Purpose**: Save road network with metadata

**Contains:**
- Road segments (start, angle, length, type)
- Generation metadata (timestamp)
- City state snapshot
- Configuration used
- Unique segment IDs

**Usage:**
1. Click "Export Roads"
2. Select "Export as JSON"
3. Choose location
4. File saved as `road_network.json`

**Use Cases:**
- Archiving generations
- Comparing different configurations
- Re-importing for further editing
- Data analysis

### OBJ Export (Blender)

**Purpose**: 3D model for rendering in Blender

**Contains:**
- Road geometry (rectangular prisms)
- Optional terrain mesh
- Material definitions (.mtl file)
- Proper elevation from terrain

**Options:**
- **Road Width**: Default 4.0m
- **Include Terrain**: Yes/No
- **Terrain Downsampling**: Performance vs. detail
- **Vertical Scale**: Exaggerate elevation

**Usage:**
1. Click "Export Roads"
2. Select "Export as OBJ (Blender)"
3. Choose location
4. Two files created: `.obj` and `.mtl`

**Importing to Blender:**
1. Open Blender
2. File → Import → Wavefront (.obj)
3. Select your `.obj` file
4. Roads and terrain appear with materials
5. Render or modify as needed

### glTF Export

**Purpose**: Modern 3D format with better material support

**Contains:**
- Road geometry
- PBR materials (metallic/roughness)
- Optional terrain mesh
- Efficient binary encoding

**Options:**
- **Embed Binary**: Single file vs. separate .bin
- All other options same as OBJ

**Usage:**
1. Click "Export Roads"
2. Select "Export as glTF"
3. Choose location
4. File(s) created: `.gltf` (and optionally `.bin`)

**Use Cases:**
- Game engines (Unity, Unreal)
- Web 3D viewers
- Better material fidelity than OBJ
- Animation-ready format

---

## Troubleshooting

### No Roads Generated

**Problem**: "Generate Roads" produces empty or very few roads

**Solutions:**
1. **Check terrain bounds**: Ensure initial road is within city bounds
2. **Verify terrain data**: Load terrain successfully before generating
3. **Relax constraints**:
   - Increase max buildable slope
   - Decrease min urbanization factor
   - Reduce minimum road distance
4. **Check initial placement**: Place on flat, buildable terrain
5. **Increase city age**: Age 0 might be too restrictive

### Roads Don't Respect Districts

**Problem**: Roads cross district boundaries unexpectedly

**Solutions:**
1. **Main roads can cross**: Only internal roads are blocked by district boundaries
2. **Set isMainRoad**: In initial query, set `isMainRoad: false` for stricter boundaries
3. **Validate districts**: Ensure districts are contiguous
4. **Paint more carefully**: Verify district edges are clear

### Performance Issues

**Problem**: Generation takes too long

**Solutions:**
1. **Reduce map size**: Downsample terrain before loading
2. **Simplify constraints**: Fewer rules = faster generation
3. **Limit branching**: Reduce branching probabilities
4. **Smaller initial length**: Shorter roads = faster convergence
5. **Reduce city bounds**: Generate in smaller area

### Visualization Problems

**Problem**: 3D view is slow or laggy

**Solutions:**
1. **Increase terrain downsampling**: 5-10x for large maps
2. **Disable terrain**: Focus on roads only
3. **Reduce vertical scale**: Less geometry deformation
4. **Close other apps**: Free up GPU resources
5. **Lower road count**: Generate fewer roads

### Export Fails

**Problem**: Cannot export files

**Solutions:**
1. **Check permissions**: Ensure write access to destination
2. **Verify disk space**: Exports can be large with terrain
3. **Try different format**: JSON always works, try that first
4. **Check file names**: Avoid special characters
5. **Disable terrain**: Export roads only if terrain export fails

---

## Tips and Best Practices

### Terrain Preparation

- **Use realistic data**: Real ASC files produce best results
- **Paint large districts**: Small fragments may not generate well
- **Contiguous districts**: Avoid isolated district cells
- **Mix district types**: Variety creates more interesting networks
- **Validate before generating**: Fix all validation errors

### Parameter Configuration

- **Start conservative**: Use presets, then adjust incrementally
- **Match real cities**: Research similar real-world cities
- **Age matters**: Start with age 10-15 for balanced rules
- **Save configurations**: Document successful configurations
- **Test on small areas**: Verify parameters before full generation

### Road Generation

- **Central placement**: Start initial road in map center
- **Main roads first**: Set isMainRoad: true for backbone
- **Iterative generation**: Generate, evaluate, adjust, repeat
- **Multiple seeds**: Try different initial placements
- **Document results**: Keep notes on parameter effects

### Visualization

- **Use 3D for understanding**: Better spatial awareness
- **Use 2D for quick checks**: Faster rendering
- **Adjust vertical scale**: Emphasize or flatten terrain
- **Take screenshots**: Document interesting results
- **Compare views**: Switch between 2D and 3D

### Exporting

- **Export early and often**: Don't lose work
- **JSON for archival**: Complete data preservation
- **OBJ for rendering**: Best Blender compatibility
- **glTF for games**: If targeting game engines
- **Test imports**: Verify exports open correctly
- **Organize files**: Use descriptive names and folders

### Workflow Optimization

1. **Prepare template terrains**: Save commonly used maps
2. **Create configuration library**: Collection of rule sets
3. **Batch process**: Queue multiple generations
4. **Document findings**: Track what works
5. **Share results**: Export and archive successful cities

### Common Workflows

**Quick Test:**
1. Load test.asc
2. Paint one district
3. Use "Growing City" preset
4. Default rules
5. Generate
6. View in 2D

**Realistic City:**
1. Load real terrain data
2. Carefully paint multiple districts
3. Research real city parameters
4. Configure detailed rules
5. Generate multiple times
6. Export to Blender for rendering

**Comparison Study:**
1. Prepare terrain with districts
2. Export terrain JSON
3. Save city state configuration A
4. Generate and export roads A
5. Load same terrain
6. Load city state configuration B
7. Generate and export roads B
8. Compare in 3D viewer

---

## Advanced Topics

### Understanding the Algorithm

The road generator uses a priority queue where:
- Lower time = higher priority
- Main roads processed before branches
- Delays control road hierarchy
- Constraints act as filters
- Goals generate new proposals

### Custom Rule Development

Future versions will support custom rules. Prepare by:
- Understanding existing rules
- Documenting desired behaviors
- Testing with available parameters
- Providing feedback

### Integration with Other Tools

**GIS Software:**
- Export JSON
- Convert to GeoJSON (custom tool)
- Import into QGIS/ArcGIS

**Game Engines:**
- Export glTF
- Import to Unity/Unreal
- Apply game materials
- Add collision meshes

**Rendering Software:**
- Export OBJ
- Import to Blender/3ds Max/Cinema 4D
- Apply photorealistic materials
- Add lighting and camera
- Render final images/animations

---

## Keyboard Shortcuts

### Terrain Editor
- `B` - Brush tool
- `F` - Fill tool
- `E` - Eraser
- `⌘Z` - Undo
- `⇧⌘Z` - Redo
- `⌘S` - Save (if implemented)
- `⌘O` - Open (if implemented)

### General
- `⌘Q` - Quit application
- `⌘,` - Preferences (if implemented)

---

## Glossary

- **ASC File**: ASCII Grid format for elevation data
- **Constraint Rule**: Validation rule that can reject roads
- **District**: City zone with specific generation rules
- **Goal Rule**: Rule that generates new road proposals
- **Priority Queue**: Data structure ordering roads by importance
- **Road Segment**: Single piece of road with start, angle, length
- **Terrain Node**: Single grid point with elevation and properties
- **Urbanization Factor**: Buildability score derived from slope

---

## Getting Help

### Resources

- **Architecture Document**: `doc/architecture.md` - Technical details
- **README**: Project overview and build instructions
- **Source Code**: Well-commented implementation
- **Tests**: Examples of expected behavior

### Reporting Issues

When reporting problems, include:
1. macOS version
2. CityWeaver version
3. Steps to reproduce
4. Expected vs. actual behavior
5. Terrain file info (size, format)
6. Screenshots if relevant
7. Generated road count
8. Configuration used

### Community

Share your cities and configurations!
- Export interesting results
- Document parameter combinations
- Report what works well
- Suggest improvements

---

## Conclusion

CityWeaver provides powerful tools for procedural city generation. Experiment with different parameters, study real cities, and create unique urban landscapes. The system is designed to be flexible and extensible, so your feedback helps improve future versions.

Happy city building! 🏙️

