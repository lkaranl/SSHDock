import Foundation

public enum ConnectionState: Equatable, Hashable {
    case disconnected
    case connecting
    case connected
    case failed(String)
    
    public var statusTitle: String {
        switch self {
        case .disconnected:
            return "Desconectado"
        case .connecting:
            return "Conectando..."
        case .connected:
            return "Conectado"
        case .failed(let message):
            return "Erro: \(message)"
        }
    }
    
    public var iconName: String {
        switch self {
        case .disconnected:
            return "circle"
        case .connecting:
            return "arrow.triangle.2.circlepath"
        case .connected:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
}

public struct SSHSession: Identifiable, Hashable {
    public let id: UUID
    public let host: Host
    public var title: String
    public var state: ConnectionState
    public var startedAt: Date
    
    public init(
        id: UUID = UUID(),
        host: Host,
        title: String? = nil,
        state: ConnectionState = .connecting,
        startedAt: Date = Date()
    ) {
        self.id = id
        self.host = host
        self.title = title ?? host.name
        self.state = state
        self.startedAt = startedAt
    }
}
