import SwiftUI

struct CookingModeView: View {
    let recipe: Recipe
    @Environment(\.dismiss) var dismiss
    @State private var currentStep = 0
    @State private var timeRemaining = 0
    @State private var timerRunning = false
    @State private var timerTask: Task<Void,Never>?
    @State private var showingIngredients = false
    var step: RecipeStep { recipe.instructions[currentStep] }
    var isLast: Bool { currentStep == recipe.instructions.count - 1 }
    var progress: Double { Double(currentStep+1)/Double(recipe.instructions.count) }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing:0) {
                HStack {
                    Button("Exit"){stopTimer();dismiss()}.foregroundColor(.white.opacity(0.7))
                    Spacer(); Text(recipe.name).font(.headline).foregroundColor(.white).lineLimit(1); Spacer()
                    Button{showingIngredients=true}label:{Image(systemName:"list.bullet").foregroundColor(.white.opacity(0.7))}
                }.padding()
                VStack(spacing:4) {
                    GeometryReader{g in ZStack(alignment:.leading){RoundedRectangle(cornerRadius:4).fill(Color.white.opacity(0.2));RoundedRectangle(cornerRadius:4).fill(Color.green).frame(width:g.size.width*progress).animation(.spring(),value:progress)}.frame(height:6)}.frame(height:6)
                    Text("Step \(currentStep+1) of \(recipe.instructions.count)").font(.caption).foregroundColor(.white.opacity(0.6))
                }.padding(.horizontal).padding(.bottom,8)
                Spacer()
                VStack(spacing:28) {
                    Text(step.instruction).font(.title2).multilineTextAlignment(.center).foregroundColor(.white).padding(.horizontal,24).transition(.opacity).id(currentStep)
                    if step.timerMinutes != nil {
                        VStack(spacing:12) {
                            Text(String(format:"%02d:%02d",timeRemaining/60,timeRemaining%60)).font(.system(size:72,weight:.thin,design:.monospaced)).foregroundColor(timeRemaining==0 ? .red : .green)
                            HStack(spacing:20) {
                                Button{if timerRunning{pauseTimer()}else{startTimer()}}label:{Image(systemName:timerRunning ? "pause.circle.fill":"play.circle.fill").font(.system(size:48)).foregroundColor(.green)}
                                Button{resetTimer()}label:{Image(systemName:"arrow.counterclockwise.circle").font(.system(size:36)).foregroundColor(.white.opacity(0.5))}
                            }
                        }
                    }
                }
                Spacer()
                HStack(spacing:16) {
                    if currentStep>0 { Button{stopTimer();withAnimation{currentStep-=1}}label:{HStack{Image(systemName:"chevron.left");Text("Back")}.frame(maxWidth:.infinity).padding().background(Color.white.opacity(0.1)).foregroundColor(.white).cornerRadius(14)} }
                    if isLast { Button{stopTimer();dismiss()}label:{Text("Done! Enjoy!").frame(maxWidth:.infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(14).font(.headline)} }
                    else { Button{stopTimer();withAnimation{currentStep+=1}}label:{HStack{Text("Next");Image(systemName:"chevron.right")}.frame(maxWidth:.infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(14).font(.headline)} }
                }.padding()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear{loadTimer()}.onChange(of:currentStep){_ in loadTimer()}
        .sheet(isPresented:$showingIngredients){ NavigationView{ List(recipe.ingredients){Text($0.display)}.navigationTitle("Ingredients").navigationBarTitleDisplayMode(.inline).toolbar{ToolbarItem(placement:.navigationBarTrailing){Button("Done"){showingIngredients=false}}} } }
    }
    private func loadTimer() { stopTimer(); timeRemaining = (step.timerMinutes ?? 0)*60 }
    private func startTimer() {
        timerRunning=true; timerTask=Task{
            while timeRemaining>0 && !Task.isCancelled { try? await Task.sleep(nanoseconds:1_000_000_000); if !Task.isCancelled { await MainActor.run{timeRemaining-=1} } }
            await MainActor.run{timerRunning=false}
        }
    }
    private func pauseTimer(){timerRunning=false;timerTask?.cancel()}
    private func stopTimer(){timerRunning=false;timerTask?.cancel()}
    private func resetTimer(){stopTimer();timeRemaining=(step.timerMinutes ?? 0)*60}
}
