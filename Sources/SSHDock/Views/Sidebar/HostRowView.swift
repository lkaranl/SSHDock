import SwiftUI

public struct HostRowView: View {
    public let host: Host
    public let activeSession: SSHSession?
    public let activeSessionsCount: Int
    public let onConnect: () -> Void
    public let onNewTab: () -> Void
    public let onEdit: () -> Void
    public let onDelete: () -> Void
    
    @State private var isHovered: Bool = false
    
    public init(
        host: Host,
        activeSession: SSHSession? = nil,
        activeSessionsCount: Int = 0,
        onConnect: @escaping () -> Void,
        onNewTab: @escaping () -> Void = {},
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.host = host
        self.activeSession = activeSession
        self.activeSessionsCount = activeSessionsCount
        self.onConnect = onConnect
        self.onNewTab = onNewTab
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Ícone do Host (SF Symbol de acordo com Auth Method)
            Image(systemName: host.authMethod == .password ? "lock.fill" : "key.fill")
                .foregroundColor(activeSession != nil ? .accentColor : .secondary)
                .font(.system(size: 13))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(host.connectionString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if activeSessionsCount > 1 {
                Text("\(activeSessionsCount) abas")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            } else if let session = activeSession {
                StatusBadge(state: session.state)
            } else if isHovered {
                HStack(spacing: 6) {
                    Button(action: onConnect) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("Conectar SSH")
                    
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Editar Host")
                    
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Excluir Host")
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onConnect) {
                Label("Conectar Sessão", systemImage: "terminal")
            }
            Button(action: onNewTab) {
                Label("Abrir Nova Aba (⌘ T)", systemImage: "plus.rectangle.on.rectangle")
            }
            Divider()
            Button(action: onEdit) {
                Label("Editar Host", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Excluir Host", systemImage: "trash")
            }
        }
    }
}
