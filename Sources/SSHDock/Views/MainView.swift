import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = AppViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            TerminalContainerView(viewModel: viewModel)
        }
        .navigationTitle("SSHDock")
        // Alerta global de erros (persistência, Keychain, etc.)
        .alert(
            "Ocorreu um erro",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            ),
            presenting: viewModel.errorMessage
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        // .prominentDetail: sidebar sobrepõe o detail sem redimensioná-lo.
        // Elimina 100% das chamadas setFrameSize/Metal durante toggle do sidebar.
        .navigationSplitViewStyle(.prominentDetail)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.hostToEdit = nil
                    viewModel.isPresentingHostForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .help("Novo Servidor SSH")
            }
        }
    }
}
