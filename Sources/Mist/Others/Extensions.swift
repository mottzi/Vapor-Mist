import Foundation

extension UUID {
    
    var short: String { String(uuidString.prefix(8)) }
    
}
