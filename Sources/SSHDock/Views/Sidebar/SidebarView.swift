import SwiftUI

public struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Barra de Busca e Ações Superiores
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Buscar servidor ou IP...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(8)
                
                HStack(spacing: 8) {
                    Button {
                        viewModel.hostToEdit = nil
                        viewModel.isPresentingHostForm = true
                    } label: {
                        Label("Novo Host", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button {
                        viewModel.isPresentingGroupForm = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Novo Grupo")
                }
            }
            .padding(10)
            
            Divider()
            
            // Lista de Servidores Agrupados
            List {
                ForEach(viewModel.groups) { group in
                    Section(header: GroupHeaderView(group: group, onDelete: {
                        viewModel.deleteGroup(group)
                    })) {
                        let groupHosts = viewModel.hostsForGroup(group.id)
                        if groupHosts.isEmpty {
                            Text("Nenhum servidor cadastrado")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.leading, 12)
                        } else {
                            ForEach(groupHosts) { host in
                                HostRowView(
                                    host: host,
                                    activeSession: viewModel.activeSessions.first(where: { $0.host.id == host.id }),
                                    onConnect: {
                                        viewModel.openSession(for: host)
                                    },
                                    onEdit: {
                                        viewModel.hostToEdit = host
                                        viewModel.isPresentingHostForm = true
                                    },
                                    onDelete: {
                                        viewModel.deleteHost(host)
                                    }
                                )
                                .tag(host.id)
                                .onTapGesture(count: 2) {
                                    viewModel.openSession(for: host)
                                }
                            }
                        }
                    }
                }
                
                let unassigned = viewModel.unassignedHosts
                if !unassigned.isEmpty {
                    Section(header: Text("Gerais / Sem Grupo")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)) {
                        ForEach(unassigned) { host in
                            HostRowView(
                                host: host,
                                activeSession: viewModel.activeSessions.first(where: { $0.host.id == host.id }),
                                onConnect: {
                                    viewModel.openSession(for: host)
                                },
                                onEdit: {
                                    viewModel.hostToEdit = host
                                    viewModel.isPresentingHostForm = true
                                },
                                onDelete: {
                                    viewModel.deleteHost(host)
                                }
                            )
                            .tag(host.id)
                            .onTapGesture(count: 2) {
                                viewModel.openSession(for: host)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $viewModel.isPresentingHostForm) {
            HostFormView(viewModel: viewModel, hostToEdit: viewModel.hostToEdit)
        }
        .sheet(isPresented: $viewModel.isPresentingGroupForm) {
            GroupFormView(viewModel: viewModel)
        }
    }
}
