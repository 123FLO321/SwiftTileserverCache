import Foundation

internal extension String {
    var isEmpty: Bool {
        return self.trimmingCharacters(in: .whitespaces) == ""
    }
}
