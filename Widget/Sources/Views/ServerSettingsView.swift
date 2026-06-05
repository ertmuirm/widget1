import SwiftUI
import NetworkExtension

struct ServerSettingsView: View {
    @State private var ssid: String = SharedStorage.shared.allowedSSID
    @State private var portText: String = String(SharedStorage.shared.serverPort)
    @State private var currentSSID: String = "Loading..."
    @State private var isRunning: Bool = false

    private var effectivePort: String { portText.isEmpty ? "8080" : portText }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Current Wi-Fi SSID")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentSSID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Allowed SSID")
                    Spacer()
                    TextField("Any network", text: $ssid)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                HStack {
                    Text("Listen Port")
                    Spacer()
                    TextField("8080", text: $portText)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.white)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }
            } header: {
                Text("Configuration")
            } footer: {
                Text("Leave Allowed SSID blank to accept connections from any Wi-Fi. If the SSID entitlement is unavailable, the check is skipped and all connections are allowed.")
                    .font(.caption2)
            }

            Section {
                HStack {
                    Text("Endpoint")
                    Spacer()
                    Text("GET /execute-widget-action?id=CMD")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isRunning ? "Running" : "Stopped")
                        .foregroundStyle(isRunning ? .green : .red)
                }

                Button("Save & Restart") {
                    saveAndRestart()
                }
                .foregroundStyle(.blue)
            } header: {
                Text("Server")
            } footer: {
                Text("Replace <iPhone-IP> with the device IP from Settings → Wi-Fi. Example: http://<iPhone-IP>:\(effectivePort)/execute-widget-action?id=YOUR_COMMAND")
                    .font(.caption2)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Local Server")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .onAppear {
            isRunning = LocalActionServer.shared.isRunning
            NEHotspotNetwork.fetchCurrent { network in
                DispatchQueue.main.async {
                    currentSSID = network?.ssid ?? "Unavailable"
                }
            }
        }
    }

    private func saveAndRestart() {
        SharedStorage.shared.allowedSSID = ssid
        if let port = Int(portText), port > 0, port < 65536 {
            SharedStorage.shared.serverPort = port
        }
        LocalActionServer.shared.restart()
        isRunning = LocalActionServer.shared.isRunning
    }
}

#Preview {
    NavigationStack {
        ServerSettingsView()
    }
    .preferredColorScheme(.dark)
}
