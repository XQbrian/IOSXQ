import SwiftUI

// MARK: - Enterprise Workspace Creation Wizard (s-ent-create-1/2/3/success)
// Triggered from WelcomeView's "Create Enterprise Workspace" button.

struct EnterpriseCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1

    // Step 1
    @State private var companyName = ""
    @State private var workEmail   = ""
    @State private var country     = ""
    @State private var industry    = ""

    // Step 2
    @State private var workspaceName  = ""
    @State private var dataRegion     = ""
    @State private var cloudProvider  = "aws"

    // Step 3
    @State private var firstName       = ""
    @State private var lastName        = ""
    @State private var password        = ""
    @State private var confirmPassword = ""

    private let brandGrad = LinearGradient(
        colors: [Color(red: 0.239, green: 0.353, blue: 0.996),
                 Color(red: 0.412, green: 0.471, blue: 0.973)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    private let brand = Color(red: 0.239, green: 0.353, blue: 0.996)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if step == 4 {
                successScreen
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .center, spacing: 0) {
                            stepIconView.padding(.top, 32).padding(.bottom, 20)
                            Text(titleText)
                                .font(.system(size: 24, weight: .heavy))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .kerning(-0.5)
                                .padding(.bottom, 6)
                            Text(subtitleText)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                                .padding(.bottom, 6)
                            progressBar.padding(.bottom, 28)
                            stepFields.padding(.bottom, 24)
                            continueButton.padding(.bottom, 12)
                        }
                        .padding(.horizontal, 28)
                    }
                    backButton
                }
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
    }

    // MARK: Icon

    private var stepIconView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17)
                .fill(brandGrad)
                .frame(width: 64, height: 64)
                .shadow(color: brand.opacity(0.4), radius: 32, x: 0, y: 8)
            Text(step == 1 ? "🏢" : step == 2 ? "⚙️" : "🔑")
                .font(.system(size: 32))
        }
    }

    private var titleText: String {
        switch step {
        case 1: return "Create Enterprise Workspace"
        case 2: return "Workspace Configuration"
        default: return "Administrator Setup"
        }
    }

    private var subtitleText: String {
        switch step {
        case 1: return "Step 1 of 3 — Organization Information"
        case 2: return "Step 2 of 3 — Data & Infrastructure"
        default: return "Step 3 of 3 — Secure your admin account"
        }
    }

    private var progressBar: some View {
        let fraction: CGFloat = step == 1 ? 1/3 : step == 2 ? 2/3 : 1.0
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 3)
                RoundedRectangle(cornerRadius: 3).fill(brand)
                    .frame(width: geo.size.width * fraction, height: 3)
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder
    private var stepFields: some View {
        switch step {
        case 1: step1Fields
        case 2: step2Fields
        default: step3Fields
        }
    }

    // MARK: Step 1

    private var step1Fields: some View {
        VStack(spacing: 12) {
            darkField("Company Name", text: $companyName)
            darkField("Work Email",   text: $workEmail, keyboard: .emailAddress)
            darkPicker("Country",  selected: $country,
                       options: ["United States","United Kingdom","Canada","Australia",
                                 "Germany","France","Japan","Other"])
            darkPicker("Industry", selected: $industry,
                       options: ["Healthcare","Finance & Banking","Legal","Government",
                                 "Technology","Defense","Education","Other"])
        }
    }

    // MARK: Step 2

    private var step2Fields: some View {
        VStack(spacing: 12) {
            darkField("Workspace Name", text: $workspaceName)
            darkPicker("Data Residency Region", selected: $dataRegion,
                       options: ["US East (Virginia)","US West (Oregon)",
                                 "EU West (Ireland)","EU Central (Frankfurt)",
                                 "APAC (Singapore)","APAC (Tokyo)","Canada (Montreal)"])

            VStack(alignment: .leading, spacing: 10) {
                Text("CLOUD PROVIDER")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(0.4)

                ForEach([("aws","AWS","Amazon Web Services"),
                         ("azure","Azure","Microsoft Azure"),
                         ("gcp","Google Cloud","GCP"),
                         ("self","Self Hosted","On-premises")],
                        id: \.0) { id, label, sub in
                    Button { cloudProvider = id } label: {
                        HStack(spacing: 12) {
                            Image(systemName: cloudProvider == id
                                  ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 17))
                                .foregroundColor(brand)
                            Text(label)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(sub)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                        .background(Color(red: 0.110, green: 0.110, blue: 0.118))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(cloudProvider == id ? brand.opacity(0.4) : Color.clear,
                                    lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Step 3

    private var step3Fields: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                darkField("First Name", text: $firstName)
                darkField("Last Name",  text: $lastName)
            }
            darkSecureField("Password",         text: $password)
            darkSecureField("Confirm Password", text: $confirmPassword)
            Text("Password must be at least 12 characters, include uppercase, lowercase, number, and symbol. Keys are stored only in your device's Secure Enclave.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
                .lineSpacing(2)
                .padding(12)
                .background(Color(red: 0.110, green: 0.110, blue: 0.118))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: Action Buttons

    private var continueButton: some View {
        Button { if step < 3 { step += 1 } else { step = 4 } } label: {
            Text(step == 3 ? "Create Workspace" : "Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(brandGrad)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var backButton: some View {
        Button { if step > 1 { step -= 1 } else { dismiss() } } label: {
            Text("← Back")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 44)
    }

    // MARK: Success Screen

    private var successScreen: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.204, green: 0.780, blue: 0.349),
                                 Color(red: 0, green: 0.706, blue: 0.302)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 72, height: 72)
                    .shadow(color: Color(red: 0.204, green: 0.780, blue: 0.349).opacity(0.35),
                            radius: 32, x: 0, y: 8)
                Text("✓")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 24)

            Text("Workspace Created")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
                .kerning(-0.5)
                .padding(.bottom, 10)

            Text("Your Enterprise Workspace has been created. Keys are bound to this device and encrypted at rest.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

            VStack(spacing: 10) {
                Button { dismiss() } label: {
                    Text("Go To Workspace")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(brandGrad)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Button { dismiss() } label: {
                    Text("Invite Team Members")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.25), lineWidth: 1.5))
                }
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    // MARK: - Field Helpers

    private func darkField(_ placeholder: String, text: Binding<String>,
                            keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .font(.system(size: 15))
            .foregroundColor(.white)
            .tint(.white)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color(red: 0.110, green: 0.110, blue: 0.118))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.220, green: 0.220, blue: 0.229), lineWidth: 1))
    }

    private func darkSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .font(.system(size: 15))
            .foregroundColor(.white)
            .tint(.white)
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color(red: 0.110, green: 0.110, blue: 0.118))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.220, green: 0.220, blue: 0.229), lineWidth: 1))
    }

    private func darkPicker(_ placeholder: String, selected: Binding<String>,
                             options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button(opt) { selected.wrappedValue = opt }
            }
        } label: {
            HStack {
                Text(selected.wrappedValue.isEmpty ? placeholder : selected.wrappedValue)
                    .font(.system(size: 15))
                    .foregroundColor(selected.wrappedValue.isEmpty ? .white.opacity(0.35) : .white)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(Color(red: 0.110, green: 0.110, blue: 0.118))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.220, green: 0.220, blue: 0.229), lineWidth: 1))
        }
    }
}

#Preview {
    NavigationStack {
        EnterpriseCreateView()
    }
}
