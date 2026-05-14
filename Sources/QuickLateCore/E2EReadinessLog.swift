import Foundation

public struct E2EReadinessEvent: Codable, Equatable, Sendable {
    public let name: String
    public let fields: [String: String]

    public init(name: String, fields: [String: String] = [:]) {
        self.name = name
        self.fields = fields
    }
}

public enum E2EReadinessLog {
    public static func encodeLine(_ event: E2EReadinessEvent) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decodeLines(_ text: String) -> [E2EReadinessEvent] {
        let decoder = JSONDecoder()
        return text.split(whereSeparator: \.isNewline).compactMap { line in
            guard let data = String(line).data(using: .utf8) else { return nil }
            return try? decoder.decode(E2EReadinessEvent.self, from: data)
        }
    }

    public static func containsEvent(named name: String, in text: String) -> Bool {
        decodeLines(text).contains { $0.name == name }
    }
}
