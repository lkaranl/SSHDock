import Foundation

/// Gerencia a integração segura com o OpenSSH através do mecanismo SSH_ASKPASS.
/// Permite fornecer senhas e passphrases de forma síncrona, direta e sem expor credenciais no buffer do PTY.
public final class SSHAskPassHelper {
    public static let shared = SSHAskPassHelper()
    
    private let scriptName = "sshdock-askpass"
    private var cachedScriptPath: String?
    private let lock = NSLock()
    
    private init() {}
    
    /// Garante que o script auxiliar do SSH_ASKPASS exista e tenha permissões de execução (0700).
    /// Retorna o caminho absoluto do script executável.
    public func ensureAskPassScriptExists() -> String {
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cachedScriptPath, FileManager.default.isExecutableFile(atPath: cached) {
            return cached
        }
        
        let fileManager = FileManager.default
        let scriptDir: URL
        
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            scriptDir = appSupport.appendingPathComponent("SSHDock", isDirectory: true)
        } else {
            scriptDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SSHDock", isDirectory: true)
        }
        
        try? fileManager.createDirectory(at: scriptDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        
        let scriptURL = scriptDir.appendingPathComponent(scriptName)
        let scriptPath = scriptURL.path
        
        let scriptContent = """
        #!/bin/sh
        if [ -n "$SSHDOCK_AUTH_SECRET" ]; then
            printf '%s\\n' "$SSHDOCK_AUTH_SECRET"
        fi
        """
        
        do {
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptPath)
        } catch {
            NSLog("[SSHDock] Falha ao escrever script askpass em %@: %@", scriptPath, error.localizedDescription)
        }
        
        cachedScriptPath = scriptPath
        return scriptPath
    }
    
    /// Constrói o array de variáveis de ambiente com suporte a UTF-8, cores, SSH_ASKPASS (senha/passphrase)
    /// e SSH_AUTH_SOCK (ssh-agent: 1Password, Secretive, ssh-add etc.).
    /// Em modo agente, `secret` deve ser nil para NÃO configurar o SSH_ASKPASS.
    public func buildEnvironment(secret: String? = nil, sshAuthSock: String? = nil) -> [String] {
        var envDict = ProcessInfo.processInfo.environment
        envDict["TERM"] = "xterm-256color"
        envDict["COLORTERM"] = "truecolor"
        envDict["LANG"] = "en_US.UTF-8"
        envDict["LC_ALL"] = "en_US.UTF-8"
        envDict["LC_CTYPE"] = "en_US.UTF-8"
        
        if let secret = secret, !secret.isEmpty {
            let askPassPath = ensureAskPassScriptExists()
            envDict["SSH_ASKPASS"] = askPassPath
            envDict["SSH_ASKPASS_REQUIRE"] = "force"
            envDict["SSHDOCK_AUTH_SECRET"] = secret
            envDict["DISPLAY"] = ":0"
        }
        
        if let sock = sshAuthSock, !sock.isEmpty {
            let expandedSock = NSString(string: sock).expandingTildeInPath
            envDict["SSH_AUTH_SOCK"] = expandedSock
        }
        
        return envDict.map { "\($0.key)=\($0.value)" }
    }
}
