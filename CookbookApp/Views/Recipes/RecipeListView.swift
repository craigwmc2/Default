import SwiftUI

struct RecipeListView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var showingGenerator = false
    @State private var searchText = ""
    @State private var filterFavorites = false
    @State private var selectedCuisine: String?
    var cuisines: [String] { Array(Set(recipeStore.recipes.map(\.cuisineType))).sorted() }
    var displayed: [Recipe] {
        var list = recipeStore.recipes
        if filterFavorites { list = list.filter(\.isFavorite) }
        if let c = selectedCuisine { list = list.filter { $0.cuisineType == c } }
        if !searchText.isEmpty { list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        return list
    }
    var body: some View {
        NavigationView {
            Group {
                if recipeStore.recipes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed").font(.system(size: 60)).foregroundColor(.secondary)
                        Text("No Recipes Yet").font(.title3).bold()
                        Text("Tap the wand to generate AI-powered recipes.").multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button { showingGenerator = true } label: { Label("Generate Recipes", systemImage: "wand.and.stars") }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    VStack(spacing: 0) {
                        filterBar
                        List {
                            ForEach(displayed) { r in
                                NavigationLink(destination: RecipeDetailView(recipe: r)) { RecipeRowView(recipe: r) }
                                    .swipeActions(edge: .leading) { Button { recipeStore.toggleFavorite(r) } label: { Label(r.isFavorite ? "Unfavorite":"Favorite", systemImage: r.isFavorite ? "heart.slash":"heart.fill") }.tint(.pink) }
                                    .swipeActions(edge: .trailing) { Button(role: .destructive) { recipeStore.delete(r) } label: { Label("Delete", systemImage: "trash") } }
                            }
                        }.listStyle(.plain)
                    }.searchable(text: $searchText, prompt: "Search recipes")
                }
            }
            .navigationTitle("Recipes")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingGenerator = true } label: { Image(systemName: "wand.and.stars") } } }
            .sheet(isPresented: $showingGenerator) { GenerateRecipeView() }
        }
    }
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "Favorites", icon: "heart.fill", isActive: filterFavorites) { filterFavorites.toggle() }
                Divider().frame(height: 20)
                ForEach(cuisines, id: \.self) { c in FilterChip(label: c, icon: nil, isActive: selectedCuisine == c) { selectedCuisine = selectedCuisine == c ? nil : c } }
            }.padding(.horizontal).padding(.vertical, 8)
        }.background(Color(.systemGroupedBackground))
    }
}
struct FilterChip: View {
    let label: String; let icon: String?; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) { if let i = icon { Image(systemName: i).font(.caption) }; Text(label).font(.caption) }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isActive ? Color.green : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary).cornerRadius(20)
        }
    }
}
struct RecipeRowView: View {
    let recipe: Recipe
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(recipe.name).font(.subheadline).bold(); if recipe.isFavorite { Image(systemName: "heart.fill").foregroundColor(.pink).font(.caption) } }
                Text(recipe.cuisineType).font(.caption).foregroundColor(.secondary)
                HStack(spacing: 12) { Label("\(recipe.totalTime)m", systemImage: "clock"); Label("\(recipe.servings) servings", systemImage: "person.2"); if let r = recipe.rating { StarRatingDisplay(rating: r) } }.font(.caption2).foregroundColor(.secondary)
            }; Spacer()
        }.padding(.vertical, 4)
    }
}
struct StarRatingDisplay: View {
    let rating: Int
    var body: some View { HStack(spacing: 1) { ForEach(1...5, id: \.self) { Image(systemName: $0 <= rating ? "star.fill":"star").foregroundColor(.yellow) } }.font(.caption2) }
}
