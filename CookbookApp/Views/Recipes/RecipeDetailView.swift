import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var mealPlanStore: MealPlanStore
    let recipe: Recipe
    @State private var servings: Int
    @State private var showingCookingMode = false
    @State private var showingRating = false
    @State private var currentRating: Int
    init(recipe: Recipe) { self.recipe = recipe; _servings = State(initialValue: recipe.servings); _currentRating = State(initialValue: recipe.rating ?? 0) }
    private var scaled: Recipe { recipe.scaled(to: servings) }
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 24) { header; meta; if let n = recipe.nutritionInfo { nutrition(n) }; ingredients; instructions; actions }.padding() }
            .navigationTitle(recipe.name).navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { recipeStore.toggleFavorite(recipe) } label: { Image(systemName: (recipeStore.recipe(by: recipe.id)?.isFavorite ?? false) ? "heart.fill":"heart").foregroundColor(.pink) } } }
            .fullScreenCover(isPresented: $showingCookingMode) { CookingModeView(recipe: scaled) }
            .sheet(isPresented: $showingRating) { RatingView(recipe: recipe, currentRating: $currentRating) { stars in recipeStore.rate(recipe, stars: stars, preferences: &mealPlanStore.preferences); mealPlanStore.savePreferences() } }
    }
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.description).font(.body).foregroundColor(.secondary)
            HStack(spacing: 6) { ForEach(recipe.tags, id: \.self) { Text($0).font(.caption2).padding(.horizontal,8).padding(.vertical,4).background(Color.green.opacity(0.15)).foregroundColor(.green).cornerRadius(8) } }
        }
    }
    private var meta: some View {
        HStack {
            tile("clock","Prep","\(recipe.prepTime)m"); Divider().frame(height:40)
            tile("flame","Cook","\(recipe.cookTime)m"); Divider().frame(height:40)
            tile("fork.knife","Cuisine",recipe.cuisineType); Divider().frame(height:40)
            VStack(spacing:4) {
                HStack(spacing:8) {
                    Button { if servings>1{servings-=1} } label: {Image(systemName:"minus.circle").foregroundColor(.green)}
                    Text("\(servings)").font(.subheadline).bold().frame(minWidth:20)
                    Button { servings+=1 } label: {Image(systemName:"plus.circle").foregroundColor(.green)}
                }; Text("Servings").font(.caption2).foregroundColor(.secondary)
            }.frame(maxWidth:.infinity)
        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(16)
    }
    private func tile(_ icon: String,_ label: String,_ val: String) -> some View {
        VStack(spacing:4){Image(systemName:icon).foregroundColor(.green);Text(val).font(.subheadline).bold();Text(label).font(.caption2).foregroundColor(.secondary)}.frame(maxWidth:.infinity)
    }
    private func nutrition(_ n: NutritionInfo) -> some View {
        VStack(alignment:.leading,spacing:10){
            Text("Nutrition (per serving)").font(.headline)
            HStack{nTile("Calories","\(n.calories)","kcal");nTile("Protein",String(format:"%.0f",n.protein),"g");nTile("Carbs",String(format:"%.0f",n.carbohydrates),"g");nTile("Fat",String(format:"%.0f",n.fat),"g");nTile("Fiber",String(format:"%.0f",n.fiber),"g")}
        }.padding().background(Color(.secondarySystemBackground)).cornerRadius(16)
    }
    private func nTile(_ l: String,_ v: String,_ u: String) -> some View {
        VStack(spacing:2){Text(v).font(.subheadline).bold();Text(u).font(.caption2).foregroundColor(.secondary);Text(l).font(.caption2).foregroundColor(.secondary)}.frame(maxWidth:.infinity)
    }
    private var ingredients: some View {
        VStack(alignment:.leading,spacing:10){
            Text("Ingredients").font(.headline)
            if servings != recipe.servings { Text("Scaled for \(servings) servings").font(.caption).foregroundColor(.green).italic() }
            ForEach(scaled.ingredients){i in HStack{Circle().fill(Color.green).frame(width:6,height:6);Text(i.display).font(.subheadline)}}
        }
    }
    private var instructions: some View {
        VStack(alignment:.leading,spacing:12){
            Text("Instructions").font(.headline)
            ForEach(Array(recipe.instructions.enumerated()),id:\.element.id){idx,step in
                HStack(alignment:.top,spacing:12){
                    Text("\(idx+1)").font(.subheadline).bold().foregroundColor(.white).frame(width:28,height:28).background(Color.green).clipShape(Circle())
                    VStack(alignment:.leading,spacing:4){
                        Text(step.instruction).font(.subheadline)
                        if let m=step.timerMinutes{Label("\(m) min timer",systemImage:"timer").font(.caption).foregroundColor(.orange)}
                    }
                }
            }
        }
    }
    private var actions: some View {
        VStack(spacing:12){
            Button{showingCookingMode=true}label:{Label("Start Cooking Mode",systemImage:"play.circle.fill").frame(maxWidth:.infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(14).font(.headline)}
            Button{showingRating=true}label:{
                HStack{Text("Rate This Recipe");Spacer()
                    if currentRating>0{StarRatingDisplay(rating:currentRating)}else{Text("Tap to rate").foregroundColor(.secondary)}
                }.padding().background(Color(.secondarySystemBackground)).cornerRadius(14)
            }.foregroundColor(.primary)
        }.padding(.bottom)
    }
}
