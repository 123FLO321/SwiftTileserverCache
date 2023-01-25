import Foundation
import Vapor
import Leaf

extension LeafData: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let string = try? container.decode(String.self) {
            if string == "null" {
                self = .trueNil
            } else if (string.contains("[") || string.contains("{")),
                let data = string.data(using: .utf8) {
                if let array = try? JSONDecoder().decode([LeafData].self, from: data) {
                    self = .array(array)
                } else if let dictionary = try? JSONDecoder().decode([String: LeafData].self, from: data) {
                    self = .dictionary(dictionary)
                } else {
                    self = .string(string)
                }
            } else {
                self = .string(string)
            }
        } else if let array = try? container.decode([LeafData].self) {
            self = .array(array)
        } else if let dictionary = try? container.decode([String: LeafData].self) {
            self = .dictionary(dictionary)
        } else if container.decodeNil() {
            self = .trueNil
        } else {
            throw Abort(.badRequest, reason: "Unsupported data type in parameters")
        }
    }

}
