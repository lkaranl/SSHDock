import Foundation
import Combine

public class TerminalViewModel: ObservableObject {
    @Published public var session: SSHSession
    @Published public var statusMessage: String = ""
    
    private let keychain = KeychainManager.shared
    
    public init(session: SSHSession) {
        self.session = session
    }
    
    /// Obtém os argumentos de linha de comando para o binário /usr/bin/ssh
    public func buildSSHExecutableAndArguments() -> (executable: String, args: [String]) {
        let host = session.host
        var args: [String] = []
        
        // Porta
        args.append(contentsOf: ["-p", "\(host.port)"])
        
        // Timeouts: se o host estiver inacessível, o ssh encerra rápido (exit 255)
        // em vez de ficar pendurado indefinidamente no TCP connect.
        args.append(contentsOf: ["-o", "ConnectTimeout=10"])
        args.append(contentsOf: ["-o", "ServerAliveInterval=15"])
        args.append(contentsOf: ["-o", "ServerAliveCountMax=3"])
        
        // Aceita novas chaves automaticamente para evitar bloqueio silencioso
        args.append(contentsOf: ["-o", "StrictHostKeyChecking=accept-new"])
        
        // Autenticação por Chave SSH
        if case .sshKey(let keyPath) = host.authMethod, !keyPath.isEmpty {
            let expandedPath = NSString(string: keyPath).expandingTildeInPath
            args.append(contentsOf: ["-i", expandedPath])
        }
        
        // Força alocação de PTY e inicia no Fish Shell executando o fastfetch
        args.append("-t")
        args.append("\(host.username)@\(host.hostname)")
        args.append("command -v fish >/dev/null 2>&1 && exec fish -C \"fastfetch 2>/dev/null || true\" -l || { fastfetch 2>/dev/null || true; exec ${SHELL:-/bin/sh} -l; }")
        
        return ("/usr/bin/ssh", args)
    }
    
    /// Obtém variáveis de ambiente otimizadas com suporte a UTF-8, 256 cores e
    /// autenticação de acordo com o método do host (SSH_ASKPASS ou ssh-agent)
    public func buildEnvironment() -> [String] {
        return Self.buildConnectionEnvironment(for: session.host)
    }

    /// Busca senha/passphrase do Keychain para o host
    public func getSecretFromKeychain() -> String? {
        return keychain.readCredential(for: session.host.keychainAccountKey)
    }
    
    /// Constrói o ambiente de conexão de acordo com o método de autenticação do host:
    /// - Senha/Chave SSH: usa SSH_ASKPASS com o segredo do Keychain
    /// - Agente SSH (ssh-add, 1Password, Secretive etc.): usa SSH_AUTH_SOCK do agente,
    ///   sem configurar SSH_ASKPASS (o agente responde os desafios de autenticação)
    public static func buildConnectionEnvironment(for host: Host) -> [String] {
        switch host.authMethod {
        case .agent(let agentSocket):
            return SSHAskPassHelper.shared.buildEnvironment(secret: nil, sshAuthSock: agentSocket)
        case .password, .sshKey:
            let secret = KeychainManager.shared.readCredential(for: host.keychainAccountKey)
            return SSHAskPassHelper.shared.buildEnvironment(secret: secret)
        }
    }
}
