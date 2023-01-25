import Foundation

public struct HitRatio: Codable {
    public var cached: UInt64 = 0
    public var total: UInt64 = 0
    public var percentageString: String {
        return String(format: "%.2f", Float(cached) / Float(total) * 100)
    }
    public var displayValue: String {
        return "\(cached)/\(total) (\(percentageString)%)"
    }

    public mutating func served(new: Bool) {
        if !new { cached += 1 }
        total += 1
    }
}
