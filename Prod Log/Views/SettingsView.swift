import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingAddCategory = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time Interval")) {
                    Picker("Interval", selection: $settingsManager.timeInterval) {
                        ForEach(settingsManager.availableIntervals, id: \.self) { interval in
                            Text("\(interval) hour\(interval == 1 ? "" : "s")")
                                .tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Categories")) {
                    ForEach(settingsManager.categories) { category in
                        CategoryRow(category: category)
                            .swipeActions(allowsFullSwipe: false) {
                                if !category.isDefault {
                                    Button(role: .destructive) {
                                        settingsManager.removeCategory(category)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                    
                    Button(action: { showingAddCategory = true }) {
                        Label("Add Category", systemImage: "plus")
                    }
                }
                
                Section {
                    Button("Reset Points", role: .destructive) {
                        settingsManager.resetPoints()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    
    var body: some View {
        HStack {
            Circle()
                .fill(category.color)
                .frame(width: 20, height: 20)
            
            Text(category.name)
            
            Spacer()
            
            Text("\(Int(category.pointsPerMinute)) pts/min")
                .foregroundColor(.secondary)
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var name = ""
    @State private var color = Color.blue
    @State private var pointsPerMinute = 5.0
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)
                
                ColorPicker("Category Color", selection: $color)
                
                Stepper("Points per Minute: \(Int(pointsPerMinute))", value: $pointsPerMinute, in: 1...20)
            }
            .navigationTitle("New Category")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Add") {
                    settingsManager.addCategory(
                        name: name,
                        color: color,
                        pointsPerMinute: pointsPerMinute
                    )
                    dismiss()
                }
                .disabled(name.isEmpty)
            )
        }
    }
} 