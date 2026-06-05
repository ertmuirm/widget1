import SwiftUI
import NetworkExtension

struct ServerSettingsView: View {
    @State private var ssid: String = SharedStorage.shared.allowedSSID
    @State private var port: String = "\(SharedStorage.shared.serverPort)"
    @State private var currentSSID: String = ""
    @State private var isRunning = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Current Wi-Fi")
                    Spacer()
                    Text(currentSSID.isEmpty ? "Not connected" : currentSSID)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("Wi-Fi Network Name (SSID)", text: $ssid)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text("Allowed Network")
            } footer: {
                Text("The server only runs when connected to this Wi-Fi network. Leave empty to disable the server entirely.")
                    .font(.caption)
            }

            Section {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("8080", text: $port)
                        .foregroundStyle(.white)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            } header: {
                Text("Server Port")
            } footer: {
                Text("Send HTTP GET to http://<phone-ip>:\(port)/execute-widget-action?id=COMMAND_ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Circle()
                        .fill(isRunning ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(isRunning ? "Server running" : "Server stopped")
                        .foregroundStyle(.secondary)
                }

                Button("Save & Restart") {
                    save()
                }
                .foregroundStyle(.white)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Local Server")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            fetchCurrentSSID()
            isRunning = LocalActionServer.shared.isRunning
        }
    }

    private func fetchCurrentSSID() {
        NEHotspotNetwork.fetchCurrent { network in
            DispatchQueue.main.async {
                currentSSID = network?.ssid ?? ""
            }
        }
    }

    private func save() {
        SharedStorage.shared.allowedSSID = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if let p = Int(port), p > 0, p < 65536 {
            SharedStorage.shared.serverPort = p
        }
        LocalActionServer.shared.stop()
        LocalActionServer.shared.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isRunning = LocalActionServer.shared.isRunning
        }
    }
}
