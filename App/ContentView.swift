import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ProfileStore
    @EnvironmentObject var model: AppModel

    @State private var editing: ProxyProfile?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            List {
                Section { toggleCard }

                Section("Profiles") {
                    if store.profiles.isEmpty {
                        Text("No proxies yet. Tap + to add one, or scan your network.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    ForEach(store.profiles) { profile in
                        ProfileRow(profile: profile,
                                   isSelected: store.selectedProfileID == profile.id)
                            .contentShape(Rectangle())
                            .onTapGesture { store.selectedProfileID = profile.id }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { store.delete(profile) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { editing = profile } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(.blue)
                            }
                    }
                    .onDelete { store.delete(at: $0) }
                }

                if let err = model.lastError {
                    Section { Text(err).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle("Proxy Toggle")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showScanner = true } label: { Image(systemName: "wifi") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editing = ProxyProfile() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { profile in
                ProfileEditView(profile: profile)
            }
            .sheet(isPresented: $showScanner) {
                ScannerView { found in
                    store.upsert(found)
                    showScanner = false
                }
            }
            .task { await model.refresh() }
        }
    }

    private var toggleCard: some View {
        VStack(spacing: 16) {
            Image(systemName: model.isOn ? "shield.lefthalf.filled" : "shield.slash")
                .font(.system(size: 52))
                .foregroundStyle(model.isOn ? Color.green : Color.secondary)

            Text(model.statusText).font(.title3.weight(.semibold))

            if let p = store.selectedProfile {
                Text(p.name.isEmpty ? p.subtitle : "\(p.name) · \(p.subtitle)")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Select a profile below").font(.subheadline).foregroundStyle(.secondary)
            }

            Toggle("", isOn: Binding(
                get: { model.isOn },
                set: { _ in Task { await model.toggle() } }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .scaleEffect(1.3)
            .disabled(store.selectedProfile == nil)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct ProfileRow: View {
    let profile: ProxyProfile
    let isSelected: Bool
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name.isEmpty ? profile.host : profile.name)
                    .font(.body.weight(.medium))
                Text(profile.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
            }
        }
    }
}
