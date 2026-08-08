import SwiftUI
import AppKit
import SwiftTerm

// MARK: - ThrottledTerminalContainer
//
// Problema: NavigationSplitView chama setFrameSize 60–120x por segundo durante
// a animação de abertura/fechamento do sidebar. O LocalProcessTerminalView usa um
// renderizador Metal (MTKView) que recalcula o buffer de texto e re-renderiza a
// cada chamada, bloqueando a thread principal e causando o "delay" visível.
//
// Solução: Este container NSView intercepta setFrameSize e usa um debounce de
// 60ms, propagando o novo tamanho ao Metal apenas UMA vez após a animação
// estabilizar. Durante a transição, o container faz clip do conteúdo existente
// com uma cor de fundo correspondente para aparência limpa.

public final class ThrottledTerminalContainer: NSView {
    private(set) var terminalView: LocalProcessTerminalView?
    private var resizeTimer: Timer?
    private var targetSize: NSSize = .zero

    override public var isFlipped: Bool { true }

    public func attach(_ terminal: LocalProcessTerminalView) {
        wantsLayer = true
        // Background que combina com o terminal para evitar flash durante resize
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.masksToBounds = true

        self.terminalView = terminal
        terminal.autoresizingMask = []
        addSubview(terminal)
        terminal.frame = bounds
    }

    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        guard newSize != .zero, newSize != terminalView?.frame.size else { return }

        targetSize = newSize

        // Cancela o timer anterior e agenda um novo debounce
        resizeTimer?.invalidate()
        resizeTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: false) { [weak self] _ in
            guard let self else { return }
            // Desativa animações CA para snap instantâneo sem flash
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.terminalView?.frame = CGRect(origin: .zero, size: self.targetSize)
            CATransaction.commit()
        }
    }

    deinit {
        resizeTimer?.invalidate()
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

        // Adia startProcess para o próximo ciclo do run loop,
        // garantindo que o container já foi layoutado com frame correto
        // antes de o Metal calcular as dimensões iniciais do PTY.
        DispatchQueue.main.async {
            // Sincroniza o frame do terminal com o container antes de iniciar
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            terminalView.frame = container.bounds
            CATransaction.commit()

            terminalView.startProcess(
                executable: executable,
                args: args,
                environment: nil,
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

