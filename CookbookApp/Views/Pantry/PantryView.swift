import SwiftUI

struct PantryView: View {
    @EnvironmentObject var pantryStore: PantryStore
    @State private var showingAddItem = false
    @State private var searchText = ""
    @State private var editingItem: PantryItem?

    var body: some View {
        NavigationView {
            Group {
                if pantryStore.items.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cart.badge.plus").font(.system(size: 60)).foregroundColor(.secondary)
                        Text("Your pantry is empty").font(.title3).bold()
                        Text("Add ingredients to get personalized recipe suggestions.").multilineTextAlignment(.center).foregroundColor(.secondary)
                        Button("Add First Item") { showingAddItem = true }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    List {
                        if !pantryStore.alerts.isEmpty {
                            Section(header: Text("Attention Needed").foregroundColor(.orange)) {
                                ForEach(pantryStore.alerts.prefix(5)) { PantryItemRow(item: $0) }
                            }
                        }
                        ForEach(pantryStore.categoriesInUse) { cat in
                            let catItems = pantryStore.items(for: cat).filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
                            if !catItems.isEmpty {
                                Section(header: HStack { Text(cat.emoji); Text(cat.rawValue) }) {
                                    ForEach(catItems) { item in
                                        PantryItemRow(item: item).contentShape(Rectangle()).onTapGesture { editingItem = item }
                                            .swipeActions(edge: .trailing) { Button(role: .destructive) { pantryStore.delete(item) } label: { Label("Delete", systemImage: "trash") } }
                                            .swipeActions(edge: .leading) {
                                                Button { var u = item; u.isLowStock.toggle(); pantryStore.update(u) } label: {
                                                    Label(item.isLowStock ? "In Stock" : "Low Stock", systemImage: item.isLowStock ? "checkmark" : "exclamationmark")
                                                }.tint(.orange)
                                            }
                                    }
                                }
                            }
                        }
                    }.searchable(text: $searchText, prompt: "Search pantry").listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Pantry")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { showingAddItem = true } label: { Image(systemName: "plus") } } }
            .sheet(isPresented: $showingAddItem) { AddPantryItemView() }
            .sheet(item: $editingItem) { AddPantryItemView(editingItem: $0) }
        }
    }
}

struct PantryItemRow: View {
    let item: PantryItem
    var body: some View {
        HStack {
            Text(item.statusEmoji)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.subheadline)
                HStack {
                    Text("\(item.quantity) \(item.unit)")
                    if let e = item.expirationDate { Text("· Exp: \(e, format: .dateTime.month().day())") }
                }.font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if item.isExpired { Text("EXPIRED").font(.caption2).bold().foregroundColor(.red) }
        }
    }
}
