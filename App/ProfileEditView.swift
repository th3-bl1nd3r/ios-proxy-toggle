import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject var store: ProfileStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ProxyProfile
    @State private var portText: String

    init(profile: ProxyProfile) {
        _draft = State(initialValue: profile)
        _portText = State(initialValue: String(profile.port))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Proxy") {
                    TextField("Name (optional)", text: $draft.name)
                    TextField("Host (e.g. 192.168.1.10)", text: $draft.host)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $portText)
                        .keyboardType(.numberPad)
                        .onChange(of: portText) { new in
                            draft.port = Int(new.filter(\.isNumber)) ?? 0
                        }
                }

                Section {
                    Toggle("Requires authentication", isOn: $draft.requiresAuth)
                    if draft.requiresAuth {
                        TextField("Username", text: $draft.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $draft.password)
                    }
                }

                Text("HTTP and HTTPS traffic will use this proxy while the toggle is on.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(store.profiles.contains(where: { $0.id == draft.id }) ? "Edit Proxy" : "Add Proxy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.upsert(draft); dismiss() }
                        .disabled(!draft.isValid)
                }
            }
        }
    }
}
