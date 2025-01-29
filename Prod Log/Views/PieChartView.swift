import SwiftUI

struct PieChartView: View {
    let data: [Category: Double]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(data.keys), id: \.id) { category in
                    if let value = data[category], value > 0 {
                        PieSlice(
                            startAngle: startAngle(for: category),
                            endAngle: endAngle(for: category)
                        )
                        .fill(category.color)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
    
    private func startAngle(for category: Category) -> Angle {
        let priorCategories = Array(data.keys).prefix(while: { $0.id != category.id })
        let priorTotal = priorCategories.reduce(0.0) { $0 + (data[$1] ?? 0) }
        return .degrees(priorTotal * 360.0 / 100.0)
    }
    
    private func endAngle(for category: Category) -> Angle {
        let start = startAngle(for: category)
        let value = data[category] ?? 0
        return start + .degrees(value * 360.0 / 100.0)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center,
                   radius: radius,
                   startAngle: Angle(degrees: -90) + startAngle,
                   endAngle: Angle(degrees: -90) + endAngle,
                   clockwise: false)
        path.closeSubpath()
        return path
    }
} 