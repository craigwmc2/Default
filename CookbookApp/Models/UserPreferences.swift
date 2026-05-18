import Foundation

struct UserPreferences: Codable {
    var allergies: Set<String> = []
    var dietaryRestrictions: Set<DietaryRestriction> = []
    var favoriteCuisines: [String] = []
    var dislikedIngredients: [String] = []
    var skillLevel: CookingSkillLevel = .intermediate
    var maxCookTime: Int = 60
    var defaultServings: Int = 4
    var avoidFromRatings: [String] = []
    var userName: String = ""
    var allExclusions: [String] { Array(allergies) + dislikedIngredients + avoidFromRatings }
}

enum DietaryRestriction: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case vegetarian = "Vegetarian", vegan = "Vegan", glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free", keto = "Keto", paleo = "Paleo"
    case lowSodium = "Low Sodium", lowCarb = "Low Carb", halal = "Halal", kosher = "Kosher"
}

enum CookingSkillLevel: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case beginner = "Beginner", intermediate = "Intermediate", advanced = "Advanced", chef = "Chef Level"
}

let commonAllergens = ["Crawfish", "Shrimp", "Shellfish", "Peanuts", "Tree Nuts", "Milk", "Eggs", "Fish", "Wheat", "Soy", "Sesame"]
