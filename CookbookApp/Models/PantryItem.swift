import Foundation

enum PantryCategory: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case produce = "Produce", proteins = "Proteins", dairy = "Dairy", grains = "Grains"
    case spices = "Spices & Herbs", condiments = "Condiments", frozen = "Frozen"
    case canned = "Canned Goods", other = "Other"
    var emoji: String {
        switch self {
        case .produce: return "🥦"; case .proteins: return "🥩"; case .dairy: return "🧀"
        case .grains: return "🌾"; case .spices: return "🌿"; case .condiments: return "🫙"
        case .frozen: return "❄️"; case .canned: return "🥫"; case .other: return "📦"
        }
    }
}

struct PantryItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: PantryCategory
    var quantity: String
    var unit: String
    var expirationDate: Date?
    var isLowStock: Bool = false
    var dateAdded: Date = Date()
    var isExpired: Bool {
        guard let exp = expirationDate else { return false }; return exp < Date()
    }
    var isExpiringSoon: Bool {
        guard let exp = expirationDate else { return false }
        return exp < Date().addingTimeInterval(3*24*60*60) && !isExpired
    }
    var statusEmoji: String {
        if isExpired { return "🔴" }; if isExpiringSoon { return "🟡" }
        if isLowStock { return "🟠" }; return "🟢"
    }
}
