import Foundation

class MealPlanStore: ObservableObject {
    @Published var currentPlan: MealPlan
    @Published var preferences: UserPreferences
    init() {
        currentPlan = (UserDefaults.standard.data(forKey: "current_meal_plan").flatMap { try? JSONDecoder().decode(MealPlan.self, from: $0) })
            ?? MealPlan(weekStartDate: Calendar.current.startOfWeek)
        preferences = (UserDefaults.standard.data(forKey: "user_preferences").flatMap { try? JSONDecoder().decode(UserPreferences.self, from: $0) })
            ?? UserPreferences()
    }
    func assignMeal(_ meal: PlannedMeal, to idx: Int, mealType: MealType) {
        switch mealType {
        case .breakfast: currentPlan.days[idx].breakfast = meal
        case .lunch:     currentPlan.days[idx].lunch = meal
        case .dinner:    currentPlan.days[idx].dinner = meal
        case .snack:     currentPlan.days[idx].snacks.append(meal)
        }; savePlan()
    }
    func clearMeal(dayIndex: Int, mealType: MealType) {
        switch mealType {
        case .breakfast: currentPlan.days[dayIndex].breakfast = nil
        case .lunch:     currentPlan.days[dayIndex].lunch = nil
        case .dinner:    currentPlan.days[dayIndex].dinner = nil
        case .snack:     currentPlan.days[dayIndex].snacks = []
        }; savePlan()
    }
    func advanceToNextWeek() { currentPlan = MealPlan(weekStartDate: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentPlan.weekStartDate)!); savePlan() }
    func resetToCurrentWeek() { currentPlan = MealPlan(weekStartDate: Calendar.current.startOfWeek); savePlan() }
    func shoppingList(from recipes: [Recipe]) -> [ShoppingListItem] {
        var agg: [String: ShoppingListItem] = [:]
        for day in currentPlan.days {
            for meal in [day.breakfast, day.lunch, day.dinner].compactMap({ $0 }) {
                guard let rid = meal.recipeId, let recipe = recipes.first(where: { $0.id == rid }) else { continue }
                for ing in recipe.scaled(to: meal.servings).ingredients {
                    let k = ing.name.lowercased()
                    if var ex = agg[k] { ex.totalAmount += ing.amount; agg[k] = ex }
                    else { agg[k] = ShoppingListItem(name: ing.name, totalAmount: ing.amount, unit: ing.unit) }
                }
            }
        }
        return agg.values.sorted { $0.name < $1.name }
    }
    func savePreferences() { if let d = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(d, forKey: "user_preferences") } }
    private func savePlan() { if let d = try? JSONEncoder().encode(currentPlan) { UserDefaults.standard.set(d, forKey: "current_meal_plan") } }
}
struct ShoppingListItem: Identifiable {
    var id = UUID(); var name: String; var totalAmount: Double; var unit: String; var isChecked = false
    var display: String {
        let a = totalAmount.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(totalAmount)) : String(format: "%.1f", totalAmount)
        return unit.isEmpty ? "\(a) \(name)" : "\(a) \(unit) \(name)"
    }
}
extension Calendar { var startOfWeek: Date { date(from: dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date() } }
