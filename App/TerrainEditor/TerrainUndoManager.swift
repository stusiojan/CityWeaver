import Terrain
import SwiftUI

/// Undo/Redo manager for terrain editing operations
@MainActor
final class TerrainUndoManager: ObservableObject {
    private var undoStack: [TerrainSnapshot] = []
    private var redoStack: [TerrainSnapshot] = []
    private let maxStackSize = 50
    
    @MainActor struct TerrainSnapshot {
        let districtAssignments: [String: DistrictType?]  // "x,y" -> district
        let timestamp: Date
        
        @MainActor init(from map: TerrainMap) {
            var assignments: [String: DistrictType?] = [:]
            let dimensions = map.dimensions
            
            for y in 0..<dimensions.rows {
                for x in 0..<dimensions.cols {
                    if let node = map.getNode(at: x, y: y), node.district != nil {
                        assignments["\(x),\(y)"] = node.district
                    }
                }
            }
            
            self.districtAssignments = assignments
            self.timestamp = Date()
        }
        
        @MainActor func apply(to map: TerrainMap) {
            let dimensions = map.dimensions
            
            // Clear all districts first
            for y in 0..<dimensions.rows {
                for x in 0..<dimensions.cols {
                    map.setDistrict(at: x, y: y, district: nil)
                }
            }
            
            // Apply snapshot
            for (key, district) in districtAssignments {
                let components = key.split(separator: ",")
                if let x = Int(components[0]), let y = Int(components[1]) {
                    map.setDistrict(at: x, y: y, district: district)
                }
            }
        }
    }
    
    var canUndo: Bool {
        !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        !redoStack.isEmpty
    }
    
    func recordSnapshot(_ map: TerrainMap) {
        let snapshot = TerrainSnapshot(from: map)
        undoStack.append(snapshot)
        
        // Limit stack size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        objectWillChange.send()
    }
    
    func undo(_ map: TerrainMap) {
        guard !undoStack.isEmpty else { return }
        
        // Save current state to redo stack
        let currentSnapshot = TerrainSnapshot(from: map)
        redoStack.append(currentSnapshot)
        
        // Apply previous state
        let previousSnapshot = undoStack.removeLast()
        previousSnapshot.apply(to: map)
        
        objectWillChange.send()
    }
    
    func redo(_ map: TerrainMap) {
        guard !redoStack.isEmpty else { return }
        
        // Save current state to undo stack
        let currentSnapshot = TerrainSnapshot(from: map)
        undoStack.append(currentSnapshot)
        
        // Apply redo state
        let redoSnapshot = redoStack.removeLast()
        redoSnapshot.apply(to: map)
        
        objectWillChange.send()
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        objectWillChange.send()
    }
}

/// Keyboard shortcut handler for terrain editor
struct TerrainKeyboardShortcuts: ViewModifier {
    let activeTool: Binding<PaintTool>
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onValidate: () -> Void
    let onExport: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onKeyPress("b") {
                activeTool.wrappedValue = .brush
                return .handled
            }
            .onKeyPress("f") {
                activeTool.wrappedValue = .fill
                return .handled
            }
            .onKeyPress("r") {
                activeTool.wrappedValue = .rectangle
                return .handled
            }
            .onKeyPress("e") {
                activeTool.wrappedValue = .eraser
                return .handled
            }
            .background(
                Group {
                    Button(action: onUndo) { EmptyView() }
                        .keyboardShortcut("z", modifiers: [.command])
                        .hidden()
                    Button(action: onRedo) { EmptyView() }
                        .keyboardShortcut("Z", modifiers: [.command])
                        .hidden()
                    Button(action: onValidate) { EmptyView() }
                        .keyboardShortcut("v", modifiers: [.command])
                        .hidden()
                    Button(action: onExport) { EmptyView() }
                        .keyboardShortcut("s", modifiers: [.command])
                        .hidden()
                }
            )
    }
}

extension View {
    func terrainKeyboardShortcuts(
        activeTool: Binding<PaintTool>,
        onUndo: @escaping () -> Void,
        onRedo: @escaping () -> Void,
        onValidate: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) -> some View {
        modifier(TerrainKeyboardShortcuts(
            activeTool: activeTool,
            onUndo: onUndo,
            onRedo: onRedo,
            onValidate: onValidate,
            onExport: onExport
        ))
    }
}

