import SwiftUI

struct CategoryRowView: View {
    let category: Category
    let percentage: Double
    let isExpanded: Bool
    let timeInterval: Double
    let onTap: () -> Void
    let onSliderChange: (Double) -> Void
    
    private var timeString: String {
        let totalMinutes = (timeInterval * 60.0) * (percentage / 100.0)
        let hours = Int(totalMinutes / 60.0)
        let minutes = Int(totalMinutes.truncatingRemainder(dividingBy: 60.0))
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(category.color)
                    .frame(width: 20, height: 20)
                
                Text(category.name)
                
                Spacer()
                
                Text("\(Int(percentage))% (\(timeString))")
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            if isExpanded {
                Slider(value: Binding(
                    get: { percentage },
                    set: { onSliderChange($0) }
                ), in: 0...100, step: 5)
                .padding(.horizontal)
            }
        }
    }
} 