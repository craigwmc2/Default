import SwiftUI

struct GenerateRecipeView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var pantryStore: PantryStore
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedMealType: MealType?; @State private var cuisineHint = ""
    @State private var count = 3; @State private var usePantry = true
    var body: some View {
        NavigationView {
            Form {
                Section("How many?"){Picker("Count",selection:$count){ForEach([1,2,3,5],id:\.self){Text("\($0)").tag($0)}}.pickerStyle(.segmented)}
                Section("Meal Type"){Picker("Type",selection:$selectedMealType){Text("Any").tag(MealType?.none);ForEach(MealType.allCases){t in Text("\(t.emoji) \(t.rawValue)").tag(MealType?.some(t))}}.pickerStyle(.menu)}
                Section("Cuisine Hint"){TextField("e.g. Italian, Thai, Southern…",text:$cuisineHint)}
                Section("Ingredients"){Toggle("Use my pantry",isOn:$usePantry);if usePantry{Text("\(pantryStore.items.count) items").font(.caption).foregroundColor(.secondary)}}
                Section("Preferences"){
                    if mealPlanStore.preferences.allExclusions.isEmpty{Text("No exclusions").font(.caption).foregroundColor(.secondary)}
                    else{Text("Excluding: \(mealPlanStore.preferences.allExclusions.prefix(5).joined(separator:", "))").font(.caption).foregroundColor(.secondary)}
                    Text("Skill: \(mealPlanStore.preferences.skillLevel.rawValue)").font(.caption).foregroundColor(.secondary)
                }
                if let e=recipeStore.generationError{Section{Text(e).foregroundColor(.red).font(.caption)}}
                Section{Button{Task{await recipeStore.generateRecipes(pantryItems:usePantry ? pantryStore.items:[],preferences:mealPlanStore.preferences,count:count,mealType:selectedMealType,cuisineHint:cuisineHint.isEmpty ? nil:cuisineHint)}}label:{HStack{Spacer();if recipeStore.isGenerating{ProgressView().padding(.trailing,8);Text("Generating…")}else{Label("Generate with AI",systemImage:"wand.and.stars")};Spacer()}}.disabled(recipeStore.isGenerating)}
            }
            .navigationTitle("Generate Recipes").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.navigationBarLeading){Button("Cancel"){dismiss()}}}
            .onChange(of:recipeStore.isGenerating){g in if !g&&recipeStore.generationError==nil{dismiss()}}
        }
    }
}
