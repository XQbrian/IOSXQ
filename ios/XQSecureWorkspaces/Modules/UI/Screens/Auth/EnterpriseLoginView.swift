import SwiftUI
import XQCore

struct EnterpriseLoginView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    @State private var workEmail = ""
    @State private var detectedIDP: DetectedIDP? = nil
    @State private var isAuthenticating = false
    @State private var errorMessage: String? = nil

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)
    private let brandGradient = LinearGradient(
        colors: [Color(red: 0.239, green: 0.353, blue: 0.996),
                 Color(red: 0.412, green: 0.471, blue: 0.973)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 17)
                        .fill(brandGradient)
                        .frame(width: 64, height: 64)
                    Image(systemName: "building.2.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .padding(13)
                        .frame(width: 64, height: 64)
                }
                .shadow(color: brandBlue.opacity(0.4), radius: 32, x: 0, y: 8)
                .padding(.bottom, 20)

                Text("Enterprise Sign-In")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(.white)
                    .kerning(-0.5)
                    .padding(.bottom, 8)

                Text("Enter your work email to auto-detect\nyour identity provider.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)

                // Email input
                TextField("work@yourcompany.com", text: $workEmail)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(brandBlue)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 13)
                    .background(Color(white: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                        detectedIDP != nil ? brandBlue.opacity(0.6) : Color(white: 0.22),
                        lineWidth: 1))
                    .padding(.horizontal, 28)
                    .onChange(of: workEmail) { _, new in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            detectedIDP = DetectedIDP(email: new)
                        }
                    }

                // IDP badge (appears when domain is recognized)
                if let idp = detectedIDP {
                    HStack(spacing: 11) {
                        Text(idp.icon)
                            .font(.system(size: 26))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idp.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("Detected via domain MX record")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                        Text("AUTO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(brandBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(brandBlue.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    .padding(13)
                    .background(Color(white: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.22), lineWidth: 1))
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer().frame(height: 24)

                // SSO button
                Button {
                    Task { await signInWithSSO() }
                } label: {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Continue with SSO")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canContinue ? AnyView(brandGradient) : AnyView(brandGradient.opacity(0.35)))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canContinue || isAuthenticating)
                .padding(.horizontal, 28)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                #if targetEnvironment(simulator)
                Button("Dev Login (Simulator)") {
                    coordinator.devLogin()
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
                #endif

                Spacer()
                Spacer()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
        .navigationTitle("")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Auth

    private var canContinue: Bool {
        workEmail.contains("@") && workEmail.split(separator: "@").last.map { $0.contains(".") } == true
    }

    private func signInWithSSO() async {
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

// MARK: - IDP Detection

private struct DetectedIDP: Equatable {
    let name: String
    let icon: String

    init?(email: String) {
        guard email.contains("@"),
              let domain = email.split(separator: "@").last.map(String.init),
              domain.contains(".") else { return nil }

        let d = domain.lowercased()
        if d == "outlook.com" || d == "hotmail.com" || d == "live.com" || d.hasSuffix(".microsoft.com") {
            name = "Microsoft Entra ID"; icon = "🔷"
        } else if d == "gmail.com" || d.hasSuffix(".google.com") || d.hasSuffix(".googlemail.com") {
            name = "Google Workspace"; icon = "🟢"
        } else if d.hasSuffix(".okta.com") {
            name = "Okta"; icon = "🔐"
        } else if domain.split(separator: ".").count >= 2 {
            // Generic corporate domain — default to Microsoft Entra (most common enterprise IDP)
            name = "Microsoft Entra ID"; icon = "🔷"
        } else {
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        EnterpriseLoginView()
            .environmentObject(AppCoordinator())
    }
}
