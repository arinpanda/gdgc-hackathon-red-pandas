import SwiftUI

struct SignupView: View {
    // MARK: - State Variables
    @State private var firstName = ""
    @State private var middleName = ""
    @State private var lastName = ""
    @State private var userId = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var hasAgreedToTerms = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // MARK: - Header
                VStack(spacing: 16) {
                    // Mascot Placeholder
                    Image(systemName: "shield.righthalf.filled")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .foregroundColor(ThemeColors.primary)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Create Account")
                            .font(.headlineXL)
                            .foregroundColor(ThemeColors.onSurface)
                        
                        Text("Verify your identity to join the high-assurance grid.")
                            .font(.bodyMD)
                            .foregroundColor(ThemeColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 40)
                }
                
                VStack(spacing: 32) {
                    // MARK: - Section 1: Personal Information
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "person", title: "Personal Information")
                        
                        VStack(spacing: 16) {
                            CustomTextField(label: "First Name", placeholder: "e.g., Jonathan", text: $firstName)
                            CustomTextField(label: "Middle Name", placeholder: "Optional", text: $middleName)
                            CustomTextField(label: "Last Name", placeholder: "e.g., Sterling", text: $lastName)
                        }
                    }
                    
                    // MARK: - Section 2: Security Information
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "lock", title: "Security Information")
                        
                        VStack(spacing: 16) {
                            CustomTextField(label: "User ID", placeholder: "Choose a unique ID", text: $userId)
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Password")
                                    .font(.labelLG)
                                    .foregroundColor(ThemeColors.onSurfaceVariant)
                                
                                ZStack(alignment: .trailing) {
                                    if isPasswordVisible {
                                        TextField("••••••••••••", text: $password)
                                            .font(.bodyLG)
                                            .padding()
                                            .background(ThemeColors.surfaceContainerLowest)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(ThemeColors.surfaceDim, lineWidth: 1)
                                            )
                                    } else {
                                        SecureField("••••••••••••", text: $password)
                                            .font(.bodyLG)
                                            .padding()
                                            .background(ThemeColors.surfaceContainerLowest)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(ThemeColors.surfaceDim, lineWidth: 1)
                                            )
                                    }
                                    
                                    Button(action: { isPasswordVisible.toggle() }) {
                                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                                            .foregroundColor(ThemeColors.onSurfaceVariant)
                                            .padding(.trailing, 16)
                                    }
                                }
                            }
                        }
                    }
                    
                    // MARK: - Section 3: Authentication Documents
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(icon: "checkmark.seal", title: "Authentication Documents")
                        
                        VStack(spacing: 16) {
                            FileUploadBox(
                                icon: "camera.viewfinder",
                                title: "Upload Profile Photo",
                                subtitle: "Clear, front-facing headshot (JPEG, PNG)",
                                isPortrait: true
                            )
                            
                            FileUploadBox(
                                icon: "lanyardcard",
                                title: "ID Document Upload",
                                subtitle: "Passport, Driver's License, or Gov ID",
                                isPortrait: false
                            )
                        }
                    }
                    
                    // MARK: - Terms & Conditions
                    HStack(alignment: .top, spacing: 12) {
                        Button(action: { hasAgreedToTerms.toggle() }) {
                            Image(systemName: hasAgreedToTerms ? "checkmark.square.fill" : "square")
                                .foregroundColor(hasAgreedToTerms ? ThemeColors.primary : ThemeColors.surfaceDim)
                                .font(.system(size: 20))
                                .padding(.top, 2)
                        }
                        
                        Text("I acknowledge the AuthO ")
                            .font(.bodyMD)
                            .foregroundColor(ThemeColors.onSurfaceVariant)
                        + Text("Terms of Use")
                            .font(.bodyMD)
                            .underline()
                            .fontWeight(.medium)
                            .foregroundColor(ThemeColors.primary)
                        + Text(" and agree to formal identity attestation requirements for institutional access.")
                            .font(.bodyMD)
                            .foregroundColor(ThemeColors.onSurfaceVariant)
                    }
                    
                    // MARK: - CTA
                    VStack(spacing: 24) {
                        Button(action: {
                            // Handle create account action
                        }) {
                            HStack(spacing: 16) {
                                Text("Create Account")
                                    .font(.buttonText)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 24, weight: .bold))
                            }
                            .foregroundColor(ThemeColors.onPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(ThemeColors.primary)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Already have credentials?")
                                .font(.bodyMD)
                                .foregroundColor(ThemeColors.onSurfaceVariant)
                            
                            Button(action: {
                                // Handle sign in navigation
                            }) {
                                Text("Sign In")
                                    .font(.bodyMD)
                                    .fontWeight(.bold)
                                    .foregroundColor(ThemeColors.primary)
                            }
                        }
                    }
                    .padding(.bottom, 48)
                }
            }
            .padding(.horizontal, 24)
        }
        .background(ThemeColors.background.ignoresSafeArea())
    }
}

// MARK: - Reusable Components
struct SectionHeader: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(ThemeColors.secondary)
            
            Text(title.uppercased())
                .font(.labelLG)
                .fontWeight(.bold)
                .tracking(2.0)
                .foregroundColor(ThemeColors.secondary)
        }
    }
}

struct CustomTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.labelLG)
                .foregroundColor(ThemeColors.onSurfaceVariant)
            
            TextField(placeholder, text: $text)
                .font(.bodyLG)
                .padding()
                .background(ThemeColors.surfaceContainerLowest)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ThemeColors.surfaceDim, lineWidth: 1)
                )
        }
    }
}

struct FileUploadBox: View {
    let icon: String
    let title: String
    let subtitle: String
    let isPortrait: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(ThemeColors.surfaceContainerLowest)
                    .border(ThemeColors.primary, width: 2)
                    .frame(width: isPortrait ? 112 : .infinity, height: isPortrait ? 128 : (UIScreen.main.bounds.width - 96) * (9/16))
                
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(ThemeColors.surfaceDim)
            }
            
            VStack(spacing: 4) {
                Text(title)
                    .font(.labelLG)
                    .fontWeight(.bold)
                    .foregroundColor(ThemeColors.primary)
                
                Text(subtitle)
                    .font(.bodyMD)
                    .foregroundColor(ThemeColors.onSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(ThemeColors.surfaceContainerLow)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(ThemeColors.surfaceDim)
        )
    }
}

// MARK: - Previews
struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView()
    }
}
