import SwiftUI
import XQCore

struct XQVerificationView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    let email: String
    let idToken: String
    let msalAccountIdentifier: String

    @State private var pin = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var errorMessage: String? = nil
    @State private var resendCooldown = 0
    @FocusState private var pinFocused: Bool

    private let brandBlue = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(brandBlue)
                    .padding(.bottom, 28)

                Text("Check your email")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.bottom, 8)

                Text("We sent a verification code to\n**\(email)**")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                TextField("Enter code", text: $pin)
                    .keyboardType(.numberPad)
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 18)
                    .padding(.horizontal, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(pinFocused ? brandBlue.opacity(0.6) : Color.clear, lineWidth: 1.5)
                            )
                    )
                    .focused($pinFocused)
                    .padding(.horizontal, 48)
                    .onChange(of: pin) { _, newValue in
                        let digits = newValue.filter { $0.isNumber }
                        if digits != newValue { pin = digits }
                        if digits.count == 6 { Task { await verify() } }
                    }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 12)
                        .transition(.opacity)
                }

                Button {
                    Task { await verify() }
                } label: {
                    Group {
                        if isVerifying {
                            ProgressView().tint(.white)
                        } else {
                            Text("Verify")
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(canVerify ? brandBlue : Color.gray)
                    )
                }
                .disabled(!canVerify || isVerifying)
                .padding(.horizontal, 32)
                .padding(.top, 24)

                Button {
                    Task { await resend() }
                } label: {
                    if isResending {
                        ProgressView().scaleEffect(0.8)
                    } else if resendCooldown > 0 {
                        Text("Resend in \(resendCooldown)s").foregroundStyle(.secondary)
                    } else {
                        Text("Resend code").foregroundStyle(brandBlue)
                    }
                }
                .font(.system(size: 14))
                .disabled(isResending || resendCooldown > 0)
                .padding(.top, 16)

                Spacer()
                Spacer()

                Button("Use a different account") {
                    coordinator.navigate(to: .welcome)
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
        .onAppear { pinFocused = true }
    }

    private var canVerify: Bool { pin.count >= 6 }

    private func verify() async {
        guard canVerify, !isVerifying else { return }
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }

        do {
            let session = try await coordinator.authOrchestrator.verifyAndCreateSession(
                email: email,
                pin: pin,
                msalAccountIdentifier: msalAccountIdentifier
            )
            coordinator.completeAuthentication(session: session)
        } catch {
            errorMessage = "Invalid code. Check your email and try again."
            pin = ""
        }
    }

    private func resend() async {
        guard !isResending else { return }
        isResending = true
        defer { isResending = false }

        do {
            try await coordinator.authOrchestrator.sendXQVerificationCode(email: email)
            resendCooldown = 30
            Task {
                while resendCooldown > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    resendCooldown -= 1
                }
            }
        } catch {
            errorMessage = "Failed to resend. Please try again."
        }
    }
}
