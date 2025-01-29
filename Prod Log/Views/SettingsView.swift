import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var showingCategorySheet = false
    @State private var editingCategory: Category?
    
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
                            .swipeActions(allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    settingsManager.removeCategory(category)
                                } label: {
                                    Label("Delete", systemImage: "trash")
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
                    Button("Reset Points", role: .destructive) {
                        settingsManager.resetPoints()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCategorySheet) {
                CategoryEditView(category: editingCategory)
                    .environmentObject(settingsManager)
            }
        }
    }
}

struct TimeIntervalSlider: View {
    @Binding var selection: Int
    let intervals: [Int]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: sliderPosition(in: geometry.size.width), height: 4)
                    
                    HStack(spacing: 0) {
                        ForEach(intervals, id: \.self) { interval in
                            Rectangle()
                                .fill(selection >= interval ? Color.accentColor : Color.secondary.opacity(0.2))
                                .frame(width: 2, height: 20)
                                .frame(maxWidth: .infinity)
                                .onTapGesture {
                                    withAnimation {
                                        selection = interval
                                    }
                                }
                        }
                    }
                }
                
                HStack(spacing: 0) {
                    ForEach(intervals, id: \.self) { interval in
                        Text("\(interval)h")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateSelection(at: value.location.x, in: geometry.size.width)
                    }
            )
        }
        .frame(height: 50)
        .padding(.horizontal)
    }
    
    private func sliderPosition(in width: CGFloat) -> CGFloat {
        let index = CGFloat(intervals.firstIndex(of: selection) ?? 0)
        let segmentWidth = width / CGFloat(intervals.count - 1)
        return index * segmentWidth
    }
    
    private func updateSelection(at position: CGFloat, in width: CGFloat) {
        let segmentWidth = width / CGFloat(intervals.count - 1)
        let index = Int((position / segmentWidth).rounded())
        if index >= 0 && index < intervals.count {
            selection = intervals[index]
        }
    }
}

struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settingsManager: SettingsManager
    
    let category: Category?
    @State private var name: String
    @State private var color: Color
    @State private var pointsPerMinute: Double
    
    init(category: Category?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _color = State(initialValue: category?.color ?? .blue)
        _pointsPerMinute = State(initialValue: category?.pointsPerMinute ?? 5.0)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category Name", text: $name)
                    .foregroundColor(.primary)
                
                ColorPicker("Category Color", selection: $color)
                
                Stepper("Points per Minute: \(Int(pointsPerMinute))", value: $pointsPerMinute, in: 1...20)
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button(category == nil ? "Add" : "Save") {
                    if let existingCategory = category {
                        settingsManager.updateCategory(
                            existingCategory,
                            name: name,
                            color: color,
                            pointsPerMinute: pointsPerMinute
                        )
                    } else {
                        settingsManager.addCategory(
                            name: name,
                            color: color,
                            pointsPerMinute: pointsPerMinute
                        )
                    }
                    dismiss()
                }
                .disabled(name.isEmpty)
            )
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