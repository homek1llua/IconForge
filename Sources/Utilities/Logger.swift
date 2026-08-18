import Foundation

final class IconForgeLogger: @unchecked Sendable {
    
    enum LogLevel: Int, Comparable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    static let shared = IconForgeLogger()
    
    private var minimumLevel: LogLevel = .info
    private var logEntries: [LogEntry] = []
    private let lock = NSLock()
    private let maxEntries = 5000
    
    private init() {}
    
    func setMinimumLevel(_ level: LogLevel) {
        lock.lock()
        defer { lock.unlock() }
        minimumLevel = level
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    func logError(_ error: Error, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: error.localizedDescription, file: file, function: function, line: line)
    }
    
    func getEntries(level: LogLevel? = nil) -> [LogEntry] {
        lock.lock()
        defer { lock.unlock() }
        if let level {
            return logEntries.filter { $0.level >= level }
        }
        return logEntries
    }
    
    func clearEntries() {
        lock.lock()
        defer { lock.unlock() }
        logEntries.removeAll()
    }
    
    func exportLogs() -> String {
        let entries = getEntries()
        let formatter = ISO8601DateFormatter()
        return entries.map { entry in
            "[\(formatter.string(from: entry.timestamp))] [\(entry.level.name)] \(entry.message) (\(entry.filename):\(entry.line))"
        }.joined(separator: "\n")
    }
    
    func saveLogsToDisk() {
        let logs = exportLogs()
        let logDir = StorageManager.logsDirectory()
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "iconforge-log-\(dateFormatter.string(from: Date())).txt"
        let url = logDir.appendingPathComponent(filename)
        try? logs.write(to: url, atomically: true, encoding: .utf8)
        pruneOldLogs(keepCount: 10)
    }
    
    private func pruneOldLogs(keepCount: Int) {
        let logDir = StorageManager.logsDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: logDir,
            includingPropertiesForKeys: [.creationDateKey]
        ) else { return }
        let sorted = files.sorted { f1, f2 in
            let d1 = (try? f1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let d2 = (try? f2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return d1 > d2
        }
        for file in sorted.dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    private func log(level: LogLevel, message: String, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }
        let filename = (file as NSString).lastPathComponent
        let entry = LogEntry(
            level: level,
            message: message,
            filename: filename,
            function: function,
            line: line,
            timestamp: Date()
        )
        lock.lock()
        logEntries.append(entry)
        if logEntries.count > maxEntries {
            logEntries.removeFirst(logEntries.count - maxEntries)
        }
        lock.unlock()
    }
}

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let level: IconForgeLogger.LogLevel
    let message: String
    let filename: String
    let function: String
    let line: Int
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

extension IconForgeLogger.LogLevel {
    var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARN"
        case .error: return "ERROR"
        }
    }
}
