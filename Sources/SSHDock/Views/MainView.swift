import SwiftUI

public struct MainView: View {
    @StateObject private var viewModel = AppViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            TerminalContainerView(viewModel: viewModel)
        }
        .navigationTitle("SSHDock")
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
