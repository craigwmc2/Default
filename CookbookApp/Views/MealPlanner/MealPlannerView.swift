import SwiftUI

struct MealPlannerView: View {
    @EnvironmentObject var recipeStore: RecipeStore
    @EnvironmentObject var mealPlanStore: MealPlanStore
    @State private var selectedDay = 0
    @State private var pickingFor: (Int,MealType)?
    @State private var showingList = false
    var plan: MealPlan { mealPlanStore.currentPlan }
    var body: some View {
        NavigationView {
            VStack(spacing:0) {
                ScrollView(.horizontal,showsIndicators:false){
                    HStack(spacing:4){
                        ForEach(Array(plan.days.enumerated()),id:\.offset){idx,day in
                            Button{selectedDay=idx}label:{
                                VStack(spacing:4){
                                    Text(day.shortDayName).font(.caption2).foregroundColor(selectedDay==idx ? .white:.secondary)
                                    Text(day.dateLabel).font(.caption).bold(selectedDay==idx).foregroundColor(selectedDay==idx ? .white:.primary)
                                }.padding(.horizontal,12).padding(.vertical,8)
                                .background(day.isToday ? (selectedDay==idx ? Color.green:Color.green.opacity(0.2)):(selectedDay==idx ? Color.primary:Color.clear)).cornerRadius(10)
                            }
                        }
                    }.padding()
                }
                Divider()
                let day = plan.days[selectedDay]
                ScrollView{
                    VStack(spacing:16){
                        Text(day.dayName).font(.title3).bold().frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal).padding(.top,8)
                        ForEach(MealType.allCases.filter{$0 != .snack}){mt in mealSlot(day:day,idx:selectedDay,mt:mt)}
                    }.padding(.bottom,32)
                }
            }
            .navigationTitle("Meal Planner")
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading){Button{showingList=true}label:{Image(systemName:"cart")}}
                ToolbarItem(placement:.navigationBarTrailing){Menu{Button("Next Week"){mealPlanStore.advanceToNextWeek()};Button("Reset to Current Week"){mealPlanStore.resetToCurrentWeek()}}label:{Image(systemName:"ellipsis.circle")}}
            }
            .sheet(isPresented:$showingList){ShoppingListView(items:mealPlanStore.shoppingList(from:recipeStore.recipes))}
            .sheet(item:Binding(get:{pickingFor.map{RecipePickerContext(dayIndex:$0.0,mealType:$0.1)}},set:{_ in pickingFor=nil})){ctx in RecipePickerView(dayIndex:ctx.dayIndex,mealType:ctx.mealType)}
        }
    }
    private func mealSlot(day:DayPlan,idx:Int,mt:MealType) -> some View {
        let meal:PlannedMeal? = {switch mt{case .breakfast:return day.breakfast;case .lunch:return day.lunch;case .dinner:return day.dinner;case .snack:return nil}}()
        return VStack(alignment:.leading,spacing:8){
            HStack{Text(mt.emoji+" "+mt.rawValue).font(.subheadline);Spacer();if meal != nil{Button{mealPlanStore.clearMeal(dayIndex:idx,mealType:mt)}label:{Image(systemName:"xmark.circle").foregroundColor(.secondary)}}}
            if let m=meal{
                HStack{VStack(alignment:.leading,spacing:4){Text(m.recipeName).font(.subheadline).bold();Text("\(m.servings) servings").font(.caption).foregroundColor(.secondary)};Spacer();Image(systemName:"checkmark.circle.fill").foregroundColor(.green)}.padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
            } else {
                Button{pickingFor=(idx,mt)}label:{HStack{Image(systemName:"plus.circle.dashed");Text("Add \(mt.rawValue)");Spacer()}.padding().background(Color(.secondarySystemBackground)).cornerRadius(12).foregroundColor(.secondary)}
            }
        }.padding(.horizontal)
    }
}
struct RecipePickerContext:Identifiable{let id=UUID();let dayIndex:Int;let mealType:MealType}
struct RecipePickerView:View{
    @EnvironmentObject var recipeStore:RecipeStore;@EnvironmentObject var mealPlanStore:MealPlanStore;@Environment(\.dismiss) var dismiss
    let dayIndex:Int;let mealType:MealType;@State private var servings=4;@State private var search=""
    var filtered:[Recipe]{guard !search.isEmpty else{return recipeStore.recipes};return recipeStore.recipes.filter{$0.name.localizedCaseInsensitiveContains(search)}}
    var body:some View{
        NavigationView{
            VStack{Stepper("Servings: \(servings)",value:$servings,in:1...20).padding()
                List(filtered){r in Button{mealPlanStore.assignMeal(PlannedMeal(recipeId:r.id,recipeName:r.name,servings:servings,mealType:mealType),to:dayIndex,mealType:mealType);dismiss()}label:{RecipeRowView(recipe:r)}.foregroundColor(.primary)}.searchable(text:$search,prompt:"Search")}
            .navigationTitle("Pick \(mealType.rawValue)").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.navigationBarLeading){Button("Cancel"){dismiss()}}}
        }.onAppear{servings=mealPlanStore.preferences.defaultServings}
    }
}
