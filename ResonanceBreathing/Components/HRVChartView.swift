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

    var body: some View {
        VStack(spacing: 4) {
            Chart(dataPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .foregroundStyle(AppTheme.chartLine)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", point.time),
                    y: .value("RMSSD", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.chartLine.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .frame(height: 80)

            HStack {
                Text("Rate: \(String(format: "%.1f", breathingRate)) bpm")
                    .foregroundStyle(AppTheme.primaryText)
                if isAdapting {
                    Text("adapting")
                        .foregroundStyle(AppTheme.petalTeal)
                } else {
                    Text("locked")
                        .foregroundStyle(.green.opacity(0.8))
                }
                Spacer()
            }
            .font(.system(.caption2, design: .monospaced))
        }
        .padding(.horizontal)
    }
}

#Preview {
    let sampleData = (0..<60).map { i in
        HRVDataPoint(time: Double(i), value: 40 + sin(Double(i) * 0.3) * 10 + Double.random(in: -3...3))
    }
    HRVChartView(dataPoints: sampleData, breathingRate: 5.5, isAdapting: true)
        .background(AppTheme.background)
}
