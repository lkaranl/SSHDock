import SwiftUI

public struct GroupFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel
    
    @State private var name: String = ""
    @State private var iconName: String = "folder.fill"
    @State private var colorHex: String = "#007AFF"
    
    private let iconOptions = [
        "folder.fill", "house.fill", "cloud.fill", "externaldrive.fill",
        "server.rack", "cpu", "network", "lock.shield.fill", "cube.fill"
    ]
    
    private let colorOptions = [
        "#007AFF", "#FF9500", "#34C759", "#AF52DE",
        "#FF3B30", "#5AC8FA", "#FFCC00", "#8E8E93"
    ]
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Novo Grupo / Categoria")
                .font(.headline)
            
            Form {
                TextField("Nome do Grupo", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ícone:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .padding(6)
                                    .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cor de Destaque:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(colorOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    colorHex = hex
                                }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancelar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Salvar Grupo") {
                    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let newGroup = HostGroup(name: name, iconName: iconName, colorHex: colorHex)
                    viewModel.addGroup(newGroup)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

// Extension utilitária para Hex Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8 * 17), (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
