import SwiftUI
import AppKit
import SwiftTerm

/// Container AppKit de altíssima performance para gerenciar abas de sessões SSH ativas.
/// Mantém as views de terminal vivas em memória no subview stack, permitindo troca
/// instantânea de abas (0ms delay) por alternância do `isHidden` sem recriar o processo SSH.
public final class TerminalMultiSessionContainerView: NSView {
    private var terminalViews: [UUID: LocalProcessTerminalView] = [:]
    private var currentSelectedId: UUID?
    private var fontObserver: NSObjectProtocol?
    
    override public var isFlipped: Bool { true }
    
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupFontObserver()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFontObserver()
    }
    
    deinit {
        if let observer = fontObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupFontObserver() {
        fontObserver = NotificationCenter.default.addObserver(
            forName: .terminalFontSizeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateAllTerminalFonts()
        }
    }
    
    private func updateAllTerminalFonts() {
        let font = TerminalFontManager.shared.getBestTerminalFont()
        for (_, tv) in terminalViews {
            tv.font = font
        }
    }
    
    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        // 1. Atalhos de Sistema (Zoom e Gestão de Abas)
        if event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers ?? ""
            if chars == "+" || chars == "=" {
                TerminalFontManager.shared.increaseFontSize()
                return true
            } else if chars == "-" {
                TerminalFontManager.shared.decreaseFontSize()
                return true
            } else if chars == "0" {
                TerminalFontManager.shared.resetFontSize()
                return true
            } else if chars.lowercased() == "t" {
                NotificationCenter.default.post(name: .openNewTab, object: nil)
                return true
            } else if chars.lowercased() == "w" {
                NotificationCenter.default.post(name: .closeCurrentTab, object: nil)
                return true
            }
        }
        
        // 2. Atalhos Customizados Cadastrados
        let customShortcuts = StorageManager.shared.safeLoadShortcuts()
        for shortcut in customShortcuts where shortcut.isEnabled {
            if shortcut.matches(event: event) {
                if let selectedId = currentSelectedId, let tv = terminalViews[selectedId] {
                    let cmd = shortcut.autoExecute ? "\(shortcut.command)\n" : shortcut.command
                    tv.send(txt: cmd)
                    return true
                }
            }
        }
        
        return super.performKeyEquivalent(with: event)
    }
    
    override public func magnify(with event: NSEvent) {
        if event.magnification > 0.05 {
            TerminalFontManager.shared.increaseFontSize()
        } else if event.magnification < -0.05 {
            TerminalFontManager.shared.decreaseFontSize()
        }
    }
    
    public func syncSessions(
        sessions: [SSHSession],
        selectedId: UUID?,
        commandToInject: String?,
        coordinator: TerminalMultiSessionView.Coordinator,
        onStateChanged: @escaping (UUID, ConnectionState) -> Void
    ) {
        let activeIds = Set(sessions.map { $0.id })
        
        // 1. Remove sessões encerradas
        for (id, tv) in terminalViews where !activeIds.contains(id) {
            tv.removeFromSuperview()
            terminalViews.removeValue(forKey: id)
        }
        
        // 2. Adiciona novas sessões que ainda não existem no pool
        for session in sessions {
            if terminalViews[session.id] == nil {
                let tv = LocalProcessTerminalView(frame: bounds)
                tv.autoresizingMask = [.width, .height]
                
                // Configura fonte Nerd Font com tamanho atual do TerminalFontManager
                let font = TerminalFontManager.shared.getBestTerminalFont()
                tv.font = font
                
                // Configura o delegate da sessão com o ID correspondente
                let sessionDelegate = SingleSessionDelegate(sessionId: session.id, onStateChanged: onStateChanged)
                tv.processDelegate = sessionDelegate
                
                // Associa o delegate à view via propriedade dinâmica para evitar deinit
                objc_setAssociatedObject(tv, &AssociatedKeys.delegateKey, sessionDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                // Prepara variáveis de ambiente de acordo com o método de autenticação
                // (SSH_ASKPASS + Keychain para senha/chave; SSH_AUTH_SOCK para agente)
                let env = TerminalViewModel.buildConnectionEnvironment(for: session.host)
                let args = buildSSHArgs(for: session.host)
                
                addSubview(tv)
                terminalViews[session.id] = tv
                
                DispatchQueue.main.async {
                    tv.frame = self.bounds
                    tv.startProcess(
                        executable: "/usr/bin/ssh",
                        args: args,
                        environment: env,
                        execName: nil
                    )
                    // Sessão inicia como .connecting; o watchdog do delegate
                    // marca .connected (processo vivo após timeout) ou .failed
                    // (processo morreu antes de estabelecer a conexão).
                    onStateChanged(session.id, .connecting)
                    sessionDelegate.scheduleConnectionWatchdog()
                }
            }
        }
        
        // 3. Alterna a visibilidade (0ms delay)
        self.currentSelectedId = selectedId
        for (id, tv) in terminalViews {
            if id == selectedId {
                tv.isHidden = false
                tv.frame = bounds
                window?.makeFirstResponder(tv)
            } else {
                tv.isHidden = true
            }
        }
        
        // 4. Injeta comandos de Snippets se houver
        if let selectedId = selectedId,
           let command = commandToInject,
           !command.isEmpty,
           let selectedTv = terminalViews[selectedId] {
            selectedTv.send(txt: command)
        }
    }
    
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        if let selectedId = currentSelectedId, let tv = terminalViews[selectedId] {
            tv.frame = CGRect(origin: .zero, size: newSize)
        }
    }
    
    /// Argumentos SSH com timeout de conexão: se o host estiver inacessível,
    /// o próprio /usr/bin/ssh encerra rápido (exit 255) em vez de ficar pendurado.
    private func buildSSHArgs(for host: Host) -> [String] {
        var args: [String] = []
        args.reserveCapacity(16)
        args.append("-p")
        args.append("\(host.port)")
        args.append("-o")
        args.append("ConnectTimeout=10")
        args.append("-o")
        args.append("ServerAliveInterval=15")
        args.append("-o")
        args.append("ServerAliveCountMax=3")
        args.append("-o")
        args.append("StrictHostKeyChecking=accept-new")
        if case .sshKey(let keyPath) = host.authMethod, !keyPath.isEmpty {
            args.append("-i")
            args.append(NSString(string: keyPath).expandingTildeInPath)
        }
        args.append("-t")
        args.append("\(host.username)@\(host.hostname)")
        args.append("command -v fish >/dev/null 2>&1 && exec fish -C \"fastfetch 2>/dev/null || true\" -l || { fastfetch 2>/dev/null || true; exec ${SHELL:-/bin/sh} -l; }")
        return args
    }
}

private struct AssociatedKeys {
    static var delegateKey: UInt8 = 0
}

/// Timeout (em segundos) aguardado antes de considerar a conexão estabelecida.
/// Se o processo SSH ainda estiver vivo após esse período, assume-se conectado.
private let connectionWatchdogTimeout: TimeInterval = 15

private final class SingleSessionDelegate: NSObject, LocalProcessTerminalViewDelegate {
    let sessionId: UUID
    let onStateChanged: (UUID, ConnectionState) -> Void
    
    /// Indica se o processo SSH já encerrou (falha ou saída normal)
    var wasTerminated = false
    /// Indica se a conexão já foi considerada estabelecida (watchdog disparou)
    var connectionEstablished = false
    
    init(sessionId: UUID, onStateChanged: @escaping (UUID, ConnectionState) -> Void) {
        self.sessionId = sessionId
        self.onStateChanged = onStateChanged
    }
    
    /// Agenda o watchdog de conexão: se o processo continuar vivo após o timeout,
    /// marca como conectado; se o processo morrer antes, marca como falhou.
    func scheduleConnectionWatchdog() {
        DispatchQueue.main.asyncAfter(deadline: .now() + connectionWatchdogTimeout) { [weak self] in
            guard let self, !self.wasTerminated, !self.connectionEstablished else { return }
            self.connectionEstablished = true
            self.onStateChanged(self.sessionId, .connected)
        }
    }
    
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    
    func processTerminated(source: TerminalView, exitCode: Int32?) {
        DispatchQueue.main.async {
            self.wasTerminated = true
            
            // Falha durante a conexão (host inacessível, porta errada, timeout etc.)
            if !self.connectionEstablished, let code = exitCode, code != 0 {
                let reason = code == 255
                    ? "Não foi possível conectar ao host. Verifique host, porta e credenciais."
                    : "Processo finalizado com código \(code)"
                self.onStateChanged(self.sessionId, .failed(reason))
            } else if let code = exitCode, code != 0 {
                self.onStateChanged(self.sessionId, .failed("Sessão encerrada com código \(code)"))
            } else {
                self.onStateChanged(self.sessionId, .disconnected)
            }
        }
    }
    
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

// MARK: - SwiftTerm Multi-Session View (NSViewRepresentable)

public struct TerminalMultiSessionView: NSViewRepresentable {
    public typealias NSViewType = TerminalMultiSessionContainerView
    
    public let sessions: [SSHSession]
    public let selectedSessionId: UUID?
    public let commandToInject: String?
    public let onStateChanged: (UUID, ConnectionState) -> Void
    
    public init(
        sessions: [SSHSession],
        selectedSessionId: UUID?,
        commandToInject: String?,
        onStateChanged: @escaping (UUID, ConnectionState) -> Void
    ) {
        self.sessions = sessions
        self.selectedSessionId = selectedSessionId
        self.commandToInject = commandToInject
        self.onStateChanged = onStateChanged
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> TerminalMultiSessionContainerView {
        let container = TerminalMultiSessionContainerView()
        container.syncSessions(
            sessions: sessions,
            selectedId: selectedSessionId,
            commandToInject: commandToInject,
            coordinator: context.coordinator,
            onStateChanged: onStateChanged
        )
        return container
    }
    
    public func updateNSView(_ container: TerminalMultiSessionContainerView, context: Context) {
        container.syncSessions(
            sessions: sessions,
            selectedId: selectedSessionId,
            commandToInject: commandToInject,
            coordinator: context.coordinator,
            onStateChanged: onStateChanged
        )
    }
    
    public class Coordinator: NSObject {
        var parent: TerminalMultiSessionView
        
        init(_ parent: TerminalMultiSessionView) {
            self.parent = parent
        }
    }
}
