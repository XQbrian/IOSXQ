import SwiftUI
import XQCore

struct EnterpriseLoginView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var isAuthenticating = false
    @State private var errorMessage: String? = nil

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                RoundedRectangle(cornerRadius: 22)
                    .fill(brandBlue)
                    .frame(width: 88, height: 88)
                    .overlay(
                        Image(systemName: "lock.shield.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.white)
                            .padding(18)
                    )
                    .shadow(color: brandBlue.opacity(0.35), radius: 16, x: 0, y: 8)
                    .padding(.bottom, 28)

                Text("XQ Secure Workspaces")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.bottom, 8)

                Text("Sign in with your corporate account\nto access your encrypted workspace.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 48)

                Button {
                    Task { await signInWithMicrosoft() }
                } label: {
                    HStack(spacing: 12) {
                        MicrosoftLogoShape()
                            .frame(width: 20, height: 20)
                        Text(isAuthenticating ? "Signing in…" : "Continue with Microsoft")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isAuthenticating ? Color.gray : brandBlue)
                    )
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 32)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                        .transition(.opacity)
                }

                Spacer()
                Spacer()

                Text("End-to-end encrypted · Zero-trust · HIPAA compliant")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary.opacity(0.7))
                    .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
    }

    // MARK: - Auth

    private func signInWithMicrosoft() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        errorMessage = nil
        defer { isAuthenticating = false }

        guard let vc = topViewController() else {
            errorMessage = "Unable to present sign-in. Please restart the app."
            return
        }

        do {
            let msalResult = try await coordinator.authOrchestrator.initiateEnterpriseLogin(from: vc)
            try await coordinator.authOrchestrator.sendXQVerificationCode(email: msalResult.email)
            coordinator.navigate(to: .xqVerification(
                email: msalResult.email,
                idToken: msalResult.idToken,
                msalAccountIdentifier: msalResult.accountIdentifier,
                graphToken: msalResult.graphAccessToken
            ))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

// MARK: - Microsoft four-colour logo

private struct MicrosoftLogoShape: View {
    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                Rectangle().fill(Color(red: 0.941, green: 0.341, blue: 0.133))
                Rectangle().fill(Color(red: 0.122, green: 0.467, blue: 0.706))
            }
            GridRow {
                Rectangle().fill(Color(red: 0.522, green: 0.706, blue: 0.000))
                Rectangle().fill(Color(red: 1.000, green: 0.733, blue: 0.020))
            }
        }
    }
}
