import SwiftUI
import SwiftData
import BreathingCore

struct CalibrationView: View {
    @StateObject private var calibrationManager = CalibrationManager()
    @Query private var allSettings: [UserSettings]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppTheme.backgroundGradient.ignoresSafeArea()

            switch calibrationManager.state {
            case .idle:
                introView
            case .preparingRate(let index):
                preparingView(index: index)
            case .breathing(let index):
                breathingView(index: index)
            case .analyzing:
                analyzingView
            case .complete(let bestRate):
                completeView(bestRate: bestRate)
            }
        }
        .navigationTitle("Calibration")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.accent)

            Text("Find Your Resonance")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)

            Text("We'll guide you through three breathing rates to find which one produces the strongest heart rate variability response for you.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 8) {
                ratePreviewRow(rate: 4.5, label: "Slow")
                ratePreviewRow(rate: 5.5, label: "Medium")
                ratePreviewRow(rate: 6.5, label: "Fast")
            }
            .padding(16)
            .mindfulCard()
            .padding(.horizontal, 24)

            Text("Each rate is tested for 30 seconds. Total time: ~2 minutes.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)

            Spacer()

            Button(action: { calibrationManager.startCalibration() }) {
                Text("Begin Calibration")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.backgroundBase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.buttonGradient)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func ratePreviewRow(rate: Double, label: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(width: 60, alignment: .leading)
            Text(String(format: "%.1f bpm", rate))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(String(format: "%.1fs cycle", 60.0 / rate))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    // MARK: - Preparing

    private func preparingView(index: Int) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Get Ready")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            Text(String(format: "%.1f bpm", CalibrationManager.testRates[index]))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)

            Text("\(calibrationManager.countdown)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)

            progressDots(currentIndex: index)

            Spacer()

            cancelButton
        }
    }

    // MARK: - Breathing

    private func breathingView(index: Int) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text(String(format: "%.1f bpm", CalibrationManager.testRates[index]))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            breathCircle

            Text(calibrationManager.guidePhase.label)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)

            if calibrationManager.heartRate > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppTheme.danger)
                    Text(String(format: "%.0f", calibrationManager.heartRate))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                }
            }

            ProgressView(value: calibrationManager.segmentProgress)
                .tint(AppTheme.accent)
                .padding(.horizontal, 40)

            progressDots(currentIndex: index)

            Spacer()

            cancelButton
        }
    }

    private var breathCircle: some View {
        let expansion = calibrationManager.guidePhase == .inhale
            ? calibrationManager.guideProgress
            : (calibrationManager.guidePhase == .exhale ? 1.0 - calibrationManager.guideProgress : 1.0)
        let size: CGFloat = 100 + CGFloat(expansion) * 80

        return Circle()
            .fill(AppTheme.tint.opacity(0.3 + expansion * 0.3))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(AppTheme.tint.opacity(0.6), lineWidth: 2)
            )
            .animation(.easeInOut(duration: 0.3), value: expansion)
    }

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(AppTheme.accent)

            Text("Analyzing...")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)

            Text("Finding your optimal resonance rate")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()
        }
    }

    // MARK: - Complete

    private func completeView(bestRate: Double) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.success)

            Text("Your Resonance Rate")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)

            Text(String(format: "%.1f bpm", bestRate))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)

            rsaComparisonChart

            Spacer()

            Button(action: { saveCalibration(rate: bestRate) }) {
                Text("Save")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.backgroundBase)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.buttonGradient)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var rsaComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RSA Amplitude by Rate")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.tertiaryText)

            ForEach(Array(zip(CalibrationManager.testRates, calibrationManager.rsaResults).enumerated()), id: \.offset) { index, pair in
                let (rate, rsa) = pair
                let maxRSA = calibrationManager.rsaResults.max() ?? 1.0
                let isWinner = rsa == maxRSA
                HStack(spacing: 12) {
                    Text(String(format: "%.1f", rate))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 35, alignment: .trailing)

                    GeometryReader { proxy in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isWinner ? AppTheme.accent : AppTheme.tint.opacity(0.5))
                            .frame(width: max(4, proxy.size.width * (rsa / max(maxRSA, 0.01))))
                    }
                    .frame(height: 20)

                    Text(String(format: "%.1f", rsa))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 40, alignment: .leading)
                }
            }
        }
        .padding(16)
        .mindfulCard()
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private func progressDots(currentIndex: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<CalibrationManager.testRates.count, id: \.self) { i in
                Circle()
                    .fill(i <= currentIndex ? AppTheme.accent : AppTheme.cardStroke)
                    .frame(width: 10, height: 10)
            }
        }
    }

    private var cancelButton: some View {
        Button(action: { calibrationManager.cancel(); dismiss() }) {
            Text("Cancel")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.bottom, 24)
    }

    private func saveCalibration(rate: Double) {
        if let settings = allSettings.first {
            settings.calibratedResonanceRate = rate
            settings.calibrationDate = .now
            try? modelContext.save()
        }
        dismiss()
    }
}
