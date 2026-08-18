import Foundation

extension DateFormatter {
    static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    static let displayDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    static let shortDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f
    }()
    
    static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()
}

extension Date {
    var iso8601String: String {
        DateFormatter.iso8601Full.string(from: self)
    }
    
    var displayString: String {
        DateFormatter.displayDate.string(from: self)
    }
    
    var shortDisplayString: String {
        DateFormatter.shortDate.string(from: self)
    }
    
    var timeDisplayString: String {
        DateFormatter.timeOnly.string(from: self)
    }
}
