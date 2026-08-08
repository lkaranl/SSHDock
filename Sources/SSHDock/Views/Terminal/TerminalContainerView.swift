import SwiftUI

public struct TerminalContainerView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var pendingCommand: String? = nil

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            if viewModel.activeSessions.isEmpty {
                emptyStateView
            } else {
                // Barra de Abas Superiores
                TerminalTabBarView(viewModel: viewModel)

                Divider()

                // Toolbar de Snippets Rápidos
                SnippetsToolbarView(viewModel: viewModel) { command, autoExecute in
                    let finalCmd = autoExecute ? "\(command)\n" : command
                    pendingCommand = finalCmd
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pendingCommand = nil
                    }
                }

                Divider()

                // View de Terminal Ativo
                terminalView
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    // Extraído como computed property para evitar re-computação pesada no body principal
    @ViewBuilder
    private var terminalView: some View {
        if let selectedId = viewModel.selectedSessionId,
           let session = viewModel.activeSessions.first(where: { $0.id == selectedId }) {

            // Constrói args SSH inline — zero alocação de objetos temporários
            let host = session.host
            let sshArgs = buildSSHArgs(for: host)

            SwiftTermView(
                host: host,
                executable: "/usr/bin/ssh",
                args: sshArgs,
                commandToInject: pendingCommand,
                onStateChanged: { newState in
                    viewModel.updateSessionState(id: session.id, state: newState)
                }
            )
            .id(session.id)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Spacer()
        }
    }

    /// Constrói argumentos SSH sem instanciar TerminalViewModel
    private func buildSSHArgs(for host: Host) -> [String] {
        var args: [String] = []
        args.reserveCapacity(8)
        args.append("-p")
        args.append("\(host.port)")
        args.append("-o")
        args.append("StrictHostKeyChecking=accept-new")
        if case .sshKey(let keyPath) = host.authMethod, !keyPath.isEmpty {
            args.append("-i")
            args.append(NSString(string: keyPath).expandingTildeInPath)
        }
        args.append("\(host.username)@\(host.hostname)")
        return args
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "terminal")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.secondary)
                .symbolEffect(.pulse)
            
            VStack(spacing: 6) {
                Text("Nenhuma Sessão SSH Ativa")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Selecione um servidor na barra lateral ou crie um novo host para conectar.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            
            Button {
                viewModel.hostToEdit = nil
                viewModel.isPresentingHostForm = true
            } label: {
                Label("Adicionar Servidor", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
