import SwiftUI
import PhotosUI

struct OnboardingView: View {
    @Environment(AccountStore.self) private var accountStore

    @State private var name         = ""
    @State private var ageText      = ""
    @State private var profession   = ""
    @State private var locale       = ""
    @State private var idNumber     = ""
    @State private var isSuperuser  = false
    @State private var agreedToTerms = false
    @State private var busy         = false
    @State private var error: String?
    @State private var nameTapCount = 0

    // Photo state
    @State private var selectedProfileItem: PhotosPickerItem?
    @State private var profileUIImage: UIImage?
    @State private var idDocumentSelected = false
    @State private var selectedIdItem: PhotosPickerItem?

    private var superuserUnlocked: Bool { nameTapCount >= 10 }

    private var validAge: Int? {
        guard let n = Int(ageText), (13...120).contains(n) else { return nil }
        return n
    }

    private var canCreate: Bool {
        !name.trimmed.isEmpty && validAge != nil && !idNumber.trimmed.isEmpty && agreedToTerms && !busy
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    formCard
                }
            }
        }
        .animation(.easeInOut, value: superuserUnlocked)
        .onChange(of: selectedProfileItem) { _, item in
            Task { await loadProfilePhoto(from: item) }
        }
        .onChange(of: selectedIdItem) { _, item in
            if item != nil { idDocumentSelected = true }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 72))
                .foregroundStyle(.white)
            Text("Blackout")
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(.white)
            Text("Viral Trust Network")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.bottom, 40)
    }

    // MARK: - Form card

    private var formCard: some View {
        VStack(spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Create Account")
                    .font(.title2.bold())
                    .foregroundStyle(Color.appOnSurface)
                Text("Verify your identity to join the trust network.")
                    .font(.subheadline)
                    .foregroundStyle(Color.appOnSurfaceVariant)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            personalInfoSection
            authDocumentsSection

            if superuserUnlocked { superuserToggle }

            termsRow

            if let error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Color.appError)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            ctaButton
            Spacer(minLength: 32)
        }
        .padding(24)
        .background(Color.appBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Personal Information section

    private var personalInfoSection: some View {
        formSection(icon: "person", title: "Personal Information") {
            formField(label: "Full Name", placeholder: "e.g., Jane Sterling") {
                TextField("", text: $name)
                    .textContentType(.name)
                    .simultaneousGesture(TapGesture().onEnded { nameTapCount += 1 })
            }
            formField(label: "Age", placeholder: "13–120") {
                TextField("", text: $ageText).keyboardType(.numberPad)
            }
            formField(label: "Profession", placeholder: "Optional — e.g., Doctor") {
                TextField("", text: $profession).autocorrectionDisabled()
            }
            formField(label: "City / Region", placeholder: "e.g., London") {
                TextField("", text: $locale).autocorrectionDisabled()
            }
        }
    }

    // MARK: - Authentication Documents section

    private var authDocumentsSection: some View {
        formSection(icon: "lock.shield", title: "Authentication Documents") {
            // Government ID gate
            formField(label: "Government ID Number", placeholder: "Not stored — identity gate only") {
                TextField("", text: $idNumber)
                    .autocorrectionDisabled()
                    .textContentType(.none)
            }

            // Photo + ID upload row
            HStack(spacing: 12) {
                // Profile photo upload
                PhotosPicker(selection: $selectedProfileItem, matching: .images) {
                    VStack(spacing: 8) {
                        ZStack {
                            if let img = profileUIImage {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 88)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.appSurfaceLow)
                                    .frame(width: 72, height: 88)
                                    .overlay(
                                        Image(systemName: "person.crop.rectangle")
                                            .font(.system(size: 26))
                                            .foregroundStyle(Color.appSurfaceDim)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.appOutlineVariant, lineWidth: 1.5)
                                    )
                            }
                            if profileUIImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                    .padding(4)
                            }
                        }
                        Text("Profile Photo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.black)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // ID document upload
                PhotosPicker(selection: $selectedIdItem, matching: .images) {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(idDocumentSelected ? Color.appSurfaceLow : Color.appSurfaceLow)
                                .frame(maxWidth: .infinity)
                                .frame(height: 88)
                                .overlay(
                                    Group {
                                        if idDocumentSelected {
                                            Image(systemName: "checkmark.shield.fill")
                                                .font(.system(size: 28))
                                                .foregroundStyle(.green)
                                        } else {
                                            Image(systemName: "person.text.rectangle")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Color.appSurfaceDim)
                                        }
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(idDocumentSelected
                                                ? Color.green.opacity(0.5)
                                                : Color.appOutlineVariant,
                                                lineWidth: 1.5)
                                )
                        }
                        Text("ID Document")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.black)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            Text("Passport, Driver's Licence, or National ID")
                .font(.caption)
                .foregroundStyle(Color.appOnSurfaceVariant)
        }
    }

    // MARK: - Superuser Easter egg

    private var superuserToggle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isSuperuser) {
                Label("Superuser", systemImage: "star.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appOnSurface)
            }
            .tint(.black)
            Text("Superusers start with maximum trust and can found organisations.")
                .font(.caption)
                .foregroundStyle(Color.appOnSurfaceVariant)
        }
        .padding(16)
        .background(Color.appSurfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Terms

    private var termsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $agreedToTerms).labelsHidden().tint(.black)
            Text("I acknowledge the Blackout **Terms of Use** and agree to the identity attestation requirements for network access.")
                .font(.subheadline)
                .foregroundStyle(Color.appOnSurfaceVariant)
        }
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: create) {
            HStack(spacing: 10) {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Text("Create Account").font(.headline)
                    Spacer()
                    Image(systemName: "arrow.right").font(.headline)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(canCreate ? Color.black : Color.appOutline)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!canCreate)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formSection<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                    .foregroundStyle(Color.appOnSurfaceVariant)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Color.appOnSurfaceVariant)
            }
            VStack(spacing: 10) { content() }
        }
    }

    @ViewBuilder
    private func formField<F: View>(
        label: String,
        placeholder: String,
        @ViewBuilder field: () -> F
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.subheadline).foregroundStyle(Color.appOnSurfaceVariant)
            field()
                .textFieldStyle(.plain)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.appSurfaceDim, lineWidth: 1))
        }
    }

    // MARK: - Photo loading

    private func loadProfilePhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let img  = UIImage(data: data) {
            profileUIImage = resized(img, maxDimension: 400)
        }
    }

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size  = image.size
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        if ratio >= 1 { return image }
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Create

    private func create() {
        error = nil
        busy  = true
        Task {
            defer { busy = false }
            let photoB64 = profileUIImage?
                .jpegData(compressionQuality: 0.75)?
                .base64EncodedString()
            do {
                _ = try await accountStore.createAccount(
                    name:               name.trimmed,
                    age:                validAge ?? 0,
                    profession:         profession.trimmed,
                    locale:             locale.trimmed,
                    isSuperuser:        isSuperuser,
                    profilePhotoBase64: photoB64
                )
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
