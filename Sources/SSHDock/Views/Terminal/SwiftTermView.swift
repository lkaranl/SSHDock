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

    override public var isFlipped: Bool { true }

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

        let font = TerminalFontManager.shared.getBestTerminalFont(size: 13.0)
        terminalView.font = font

        var envDict = ProcessInfo.processInfo.environment
        envDict["TERM"] = "xterm-256color"
        envDict["COLORTERM"] = "truecolor"
        envDict["LANG"] = "en_US.UTF-8"
        envDict["LC_ALL"] = "en_US.UTF-8"
        envDict["LC_CTYPE"] = "en_US.UTF-8"
        let env = envDict.map { "\($0.key)=\($0.value)" }

        // startProcess é adiado 1 ciclo para container ter frame válido
        DispatchQueue.main.async {
            terminalView.startProcess(
                executable: executable,
                args: args,
                environment: env,
                execName: nil
            )
            onStateChanged(.connected)
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

        init(_ parent: SwiftTermView) {
            self.parent = parent
        }

        public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

        public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

        public func processTerminated(source: TerminalView, exitCode: Int32?) {
            DispatchQueue.main.async {
                if let code = exitCode, code != 0 {
                    self.parent.onStateChanged(.failed("Processo finalizado com código \(code)"))
                } else {
                    self.parent.onStateChanged(.disconnected)
                }
            }
        }

        public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    }
}

