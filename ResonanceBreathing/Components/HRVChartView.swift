import SwiftUI
import Charts

struct HRVDataPoint: Identifiable {
    let id = UUID()
    let time: Double
    let value: Double
}

struct HRVChartView: View {
    let dataPoints: [HRVDataPoint]
    let breathingRate: Double
    let isAdapting: Bool

    private var statusText: String { isAdapting ? "Adapting" : "Locked" }
    private var statusColor: Color { isAdapting ? AppTheme.warmAccent : AppTheme.success }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Live HRV")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.chartLine)

                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.chartLine.opacity(0.35), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .frame(height: 104)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)

            HStack {
                Label(String(format: "%.1f bpm", breathingRate), systemImage: "wind")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                Text(statusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(statusColor.opacity(0.18))
                    )
            }
        }
        .padding(14)
        .mindfulCard(cornerRadius: 18)
        .padding(.horizontal, 16)
    }
}

#Preview {
    let sampleData = (0..<60).map { i in
        HRVDataPoint(time: Double(i), value: 40 + sin(Double(i) * 0.3) * 10 + Double.random(in: -3...3))
    }
    HRVChartView(dataPoints: sampleData, breathingRate: 5.5, isAdapting: true)
        .background(AppTheme.background)
}
