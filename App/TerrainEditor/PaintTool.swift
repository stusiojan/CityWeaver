import Foundation

/// Available painting tools for district editing
enum PaintTool: String, CaseIterable {
    case brush
    case fill
    case rectangle
    case eraser
    
    var displayName: String {
        switch self {
        case .brush: "Brush"
        case .fill: "Fill"
        case .rectangle: "Rectangle"
        case .eraser: "Eraser"
        }
    }
    
    var systemImage: String {
        switch self {
        case .brush: "paintbrush.fill"
        case .fill: "paintbrush.pointed.fill"
        case .rectangle: "rectangle.dashed"
        case .eraser: "eraser.fill"
        }
    }
}

