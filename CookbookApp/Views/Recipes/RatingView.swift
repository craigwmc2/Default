import SwiftUI

struct RatingView: View {
    let recipe: Recipe; @Binding var currentRating: Int; let onRate: (Int)->Void
    @Environment(\.dismiss) var dismiss
    @State private var sel: Int
    init(recipe: Recipe,currentRating: Binding<Int>,onRate: @escaping (Int)->Void){self.recipe=recipe;_currentRating=currentRating;self.onRate=onRate;_sel=State(initialValue:currentRating.wrappedValue)}
    var label: String { switch sel { case 1:return "Not for me";case 2:return "Could be better";case 3:return "Pretty good";case 4:return "Really liked it";case 5:return "Absolutely loved it!";default:return "Tap a star to rate" } }
    var emoji: String { switch sel { case 1:return "😞";case 2:return "😐";case 3:return "🙂";case 4:return "😊";case 5:return "🤩";default:return "⭐️" } }
    var body: some View {
        NavigationView {
            VStack(spacing:32){
                VStack(spacing:8){Text(recipe.name).font(.title2).bold();Text("How did you like it?").font(.subheadline).foregroundColor(.secondary)}.padding(.top,32)
                Text(emoji).font(.system(size:72))
                HStack(spacing:16){ForEach(1...5,id:\.self){s in Button{withAnimation(.spring()){sel=s}}label:{Image(systemName:s<=sel ? "star.fill":"star").font(.system(size:40)).foregroundColor(.yellow)}}}
                Text(label).font(.headline).foregroundColor(.secondary).animation(.default,value:sel)
                if sel<=2&&sel>0 {
                    VStack(spacing:8){Image(systemName:"lightbulb").foregroundColor(.orange);Text("Got it! We'll avoid similar recipes in the future.").font(.subheadline).multilineTextAlignment(.center).foregroundColor(.secondary)}.padding().background(Color.orange.opacity(0.1)).cornerRadius(14).padding(.horizontal)
                }
                Spacer()
                Button{guard sel>0 else{return};currentRating=sel;onRate(sel);dismiss()}label:{Text("Submit Rating").frame(maxWidth:.infinity).padding().background(sel>0 ? Color.green:Color.gray).foregroundColor(.white).cornerRadius(14).font(.headline)}.disabled(sel==0).padding(.horizontal).padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.navigationBarLeading){Button("Cancel"){dismiss()}}}
        }
    }
}
