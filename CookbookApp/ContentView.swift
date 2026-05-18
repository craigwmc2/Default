import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            PantryView()
                .tabItem { Label("Pantry", systemImage: "refrigerator.fill") }
            RecipeListView()
                .tabItem { Label("Recipes", systemImage: "book.fill") }
            MealPlannerView()
                .tabItem { Label("Meal Plan", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .accentColor(.green)
    }
}
