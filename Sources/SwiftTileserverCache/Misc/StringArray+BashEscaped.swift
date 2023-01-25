import Foundation

internal extension Array where Element == String {
    var bashEscaped: [String] {
        return self.map({$0.bashEscaped})
    }
}
