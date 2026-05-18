import Foundation
import Combine

class PantryStore: ObservableObject {
    @Published var items: [PantryItem] = []
    private let saveKey = "pantry_items"
    init() { load() }
    func add(_ i: PantryItem) { items.append(i); save() }
    func update(_ i: PantryItem) { if let idx = items.firstIndex(where: { $0.id == i.id }) { items[idx] = i; save() } }
    func delete(_ i: PantryItem) { items.removeAll { $0.id == i.id }; save() }
    func items(for cat: PantryCategory) -> [PantryItem] { items.filter { $0.category == cat }.sorted { $0.name < $1.name } }
    var expiringSoon: [PantryItem] { items.filter(\.isExpiringSoon) }
    var expired: [PantryItem]     { items.filter(\.isExpired) }
    var lowStock: [PantryItem]    { items.filter { $0.isLowStock && !$0.isExpired } }
    var alerts: [PantryItem]      { (expired + expiringSoon + lowStock).uniqued() }
    var categoriesInUse: [PantryCategory] { PantryCategory.allCases.filter { cat in items.contains { $0.category == cat } } }
    private func save() { if let d = try? JSONEncoder().encode(items) { UserDefaults.standard.set(d, forKey: saveKey) } }
    private func load() { if let d = UserDefaults.standard.data(forKey: saveKey), let s = try? JSONDecoder().decode([PantryItem].self, from: d) { items = s } }
}
private extension Array where Element: Identifiable {
    func uniqued() -> [Element] { var seen = Set<AnyHashable>(); return filter { seen.insert($0.id as AnyObject).inserted } }
}
