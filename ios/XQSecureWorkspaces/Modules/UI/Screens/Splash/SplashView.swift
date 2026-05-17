import SwiftUI

struct SplashView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject var vm = SplashViewModel()

    private let brandBlue = Color(red: 61/255, green: 90/255, blue: 254/255)

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            RoundedRectangle(cornerRadius: 20)
                .fill(brandBlue)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "lock.shield.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .padding(16)
                )

            Text("XQ Secure")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)

            ProgressView(value: vm.progress)
                .progressViewStyle(.linear)
                .tint(brandBlue)
                .padding(.horizontal, 48)
                .animation(.easeInOut, value: vm.progress)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(vm.checks) { check in
                    HStack(spacing: 8) {
                        Image(systemName: check.passed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(check.passed ? .green : .secondary)
                        Text(check.label)
                            .font(.subheadline)
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: vm.checks.count)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)

            Spacer()
        }
        .task {
            await vm.performSecurityChecks()
        }
        .onChange(of: vm.isReady) { _, ready in
            if ready {
                coordinator.navigate(to: .welcome)
            }
        }
    }
}
