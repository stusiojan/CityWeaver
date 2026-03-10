import Foundation
import os

/// Thread-safe file writer for diagnostic logs
public actor FileLogWriter {
    public static let shared = FileLogWriter()

    private var fileHandle: FileHandle?
    private let logDirectory: URL

    private init() {
        // Use CW_LOG_DIR environment variable if set, otherwise fall back to ~/Library/Logs/CityWeaver
        if let envPath = ProcessInfo.processInfo.environment["CW_LOG_DIR"] {
            logDirectory = URL(filePath: envPath)
        } else {
            logDirectory = URL.homeDirectory
                .appending(path: "Library/Logs/CityWeaver")
        }
    }

    /// Opens a new log file for the current session
    private func openFileIfNeeded() throws {
        guard fileHandle == nil else { return }

        let fm = FileManager.default
        if !fm.fileExists(atPath: logDirectory.path(percentEncoded: false)) {
            try fm.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileURL = logDirectory.appending(path: "session-\(timestamp).log")

        fm.createFile(atPath: fileURL.path(percentEncoded: false), contents: nil)
        fileHandle = try FileHandle(forWritingTo: fileURL)
    }

    /// Writes a single line to the log file
    public func write(_ line: String) {
        do {
            try openFileIfNeeded()
            if let data = (line + "\n").data(using: .utf8) {
                fileHandle?.write(data)
            }
        } catch {
            // Fallback — print to console if file writing fails
            print("[CWLogger] File write error: \(error)")
        }
    }
}

/// Lightweight, Sendable logger facade for cross-package diagnostics
///
/// Logs simultaneously to `os.Logger` (Console.app) and a session file.
/// The log directory is determined by the `CW_LOG_DIR` environment variable,
/// falling back to `~/Library/Logs/CityWeaver/`.
public struct CWLogger: Sendable {
    private let subsystem: String
    private let osLogger: os.Logger

    /// Creates a logger scoped to the given subsystem (e.g. `"RoadGeneration"`)
    public init(subsystem: String) {
        self.subsystem = subsystem
        self.osLogger = os.Logger(
            subsystem: "com.janstusio.cityweaver",
            category: subsystem
        )
    }

    // MARK: - Public API

    public func info(_ message: String) {
        log(level: "INFO", message: message)
    }

    public func debug(_ message: String) {
        log(level: "DEBUG", message: message)
    }

    public func error(_ message: String) {
        log(level: "ERROR", message: message)
    }

    public func event(_ message: String) {
        log(level: "EVENT", message: message)
    }

    public func constraint(_ message: String) {
        log(level: "CONSTRAINT", message: message)
    }

    // MARK: - Internal

    private func log(level: String, message: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] [\(level)] [\(subsystem)] \(message)"

        // os.Logger for Console.app
        switch level {
        case "ERROR":
            osLogger.error("\(line, privacy: .public)")
        case "DEBUG":
            osLogger.debug("\(line, privacy: .public)")
        default:
            osLogger.info("\(line, privacy: .public)")
        }

        // Fire-and-forget file write — avoids blocking @MainActor callers
        Task {
            await FileLogWriter.shared.write(line)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()
}
