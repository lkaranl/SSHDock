import SwiftUI
import AppKit
import SwiftTerm

public struct SwiftTermView: NSViewRepresentable {
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
    
    public func makeNSView(context: Context) -> LocalProcessTerminalView {
        let terminalView = LocalProcessTerminalView(frame: .zero)
        terminalView.autoresizingMask = [.width, .height]
        terminalView.processDelegate = context.coordinator
        
        // Dispara o processo SSH no terminal PTY
        DispatchQueue.main.async {
            terminalView.startProcess(
                executable: executable,
                args: args,
                environment: nil,
                execName: nil
            )
            onStateChanged(.connected)
        }
        
        return terminalView
    }
    
    public func updateNSView(_ nsView: LocalProcessTerminalView, context: Context) {
        if let command = commandToInject, !command.isEmpty {
            DispatchQueue.main.async {
                nsView.send(txt: command)
            }
        }
    }
    
    public class Coordinator: NSObject, LocalProcessTerminalViewDelegate {
        var parent: SwiftTermView
        
        init(_ parent: SwiftTermView) {
            self.parent = parent
        }
        
        public func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
            // Tratamento de redimensionamento do terminal
        }
        
        public func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
            // Atualização de título se necessário
        }
        
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
