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
        
        // Aceita novas chaves automaticamente para evitar bloqueio silencioso
        args.append(contentsOf: ["-o", "StrictHostKeyChecking=accept-new"])
        
        // Autenticação por Chave SSH
        if case .sshKey(let keyPath) = host.authMethod, !keyPath.isEmpty {
            let expandedPath = NSString(string: keyPath).expandingTildeInPath
            args.append(contentsOf: ["-i", expandedPath])
        }
        
        // Força alocação de PTY e executa fastfetch na inicialização do shell
        args.append("-t")
        args.append("\(host.username)@\(host.hostname)")
        args.append("fastfetch 2>/dev/null || true; exec ${SHELL:-/bin/sh} -l")
        
        return ("/usr/bin/ssh", args)
    }
    
    /// Obtém variáveis de ambiente otimizadas com suporte a UTF-8, 256 cores e SSH_ASKPASS seguro
    public func buildEnvironment() -> [String] {
        let secret = getSecretFromKeychain()
        return SSHAskPassHelper.shared.buildEnvironment(secret: secret)
    }

    /// Busca senha/passphrase do Keychain para o host
    public func getSecretFromKeychain() -> String? {
        return keychain.readCredential(for: session.host.keychainAccountKey)
    }
}
