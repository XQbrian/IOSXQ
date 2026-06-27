import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    private let brandGradient = LinearGradient(
        colors: [Color(red: 0.239, green: 0.353, blue: 0.996),
                 Color(red: 0.412, green: 0.471, blue: 0.973)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(brandGradient)
                            .frame(width: 68, height: 68)
                        Image(systemName: "lock.shield.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .padding(14)
                            .frame(width: 68, height: 68)
                    }
                    .shadow(color: brandBlue.opacity(0.4), radius: 32, x: 0, y: 8)
                    .padding(.bottom, 26)

                    Text("Zero Trust. Every File.")
                        .font(.system(size: 27, weight: .heavy))
                        .foregroundStyle(.white)
                        .kerning(-0.5)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)

                    Text("Encryption follows your data across every device, cloud, and collaboration.")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 44)

                    VStack(spacing: 10) {
                        Button {
                            coordinator.startFree()
                        } label: {
                            Text("Start for Free")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(brandGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        NavigationLink {
                            EnterpriseLoginView()
                                .navigationBarBackButtonHidden(false)
                        } label: {
                            Text("Workspace Login")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.3), lineWidth: 1.5)
                                )
                        }

                        NavigationLink {
                            EnterpriseCreateView()
                        } label: {
                            Text("Create Enterprise Workspace")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(.white.opacity(0.15), lineWidth: 1)
                                )
                        }
                        .padding(.top, 2)
                    }
                    .padding(.horizontal, 28)

                    Spacer()
                    Spacer()

                    Text("By continuing you agree to Terms of Service.\nYour keys never leave your device.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.25))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AppCoordinator())
}
