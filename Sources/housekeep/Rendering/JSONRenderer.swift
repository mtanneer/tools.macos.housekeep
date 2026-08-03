import Foundation
import HousekeepCore

enum JSONRenderer {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    static func render<T: Encodable>(_ value: T) {
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
            print("{}")
            return
        }
        print(text)
    }
}
