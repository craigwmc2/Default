import SwiftUI

struct HomeView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var pantryStore: PantryStore
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var quickMeal: Recipe?
    @State private var isLoadingQuickMeal = false
    @State private var quickMealError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingCard
                    if !pantryStore.alerts.isEmpty { alertsSection }
                    todaysMealsSection
                    quickMealSection
                    recentRecipesSection
                }.padding()
            }
            .navigationTitle("My Cookbook").navigationBarTitleDisplayMode(.large)
        }
    }

    private var greetingCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mealPlanStore.preferences.userName.isEmpty ? "Welcome back!" : "Hello, \(mealPlanStore.preferences.userName)!").font(.title2).bold()
            Text("\(recipeStore.recipes.count) recipes · \(pantryStore.items.count) pantry items").font(.subheadline).foregroundColor(.secondary)
        }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(.systemGreen).opacity(0.12)).cornerRadius(16)
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pantry Alerts", systemImage: "exclamationmark.triangle.fill").font(.headline).foregroundColor(.orange)
            ForEach(pantryStore.alerts.prefix(3)) { item in
                HStack { Text(item.statusEmoji); Text(item.name); Spacer()
                    if item.isExpired { Text("Expired").font(.caption).foregroundColor(.red) }
                    else if item.isExpiringSoon { Text("Expiring soon").font(.caption).foregroundColor(.orange) }
                    else { Text("Low stock").font(.caption).foregroundColor(.yellow) }
                }.padding(.vertical, 4)
            }
        }.padding().background(Color(.systemOrange).opacity(0.08)).cornerRadius(16)
    }

    private var todaysMealsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Meals").font(.headline)
            if let day = mealPlanStore.currentPlan.days.first(where: \.isToday) {
                HStack(spacing: 12) {
                    chip("Breakfast", day.breakfast); chip("Lunch", day.lunch); chip("Dinner", day.dinner)
                }
            } else { Text("No meals planned today").font(.subheadline).foregroundColor(.secondary) }
        }
    }

    private func chip(_ label: String, _ meal: PlannedMeal?) -> some View {
        VStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(meal?.recipeName ?? "—").font(.caption).multilineTextAlignment(.center).lineLimit(2)
        }.frame(maxWidth: .infinity).padding(10).background(Color(.secondarySystemBackground)).cornerRadius(12)
    }

    private var quickMealSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What can I make tonight?").font(.headline)
            Button { Task { await generateQuickMeal() } } label: {
                HStack {
                    if isLoadingQuickMeal { ProgressView().tint(.white) } else { Image(systemName: "wand.and.stars") }
                    Text(isLoadingQuickMeal ? "Thinking…" : "Surprise Me")
                }.frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(14)
            }.disabled(isLoadingQuickMeal)
            if let m = quickMeal { NavigationLink(destination: RecipeDetailView(recipe: m)) { QuickMealCard(recipe: m) }.buttonStyle(PlainButtonStyle()) }
            if let e = quickMealError { Text(e).font(.caption).foregroundColor(.red) }
        }
    }

    private var recentRecipesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Recipes").font(.headline)
            if recipeStore.recipes.isEmpty { Text("Generate your first recipe!").font(.subheadline).foregroundColor(.secondary) }
            else { ForEach(recipeStore.recipes.prefix(5)) { r in NavigationLink(destination: RecipeDetailView(recipe: r)) { RecipeRowView(recipe: r) }.buttonStyle(PlainButtonStyle()) } }
        }
    }

    @MainActor private func generateQuickMeal() async {
        isLoadingQuickMeal = true; quickMealError = nil
        do {
            let m = try await ClaudeService.shared.suggestQuickMeal(pantryItems: pantryStore.items, preferences: mealPlanStore.preferences)
            quickMeal = m; recipeStore.add(m)
        } catch { quickMealError = error.localizedDescription }
        isLoadingQuickMeal = false
    }
}

struct QuickMealCard: View {
    let recipe: Recipe
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name).font(.subheadline).bold()
                Text(recipe.description).font(.caption).foregroundColor(.secondary).lineLimit(2)
                HStack { Label("\(recipe.totalTime)m", systemImage: "clock"); Label(recipe.cuisineType, systemImage: "fork.knife") }.font(.caption2).foregroundColor(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundColor(.secondary)
        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
    }
}
