import SwiftUI

struct MenuBarLabelView: View {
    let pendingCount: Int
    let isScanning: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image("MenuBarIcon")
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
            if pendingCount > 0 {
                Text("\(pendingCount)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            if isScanning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.65)
            }
        }
        .padding(.horizontal, 2)
    }
}