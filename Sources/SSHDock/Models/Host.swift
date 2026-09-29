import Foundation

public enum AuthenticationMethod: Codable, Hashable, Equatable {
    case password
    case sshKey(keyPath: String)
    /// Autenticação delegada ao ssh-agent (ssh-add, 1Password, Secretive etc.)
    case agent(agentSocket: String?)
    
    public var title: String {
        switch self {
        case .password:
            return "Senha"
        case .sshKey:
            return "Chave SSH"
        case .agent:
            return "Agente SSH"
        }
    }
    
    /// Ícone SF Symbol representando o método de autenticação
    public var iconName: String {
        switch self {
        case .password:
            return "lock.fill"
        case .sshKey:
            return "key.fill"
        case .agent:
            return "person.badge.key.fill"
        }
    }
}

public struct Host: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var hostname: String
    public var port: Int
    public var username: String
    public var authMethod: AuthenticationMethod
    public var groupId: UUID?
    public var keychainAccountKey: String
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        hostname: String,
        port: Int = 22,
        username: String,
        authMethod: AuthenticationMethod = .password,
        groupId: UUID? = nil,
        keychainAccountKey: String = UUID().uuidString,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.groupId = groupId
        self.keychainAccountKey = keychainAccountKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    public var connectionString: String {
        "\(username)@\(hostname):\(port)"
    }
}
