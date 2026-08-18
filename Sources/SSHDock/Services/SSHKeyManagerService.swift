import Foundation

public enum SSHKeyError: Error, LocalizedError {
    case generationFailed(String)
    case exportFailed(String)
    case fileNotFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .generationFailed(let msg): return "Falha ao gerar chave SSH: \(msg)"
        case .exportFailed(let msg): return "Falha ao exportar chave SSH: \(msg)"
        case .fileNotFound(let path): return "Arquivo de chave não encontrado: \(path)"
        }
    }
}

public final class SSHKeyManagerService {
    public static let shared = SSHKeyManagerService()
    
    private init() {}
    
    /// Obtém o caminho expandido da pasta ~/.ssh
    public var sshDirectoryURL: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".ssh")
    }
    
    /// Gera um novo par de chaves SSH (ed25519 ou rsa) em ~/.ssh
    public func generateKeyPair(
        filename: String = "id_ed25519_sshdock",
        type: String = "ed25519",
        passphrase: String = ""
    ) throws -> (privateKeyPath: String, publicKeyPath: String) {
        let fileManager = FileManager.default
        let sshDir = sshDirectoryURL
        
        // Garante que o diretório ~/.ssh existe com permissão 700
        if !fileManager.fileExists(atPath: sshDir.path) {
            try fileManager.createDirectory(at: sshDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
        
        let privateKeyURL = sshDir.appendingPathComponent(filename)
        
        // Se o arquivo já existir, lança erro para evitar sobrescrever
        if fileManager.fileExists(atPath: privateKeyURL.path) {
            throw SSHKeyError.generationFailed("A chave '\(filename)' já existe em ~/.ssh")
        }
        
        // Executa o ssh-keygen
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = [
            "-t", type,
            "-f", privateKeyURL.path,
            "-N", passphrase,
            "-C", "SSHDock Auto-Generated"
        ]
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Erro desconhecido"
            throw SSHKeyError.generationFailed(output)
        }
        
        let privatePathDisplay = "~/.ssh/\(filename)"
        let publicPathDisplay = "~/.ssh/\(filename).pub"
        
        return (privatePathDisplay, publicPathDisplay)
    }
    
    /// Exporta a chave pública para o arquivo authorized_keys do servidor remoto via SSH
    public func exportPublicKeyToRemoteHost(
        publicKeyPath: String,
        hostname: String,
        port: Int,
        username: String,
        password: String?
    ) async throws {
        let fileManager = FileManager.default
        let expandedPubPath = NSString(string: publicKeyPath).expandingTildeInPath
        
        guard fileManager.fileExists(atPath: expandedPubPath) else {
            throw SSHKeyError.fileNotFound(publicKeyPath)
        }
        
        let pubKeyContent = try String(contentsOfFile: expandedPubPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !pubKeyContent.isEmpty else {
            throw SSHKeyError.exportFailed("Chave pública está vazia")
        }
        
        // Script remoto que adiciona a chave ao ~/.ssh/authorized_keys com permissões corretas
        let remoteCommand = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '\(pubKeyContent)' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        
        // Se houver senha salva no Keychain, tenta enviar a chave diretamente
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        let args = [
            "-p", "\(port)",
            "-o", "StrictHostKeyChecking=accept-new",
            "\(username)@\(hostname)",
            remoteCommand
        ]
        process.arguments = args
        
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? "Falha no comando de envio SSH"
            throw SSHKeyError.exportFailed(output)
        }
    }
}
