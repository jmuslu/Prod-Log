import SwiftUI

struct LogCardView: View {
    let card: LogCard
    
    var timeSlotText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: card.startTime)) - \(formatter.string(from: card.endTime))"
    }
    
    var dateText: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        
        if calendar.isDateInToday(card.startTime) {
            return "Today"
        } else if calendar.isDateInYesterday(card.startTime) {
            return "Yesterday"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: card.startTime)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(dateText)
                    .font(.headline)
                Spacer()
                Text(timeSlotText)
                    .font(.subheadline)
            }
            .foregroundColor(.primary)
            
            if !card.categories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(card.categories.keys), id: \.id) { category in
                        if let percentage = card.categories[category] {
                            Text("\(category.name): \(Int(percentage))%")
                                .font(.caption)
                                .foregroundColor(.primary)
                                .padding(4)
                                .background(category.color.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
        .opacity(card.isComplete ? 0.6 : 1.0)
    }
} 