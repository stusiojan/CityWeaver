import Foundation

/// Available painting tools for district editing
enum PaintTool: String, CaseIterable {
    case brush
    case fill
    case eraser
    
    var displayName: String {
        switch self {
        case .brush: "Brush"
        case .fill: "Fill"
        case .eraser: "Eraser"
        }
    }
    
    var systemImage: String {
        switch self {
        case .brush: "paintbrush.fill"
        case .fill: "paintbrush.pointed.fill"
        case .eraser: "eraser.fill"
        }
    }
}

