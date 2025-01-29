import SwiftUI

struct TimerRowView: View {
    let timerString: String
    
    var body: some View {
        HStack {
            Text("Next log card in:")
                .font(.subheadline)
            Spacer()
            Text(timerString)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.clear)
    }
} 