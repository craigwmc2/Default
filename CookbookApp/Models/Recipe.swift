import Foundation

struct Recipe: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var ingredients: [Ingredient]
    var instructions: [RecipeStep]
    var prepTime: Int
    var cookTime: Int
    var servings: Int
    var cuisineType: String
    var tags: [String]
    var rating: Int?
    var isFavorite: Bool = false
    var nutritionInfo: NutritionInfo?
    var dateCreated: Date = Date()
    var totalTime: Int { prepTime + cookTime }
    func scaled(to newServings: Int) -> Recipe {
        let factor = Double(newServings) / Double(servings)
        var copy = self; copy.servings = newServings
        copy.ingredients = ingredients.map { $0.scaled(by: factor) }
        return copy
    }
}

struct Ingredient: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var amount: Double
    var unit: String
    var display: String {
        let f = amount.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(amount)) : String(format: "%.1f", amount)
        return unit.isEmpty ? "\(f) \(name)" : "\(f) \(unit) \(name)"
    }
    func scaled(by factor: Double) -> Ingredient {
        Ingredient(id: id, name: name, amount: (amount * factor * 10).rounded() / 10, unit: unit)
    }
}

struct RecipeStep: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var instruction: String
    var timerMinutes: Int?
}

struct NutritionInfo: Codable, Hashable {
    var calories: Int
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var fiber: Double
}
