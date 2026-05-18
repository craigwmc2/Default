import Foundation
import Combine

class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isGenerating = false
    @Published var generationError: String?
    private let saveKey = "saved_recipes"
    init() { load() }

    func add(_ r: Recipe) { recipes.insert(r, at: 0); save() }
    func addAll(_ rs: [Recipe]) { recipes.insert(contentsOf: rs, at: 0); save() }
    func update(_ r: Recipe) { if let i = recipes.firstIndex(where: { $0.id == r.id }) { recipes[i] = r; save() } }
    func delete(_ r: Recipe) { recipes.removeAll { $0.id == r.id }; save() }
    func toggleFavorite(_ r: Recipe) { var c = r; c.isFavorite.toggle(); update(c) }

    func rate(_ recipe: Recipe, stars: Int, preferences: inout UserPreferences) {
        var c = recipe; c.rating = stars; update(c)
        if stars <= 2 {
            Task {
                if let ings = try? await ClaudeService.shared.extractKeyIngredients(from: recipe) {
                    await MainActor.run {
                        preferences.avoidFromRatings.append(contentsOf: ings.filter { !preferences.avoidFromRatings.contains($0) })
                    }
                }
            }
        }
    }

    func generateRecipes(pantryItems: [PantryItem], preferences: UserPreferences,
                         count: Int = 3, mealType: MealType? = nil, cuisineHint: String? = nil) async {
        await MainActor.run { isGenerating = true; generationError = nil }
        do {
            let g = try await ClaudeService.shared.generateRecipes(pantryItems: pantryItems, preferences: preferences, count: count, mealType: mealType, cuisineHint: cuisineHint)
            await MainActor.run { addAll(g); isGenerating = false }
        } catch {
            await MainActor.run { generationError = error.localizedDescription; isGenerating = false }
        }
    }

    var favorites: [Recipe] { recipes.filter(\.isFavorite) }
    func recipe(by id: UUID) -> Recipe? { recipes.first { $0.id == id } }
    private func save() { if let d = try? JSONEncoder().encode(recipes) { UserDefaults.standard.set(d, forKey: saveKey) } }
    private func load() { if let d = UserDefaults.standard.data(forKey: saveKey), let s = try? JSONDecoder().decode([Recipe].self, from: d) { recipes = s } }
}
