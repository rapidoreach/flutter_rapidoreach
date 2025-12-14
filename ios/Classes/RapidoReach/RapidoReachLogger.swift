import Foundation

public enum RapidoReachLogLevel: Int {
    case error = 0
    case warn = 1
    case info = 2
    case debug = 3
}

/// Lightweight logger with level filtering and optional publisher hook.
public final class RapidoReachLogger {
    public static let shared = RapidoReachLogger()

    /// Minimum level to emit. Default `.error` for publishers; `.debug` in DEBUG builds.
    public var level: RapidoReachLogLevel = {
        #if DEBUG
        return .debug
        #else
        return .error
        #endif
    }()

    /// Optional callback to forward log lines into host app logging.
    public var sink: ((RapidoReachLogLevel, String) -> Void)?

    private let queue = DispatchQueue(label: "com.rapidoreach.logger", qos: .utility)

    private init() {}

    public func log(_ message: @autoclosure @escaping () -> String, level: RapidoReachLogLevel) {
        guard level.rawValue <= self.level.rawValue else { return }
        queue.async {
            let line = "[RapidoReach] [\(RapidoReachLogger.label(for: level))] \(message())"
            self.sink?(level, line)
            #if DEBUG
            print(line)
            #else
            if level == .error || level == .warn {
                print(line)
            }
            #endif
        }
    }

    private static func label(for level: RapidoReachLogLevel) -> String {
        switch level {
        case .error: return "ERROR"
        case .warn: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        }
    }
}
