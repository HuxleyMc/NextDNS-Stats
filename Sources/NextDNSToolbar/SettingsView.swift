import SwiftUI
import NextDNSToolbarCore

struct SettingsView: View {
    @ObservedObject var store: DashboardStore
    @Binding var isPresented: Bool
    @State private var apiKey = ""
    @State private var isSaving = false

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("NextDNS Account").font(.title2.bold())
                Text("Your API key is stored only in macOS Keychain. Saving a new key replaces the current account.")
                    .foregroundStyle(.secondary)
                SecureField("API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                if let error = store.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
                HStack {
                    if store.isAuthenticated {
                        Label("API connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                    Spacer()
                    Button("Cancel") { isPresented = false }
                    Button("Save") {
                        isSaving = true
                        Task {
                            await store.saveAPIKey(apiKey)
                            isSaving = false
                            if store.isAuthenticated { isPresented = false }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                }
            }
            .padding(24)
            .glassPanel(cornerRadius: 20, tint: .blue.opacity(0.08))
            .padding(16)
        }
        .frame(width: 420)
    }
}
