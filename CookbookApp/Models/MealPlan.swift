import Foundation

struct MealPlan: Codable {
    var weekStartDate: Date
    var days: [DayPlan]
    init(weekStartDate: Date) {
        self.weekStartDate = weekStartDate
        self.days = (0..<7).map { DayPlan(date: Calendar.current.date(byAdding: .day, value: $0, to: weekStartDate)!) }
    }
}

struct DayPlan: Identifiable, Codable {
    var id: UUID = UUID(); var date: Date
    var breakfast: PlannedMeal?; var lunch: PlannedMeal?; var dinner: PlannedMeal?
    var snacks: [PlannedMeal] = []
    var dayName: String   { DateFormatter().also { $0.dateFormat = "EEEE" }.string(from: date) }
    var shortDayName: String { DateFormatter().also { $0.dateFormat = "EEE" }.string(from: date) }
    var dateLabel: String { DateFormatter().also { $0.dateFormat = "M/d" }.string(from: date) }
    var isToday: Bool     { Calendar.current.isDateInToday(date) }
}

extension DateFormatter {
    func also(_ configure: (DateFormatter) -> Void) -> DateFormatter { configure(self); return self }
}

struct PlannedMeal: Identifiable, Codable {
    var id: UUID = UUID(); var recipeId: UUID?; var recipeName: String
    var servings: Int; var mealType: MealType
}

enum MealType: String, CaseIterable, Codable, Identifiable {
    var id: String { rawValue }
    case breakfast = "Breakfast", lunch = "Lunch", dinner = "Dinner", snack = "Snack"
    var emoji: String {
        switch self { case .breakfast: return "🌅"; case .lunch: return "☀️"; case .dinner: return "🌙"; case .snack: return "🍎" }
    }
}
