import SwiftUI

struct AddPantryItemView: View {
    @EnvironmentObject var pantryStore: PantryStore
    @Environment(\.dismiss) var dismiss
    var editingItem: PantryItem?
    @State private var name = ""; @State private var category: PantryCategory = .produce
    @State private var quantity = ""; @State private var unit = ""
    @State private var hasExpiration = false; @State private var expirationDate = Date()
    @State private var isLowStock = false
    var isEditing: Bool { editingItem != nil }
    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Name (e.g. Chicken Breast)", text: $name)
                    Picker("Category", selection: $category) { ForEach(PantryCategory.allCases) { Text("\($0.emoji) \($0.rawValue)").tag($0) } }
                }
                Section("Quantity") {
                    HStack { TextField("Amount", text: $quantity).keyboardType(.decimalPad); TextField("Unit", text: $unit) }
                }
                Section("Status") {
                    Toggle("Low Stock", isOn: $isLowStock)
                    Toggle("Has Expiration Date", isOn: $hasExpiration)
                    if hasExpiration { DatePicker("Expires", selection: $expirationDate, displayedComponents: .date) }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add to Pantry").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .navigationBarTrailing) { Button(isEditing ? "Save" : "Add") { save() }.disabled(!isValid).bold() }
            }
            .onAppear { if let i = editingItem { name=i.name; category=i.category; quantity=i.quantity; unit=i.unit; isLowStock=i.isLowStock; if let e=i.expirationDate { hasExpiration=true; expirationDate=e } } }
        }
    }

    private func save() {
        var item = editingItem ?? PantryItem(name: "", category: .produce, quantity: "", unit: "")
        item.name=name.trimmingCharacters(in: .whitespaces); item.category=category; item.quantity=quantity
        item.unit=unit; item.isLowStock=isLowStock; item.expirationDate=hasExpiration ? expirationDate : nil
        isEditing ? pantryStore.update(item) : pantryStore.add(item); dismiss()
    }
}
