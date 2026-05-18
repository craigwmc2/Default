import SwiftUI

@main
struct CookbookApp: App {
    @StateObject private var recipeStore   = RecipeStore()
    @StateObject private var pantryStore   = PantryStore()
    @StateObject private var mealPlanStore = MealPlanStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(recipeStore)
                .environmentObject(pantryStore)
                .environmentObject(mealPlanStore)
        }
    }
}
