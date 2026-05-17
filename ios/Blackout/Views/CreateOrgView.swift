import SwiftUI

struct CreateOrgView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(OrgStore.self) private var orgStore
    let founder: Account

    @State private var orgName = ""
    @State private var busy    = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Organisation name", text: $orgName)
                        .autocorrectionDisabled()
                } footer: {
                    Text("You will be the founder with unlimited invite depth.")
                }

                Section {
                    Button(action: create) {
                        if busy {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Found organisation").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(orgName.trimmingCharacters(in: .whitespaces).isEmpty || busy)
                }

                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Create Organisation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create() {
        busy = true; error = nil
        Task {
            defer { busy = false }
            do {
                try await orgStore.foundOrganization(
                    founder: founder,
                    name: orgName.trimmingCharacters(in: .whitespaces)
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
