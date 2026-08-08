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
        
        // Destination user@host
        args.append("\(host.username)@\(host.hostname)")
        
        return ("/usr/bin/ssh", args)
    }
    
    /// Busca senha/passphrase do Keychain para o host
    public func getSecretFromKeychain() -> String? {
        return keychain.readCredential(for: session.host.keychainAccountKey)
    }
}
