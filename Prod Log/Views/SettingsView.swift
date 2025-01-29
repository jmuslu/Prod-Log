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
                    TimeIntervalSlider(selection: Binding(
                        get: { Int(settingsManager.timeInterval) },
                        set: { settingsManager.timeInterval = Double($0) }
                    ), intervals: settingsManager.availableIntervals.map { Int($0) })
                }
                
                Section(header: Text("Categories")) {
                    ForEach(settingsManager.categories) { category in
                        CategoryRow(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCategory = category
                                showingCategorySheet = true
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let category = settingsManager.categories[index]
                            if !category.isDefault {
                                settingsManager.removeCategory(category)
                            }
                        }
                    }
                    
                    Button(action: {
                        editingCategory = nil
                        showingCategorySheet = true
                    }) {
                        Label("Add Category", systemImage: "plus")
                    }
                }
                
                Section {
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
                Text("This will clear all logged activities for today. This action cannot be undone.")
            }
        }
    }
}

struct TimeIntervalSlider: View {
    @Binding var selection: Int
    let intervals: [Int]
    
    var body: some View {
        VStack(spacing: 20) {
            // Current selection display
            Text("\(selection) hour\(selection == 1 ? "" : "s") between log cards")
                .font(.headline)
                .foregroundColor(.primary)
            
            // Timeline slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Base line
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 2)
                    
                    // Interval markers
                    ForEach(intervals, id: \.self) { interval in
                        TimelineMarker(
                            interval: interval,
                            isSelected: interval == selection,
                            width: geometry.size.width,
                            intervals: intervals
                        )
                    }
                    
                    // Selection indicator
                    if let index = intervals.firstIndex(of: selection) {
                        let position = (CGFloat(index) / CGFloat(intervals.count - 1)) * (geometry.size.width - 40)
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 20, height: 20)
                            .offset(x: position + 10)
                    }
                }
                .frame(height: 60)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            updateSelection(at: value.location.x, in: geometry.size.width)
                        }
                )
            }
            .frame(height: 60)
            
            // Hour divisions
            Text("\(24/selection) time slots per day")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func updateSelection(at position: CGFloat, in width: CGFloat) {
        let stepWidth = width / CGFloat(intervals.count - 1)
        let index = Int(round(position / stepWidth))
        let boundedIndex = max(0, min(index, intervals.count - 1))
        selection = intervals[boundedIndex]
    }
}

struct TimelineMarker: View {
    let interval: Int
    let isSelected: Bool
    let width: CGFloat
    let intervals: [Int]
    
    var body: some View {
        if let index = intervals.firstIndex(of: interval) {
            let position = (CGFloat(index) / CGFloat(intervals.count - 1)) * (width - 40)
            VStack(spacing: 4) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 2, height: 10)
                Text("\(interval)h")
                    .font(.caption)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .offset(x: position + 20)
        }
    }
}

struct CategoryEditSheet: View {
    let category: Category?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var name: String = ""
    @State private var color: Color = .blue
    @State private var pointsPerMinute: Double = 1.0
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)
                
                ColorPicker("Color", selection: $color)
                
                Stepper(value: $pointsPerMinute, in: 0.5...10.0, step: 0.5) {
                    Text("Points per minute: \(pointsPerMinute, specifier: "%.1f")")
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
                pointsPerMinute = category.pointsPerMinute
            }
        }
    }
    
    private func saveCategory() {
        if let existingCategory = category {
            // Create updated category
            let updatedCategory = Category(
                id: existingCategory.id,
                name: name,
                color: color,
                pointsPerMinute: pointsPerMinute,
                isDefault: existingCategory.isDefault,
                deletedDate: existingCategory.deletedDate
            )
            settingsManager.updateCategory(updatedCategory)
        } else {
            let newCategory = Category(
                name: name,
                color: color,
                pointsPerMinute: pointsPerMinute,
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
            
            Text("\(Int(category.pointsPerMinute)) pts/min")
                .foregroundColor(.secondary)
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}