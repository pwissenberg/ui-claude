import Foundation

/// Minimal logger. Writes to stderr (visible when the executable is run from a
/// terminal) and to `~/Library/Logs/ClaudeCompanion.log` so failures are
/// diagnosable when the app is launched normally from Finder.
enum Log {
    private static let logURL: URL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/ClaudeCompanion.log")

    static func info(_ message: String)  { write("INFO",  message) }
    static func warn(_ message: String)  { write("WARN",  message) }
    static func error(_ message: String) { write("ERROR", message) }

    private static func write(_ level: String, _ message: String) {
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(stamp)] \(level): \(message)\n"

        FileHandle.standardError.write(Data(line.utf8))

        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: logURL)
        }
    }
}
