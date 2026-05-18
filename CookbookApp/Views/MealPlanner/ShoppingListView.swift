import SwiftUI

struct ShoppingListView: View {
    let items: [ShoppingListItem]
    @Environment(\.dismiss) var dismiss
    @State private var checkedIds: Set<UUID> = []
    var unchecked: [ShoppingListItem] { items.filter { !checkedIds.contains($0.id) } }
    var checked: [ShoppingListItem]   { items.filter {  checkedIds.contains($0.id) } }
    var body: some View {
        NavigationView {
            List {
                if items.isEmpty { Section { Text("Plan some meals to auto-generate your shopping list.").font(.subheadline).foregroundColor(.secondary) } }
                else {
                    Section("To Buy (\(unchecked.count))") { ForEach(unchecked) { row($0) } }
                    if !checked.isEmpty { Section("In Cart (\(checked.count))") { ForEach(checked) { row($0) } } }
                }
            }.listStyle(.insetGrouped)
            .navigationTitle("Shopping List").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement:.navigationBarLeading){Button("Done"){dismiss()}}
                ToolbarItem(placement:.navigationBarTrailing){if !checked.isEmpty{Button("Clear Checked"){checkedIds.removeAll()}}}
            }
        }
    }
    private func row(_ item: ShoppingListItem) -> some View {
        Button{if checkedIds.contains(item.id){checkedIds.remove(item.id)}else{checkedIds.insert(item.id)}}label:{
            HStack{
                Image(systemName:checkedIds.contains(item.id) ? "checkmark.circle.fill":"circle").foregroundColor(checkedIds.contains(item.id) ? .green:.secondary)
                Text(item.display).strikethrough(checkedIds.contains(item.id)).foregroundColor(checkedIds.contains(item.id) ? .secondary:.primary)
            }
        }
    }
}
