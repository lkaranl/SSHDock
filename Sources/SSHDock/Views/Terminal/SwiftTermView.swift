import SwiftUI
import AppKit
import SwiftTerm

// MARK: - ThrottledTerminalContainer
//
// Container NSView que debounce mudanças de tamanho do terminal Metal.
// Com `.prominentDetail` no NavigationSplitView, o sidebar NÃO redimensiona
// o detail — então este container serve como proteção para resizes manuais
// de janela (arrastar borda) e edge cases.
//
// Usa DispatchWorkItem em vez de Timer — zero overhead de RunLoop.

public final class ThrottledTerminalContainer: NSView {
    private(set) var terminalView: LocalProcessTerminalView?
    private var pendingResize: DispatchWorkItem?
    private var hasInitialLayout = false
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

    private func setupFontObserver() {
        fontObserver = NotificationCenter.default.addObserver(
            forName: .terminalFontSizeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let tv = self?.terminalView {
                tv.font = TerminalFontManager.shared.getBestTerminalFont()
            }
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
                if let tv = terminalView {
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

    public func attach(_ terminal: LocalProcessTerminalView) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        self.terminalView = terminal
        terminal.autoresizingMask = []
        addSubview(terminal)
    }

    override public func layout() {
        super.layout()
        guard let terminal = terminalView else { return }
        let newSize = bounds.size
        guard newSize.width > 0, newSize.height > 0 else { return }

        if !hasInitialLayout {
            // Primeiro layout: aplica imediatamente sem debounce
            hasInitialLayout = true
            terminal.frame = bounds
            return
        }

        // Resizes subsequentes: debounce 50ms para window drag resize
        guard terminal.frame.size != newSize else { return }

        pendingResize?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let tv = self.terminalView else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tv.frame = self.bounds
            CATransaction.commit()
        }
        pendingResize = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    deinit {
        pendingResize?.cancel()
        if let observer = fontObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - SwiftTermView

public struct SwiftTermView: NSViewRepresentable {
    public typealias NSViewType = ThrottledTerminalContainer

    public let host: Host
    public let executable: String
    public let args: [String]
    public let commandToInject: String?
    public let onStateChanged: (ConnectionState) -> Void

    public init(
        host: Host,
        executable: String = "/usr/bin/ssh",
        args: [String],
        commandToInject: String? = nil,
        onStateChanged: @escaping (ConnectionState) -> Void
    ) {
        self.host = host
        self.executable = executable
        self.args = args
        self.commandToInject = commandToInject
        self.onStateChanged = onStateChanged
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> ThrottledTerminalContainer {
        let container = ThrottledTerminalContainer()
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.processDelegate = context.coordinator
        container.attach(terminalView)

        let font = TerminalFontManager.shared.getBestTerminalFont()
        terminalView.font = font

        // Ambiente de acordo com o método de autenticação
        // (SSH_ASKPASS + Keychain para senha/chave; SSH_AUTH_SOCK para agente)
        let env = TerminalViewModel.buildConnectionEnvironment(for: host)

        // startProcess é adiado 1 ciclo para container ter frame válido.
        // O estado inicia em .connecting; o watchdog marca .connected se o
        // processo continuar vivo após o timeout, ou .failed se ele morrer antes.
        DispatchQueue.main.async {
            terminalView.startProcess(
                executable: executable,
                args: args,
                environment: env,
                execName: nil
            )
            onStateChanged(.connecting)
            context.coordinator.scheduleConnectionWatchdog()
        }

        return container
    }

    public func updateNSView(_ container: ThrottledTerminalContainer, context: Context) {
        if let command = commandToInject, !command.isEmpty {
            container.terminalView?.send(txt: command)
        }
    }

    public class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: SwiftTermView
        private var wasTerminated = false
        private var connectionEstablished = false
        
        /// Timeout (em segundos) antes de considerar a conexão estabelecida
        private let connectionWatchdogTimeout: TimeInterval = 15

        init(_ parent: SwiftTermView) {
            self.parent = parent
        }
        
        /// Se o processo continuar vivo após o timeout, marca .connected;
        /// se morrer antes, `processTerminated` já terá marcado .failed.
        func scheduleConnectionWatchdog() {
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionWatchdogTimeout) { [weak self] in
                guard let self, !self.wasTerminated, !self.connectionEstablished else { return }
                self.connectionEstablished = true
                self.parent.onStateChanged(.connected)
            }
        }

        public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        public func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                self.wasTerminated = true
                
                if !self.connectionEstablished, let code = exitCode, code != 0 {
                    let reason = code == 255
                        ? "Não foi possível conectar ao host. Verifique host, porta e credenciais."
                        : "Processo finalizado com código \(code)"
                    self.parent.onStateChanged(.failed(reason))
                } else if let code = exitCode, code != 0 {
                    self.parent.onStateChanged(.failed("Sessão encerrada com código \(code)"))
                } else {
                    self.parent.onStateChanged(.disconnected)
                }
            }
        }

        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}

