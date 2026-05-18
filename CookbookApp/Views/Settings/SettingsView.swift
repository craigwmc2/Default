import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var apiKey = UserDefaults.standard.string(forKey:"anthropic_api_key") ?? ""
    @State private var showKey = false; @State private var newAllergy = ""; @State private var newDislike = ""
    var prefs: Binding<UserPreferences> { $mealPlanStore.preferences }
    var body: some View {
        NavigationView {
            Form {
                Section("Profile"){HStack{Text("Name");Spacer();TextField("Your name",text:prefs.userName).multilineTextAlignment(.trailing).foregroundColor(.secondary)}}
                Section(header:Text("AI Integration"),footer:Text("Stored locally, never shared.")){
                    HStack{
                        if showKey{TextField("sk-ant-...",text:$apiKey).autocapitalization(.none).disableAutocorrection(true)}else{SecureField("Anthropic API Key",text:$apiKey)}
                        Button{showKey.toggle()}label:{Image(systemName:showKey ? "eye.slash":"eye").foregroundColor(.secondary)}
                    }
                    Button("Save API Key"){UserDefaults.standard.set(apiKey,forKey:"anthropic_api_key")}.disabled(apiKey.isEmpty)
                }
                Section(header:Text("Allergies & Intolerances"),footer:Text("Always excluded from recipes.")){
                    ForEach(commonAllergens,id:\.self){a in Toggle(a,isOn:Binding(get:{mealPlanStore.preferences.allergies.contains(a)},set:{if $0{mealPlanStore.preferences.allergies.insert(a)}else{mealPlanStore.preferences.allergies.remove(a)};mealPlanStore.savePreferences()}))}
                    HStack{TextField("Add custom…",text:$newAllergy);Button("Add"){let t=newAllergy.trimmingCharacters(in:.whitespaces);if !t.isEmpty{mealPlanStore.preferences.allergies.insert(t);mealPlanStore.savePreferences();newAllergy=""}}.disabled(newAllergy.trimmingCharacters(in:.whitespaces).isEmpty)}
                }
                Section("Dietary Preferences"){ForEach(DietaryRestriction.allCases){d in Toggle(d.rawValue,isOn:Binding(get:{mealPlanStore.preferences.dietaryRestrictions.contains(d)},set:{if $0{mealPlanStore.preferences.dietaryRestrictions.insert(d)}else{mealPlanStore.preferences.dietaryRestrictions.remove(d)};mealPlanStore.savePreferences()}))}}
                Section(header:Text("Disliked Ingredients"),footer:Text("Excluded from suggestions.")){
                    ForEach(mealPlanStore.preferences.dislikedIngredients,id:\.self){i in HStack{Text(i);Spacer();Button{mealPlanStore.preferences.dislikedIngredients.removeAll{$0==i};mealPlanStore.savePreferences()}label:{Image(systemName:"minus.circle.fill").foregroundColor(.red)}}}
                    HStack{TextField("Add disliked…",text:$newDislike);Button("Add"){let t=newDislike.trimmingCharacters(in:.whitespaces);if !t.isEmpty{mealPlanStore.preferences.dislikedIngredients.append(t);mealPlanStore.savePreferences();newDislike=""}}.disabled(newDislike.trimmingCharacters(in:.whitespaces).isEmpty)}
                }
                Section("Cooking Preferences"){
                    Picker("Skill Level",selection:prefs.skillLevel){ForEach(CookingSkillLevel.allCases){Text($0.rawValue).tag($0)}}
                    HStack{Text("Max Cook Time");Spacer();Text("\(mealPlanStore.preferences.maxCookTime) min").foregroundColor(.secondary)}
                    Slider(value:Binding(get:{Double(mealPlanStore.preferences.maxCookTime)},set:{mealPlanStore.preferences.maxCookTime=Int($0)}),in:15...180,step:15)
                    HStack{Text("Default Servings");Spacer();Stepper("\(mealPlanStore.preferences.defaultServings)",value:prefs.defaultServings,in:1...12)}
                }.onChange(of:mealPlanStore.preferences.skillLevel){_ in mealPlanStore.savePreferences()}.onChange(of:mealPlanStore.preferences.maxCookTime){_ in mealPlanStore.savePreferences()}.onChange(of:mealPlanStore.preferences.defaultServings){_ in mealPlanStore.savePreferences()}
                Section(header:Text("Avoided from Low Ratings"),footer:Text("Auto-learned from poorly rated recipes.")){
                    if mealPlanStore.preferences.avoidFromRatings.isEmpty{Text("None yet — rate recipes to learn preferences.").font(.caption).foregroundColor(.secondary)}
                    else{ForEach(mealPlanStore.preferences.avoidFromRatings,id:\.self){i in HStack{Text(i);Spacer();Button{mealPlanStore.preferences.avoidFromRatings.removeAll{$0==i};mealPlanStore.savePreferences()}label:{Image(systemName:"minus.circle.fill").foregroundColor(.red)}}}}
                }
            }
            .navigationTitle("Settings")
        }
    }
}
