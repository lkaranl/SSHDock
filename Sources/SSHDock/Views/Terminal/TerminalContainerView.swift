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

                // View de Terminais com Pool Persistente (0ms Tab Switch)
                TerminalMultiSessionView(
                    sessions: viewModel.activeSessions,
                    selectedSessionId: viewModel.selectedSessionId,
                    commandToInject: pendingCommand,
                    onStateChanged: { id, newState in
                        viewModel.updateSessionState(id: id, state: newState)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
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
