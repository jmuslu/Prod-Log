import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingCategorySheet = false
    @State private var editingCategory: Category?
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time Interval")) {
                    TimeIntervalPicker(selection: Binding(
                        get: { Int(settingsManager.timeInterval) },
                        set: { settingsManager.timeInterval = Double($0) }
                    ), intervals: settingsManager.availableIntervals.map { Int($0) })
                }
                
                Section(header: Text("Categories")) {
                    ForEach(settingsManager.categories) { category in
                        CategoryRow(category: category)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            settingsManager.removeCategory(settingsManager.categories[index])
                        }
                    }
                    
                    Button(action: {
                        editingCategory = nil
                        showingCategorySheet = true
                    }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                    }
                }
                
                Section {
                    Button(action: {
                        settingsManager.resetToDefaultCategories()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                            Text("Reset to Default Categories")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.red)
                            Text("Reset Today's Logs")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCategorySheet) {
                CategoryEditSheet(category: editingCategory)
            }
            .alert("Reset Today's Logs", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settingsManager.resetTodayPoints()
                    NotificationCenter.default.post(name: .resetLogCards, object: nil)
                }
            } message: {
                Text("This will clear all logged activities and bring back all log cards for the last 36 hours. This action cannot be undone.")
            }
        }
    }
}

struct TimeIntervalPicker: View {
    @Binding var selection: Int
    let intervals: [Int]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(intervalText)
                .font(.headline)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(intervals, id: \.self) { interval in
                        Button(action: {
                            selection = interval
                        }) {
                            Text(interval == -1 ? "Auto" : "\(interval)h")
                                .font(.system(.body, design: .rounded))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selection == interval ?
                                        Color.accentColor :
                                        Color.secondary.opacity(0.1)
                                )
                                .foregroundColor(
                                    selection == interval ?
                                        .white :
                                        .primary
                                )
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var intervalText: String {
        if selection == -1 {
            return "Automatic intervals (maximizes card sizes)"
        } else {
            return "\(selection) hour\(selection == 1 ? "" : "s") between log cards"
        }
    }
}

struct CategoryEditSheet: View {
    let category: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var pointsPerMinute: Int = 1
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)
                
                ColorPicker("Color", selection: $color)
                
                Stepper(value: $pointsPerMinute, in: 1...20) {
                    Text("Points per minute: \(pointsPerMinute)")
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(category == nil ? "Add" : "Save") {
                        saveCategory()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .onAppear {
            if let category = category {
                name = category.name
                color = category.color
                pointsPerMinute = Int(category.pointsPerMinute)
            }
        }
    }
    
    private func saveCategory() {
        if let existingCategory = category {
            let updatedCategory = Category(
                id: existingCategory.id,
                name: name,
                color: color,
                pointsPerMinute: Double(pointsPerMinute),
                isDefault: existingCategory.isDefault,
                deletedDate: existingCategory.deletedDate
            )
            settingsManager.updateCategory(updatedCategory)
        } else {
            let newCategory = Category(
                name: name,
                color: color,
                pointsPerMinute: Double(pointsPerMinute),
                isDefault: false
            )
            settingsManager.addCategory(newCategory)
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
            Text("\(category.pointsPerMinuteInt) pts/min")
                .foregroundColor(.secondary)
        }
    }
}