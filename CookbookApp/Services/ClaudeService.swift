import Foundation

class ClaudeService {
    static let shared = ClaudeService()
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-opus-4-7"
    var apiKey: String {
        UserDefaults.standard.string(forKey: "anthropic_api_key")
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }

    func generateRecipes(pantryItems: [PantryItem], preferences: UserPreferences,
                         count: Int = 3, mealType: MealType? = nil, cuisineHint: String? = nil) async throws -> [Recipe] {
        let pantryList = pantryItems.map { "\($0.name) (\($0.quantity) \($0.unit))" }.joined(separator: ", ")
        let system = "You are a professional chef and nutritionist. Generate creative recipes based on pantry ingredients and preferences. Always respond with valid JSON only."
        let user = """
        Generate \(count) unique recipe\(count > 1 ? "s" : "") using: \(pantryList.isEmpty ? "common kitchen staples" : pantryList)
        - Skill: \(preferences.skillLevel.rawValue), Max time: \(preferences.maxCookTime)min
        - Exclude: \(preferences.allExclusions.isEmpty ? "none" : preferences.allExclusions.joined(separator: ", "))
        - Diets: \(preferences.dietaryRestrictions.map(\.rawValue).joined(separator: ", ").isEmpty ? "none" : preferences.dietaryRestrictions.map(\.rawValue).joined(separator: ", "))
        \(cuisineHint.map { "- Cuisine: \($0)" } ?? "") \(mealType.map { "- Meal: \($0.rawValue)" } ?? "")
        Respond ONLY with JSON array: [{"name":"","description":"","cuisineType":"","tags":[],"prepTime":0,"cookTime":0,"servings":4,
        "ingredients":[{"name":"","amount":0.0,"unit":""}],
        "instructions":[{"instruction":"","timerMinutes":null}],
        "nutritionInfo":{"calories":0,"protein":0.0,"carbohydrates":0.0,"fat":0.0,"fiber":0.0}}]
        """
        return try parseRecipes(from: try await sendMessage(system: system, user: user))
    }

    func extractKeyIngredients(from recipe: Recipe) async throws -> [String] {
        let prompt = "Given recipe \"\(recipe.name)\" with: \(recipe.ingredients.map(\.name).joined(separator: ", ")). List 3-5 most distinctive flavor ingredients as JSON array of strings only."
        let response = try await sendMessage(system: "Culinary expert. JSON only.", user: prompt)
        return (try? JSONDecoder().decode([String].self, from: Data(response.utf8))) ?? []
    }

    func suggestQuickMeal(pantryItems: [PantryItem], preferences: UserPreferences) async throws -> Recipe {
        guard let r = try await generateRecipes(pantryItems: pantryItems, preferences: preferences, count: 1).first
        else { throw ClaudeError.noResults }
        return r
    }

    private func sendMessage(system: String, user: String) async throws -> String {
        guard !apiKey.isEmpty else { throw ClaudeError.missingAPIKey }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "max_tokens": 4096,
            "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
            "messages": [["role": "user", "content": user]]
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw ClaudeError.apiError((resp as? HTTPURLResponse)?.statusCode ?? 0, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = (json["content"] as? [[String: Any]])?.first?["text"] as? String
        else { throw ClaudeError.parseError("No text in response") }
        return text
    }

    private func parseRecipes(from text: String) throws -> [Recipe] {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = s.range(of: "["), let b = s.range(of: "]", options: .backwards) { s = String(s[a.lowerBound...b.upperBound]) }
        guard let data = s.data(using: .utf8) else { throw ClaudeError.parseError("Encode failed") }
        return try JSONDecoder().decode([RawRecipe].self, from: data).map { $0.toRecipe() }
    }
}

private struct RawRecipe: Decodable {
    let name, description, cuisineType: String; let tags: [String]
    let prepTime, cookTime, servings: Int
    let ingredients: [RawIng]; let instructions: [RawStep]; let nutritionInfo: RawNut?
    func toRecipe() -> Recipe {
        Recipe(name: name, description: description,
               ingredients: ingredients.map { Ingredient(name: $0.name, amount: $0.amount, unit: $0.unit) },
               instructions: instructions.map { RecipeStep(instruction: $0.instruction, timerMinutes: $0.timerMinutes) },
               prepTime: prepTime, cookTime: cookTime, servings: servings, cuisineType: cuisineType, tags: tags,
               nutritionInfo: nutritionInfo.map { NutritionInfo(calories: $0.calories, protein: $0.protein, carbohydrates: $0.carbohydrates, fat: $0.fat, fiber: $0.fiber) })
    }
}
private struct RawIng: Decodable { let name: String; let amount: Double; let unit: String }
private struct RawStep: Decodable { let instruction: String; let timerMinutes: Int? }
private struct RawNut: Decodable { let calories: Int; let protein, carbohydrates, fat, fiber: Double }

enum ClaudeError: LocalizedError {
    case missingAPIKey, networkError(String), apiError(Int, String), parseError(String), noResults
    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Anthropic API key in Settings."
        case .networkError(let m): return "Network: \(m)"
        case .apiError(let c, let m): return "API \(c): \(m)"
        case .parseError(let m): return "Parse error: \(m)"
        case .noResults: return "No recipes generated. Try again."
        }
    }
}
