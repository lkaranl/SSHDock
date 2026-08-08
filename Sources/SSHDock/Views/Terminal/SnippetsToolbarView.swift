import SwiftUI

public struct SnippetsToolbarView: View {
    @ObservedObject var viewModel: AppViewModel
    public let onExecuteCommand: (String, Bool) -> Void
    
    @State private var isPresentingAddSnippet: Bool = false
    @State private var snippetName: String = ""
    @State private var snippetCommand: String = ""
    @State private var snippetIcon: String = "terminal.fill"
    
    public init(viewModel: AppViewModel, onExecuteCommand: @escaping (String, Bool) -> Void) {
        self.viewModel = viewModel
        self.onExecuteCommand = onExecuteCommand
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 11))
                Text("Snippets Rápidos:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(viewModel.snippets) { snippet in
                        Button {
                            onExecuteCommand(snippet.command, snippet.autoExecute)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: snippet.iconName)
                                    .font(.system(size: 10))
                                Text(snippet.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Executa: \(snippet.command)")
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.deleteSnippet(snippet)
                            } label: {
                                Label("Excluir Snippet", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Button {
                isPresentingAddSnippet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .padding(4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Adicionar novo Snippet")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Material.bar)
        .sheet(isPresented: $isPresentingAddSnippet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Novo Snippet de Comando")
                    .font(.headline)
                
                TextField("Nome (ex: Iniciar Fish)", text: $snippetName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Comando (ex: exec fish)", text: $snippetCommand)
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Button("Cancelar") {
                        isPresentingAddSnippet = false
                    }
                    Spacer()
                    Button("Salvar Snippet") {
                        guard !snippetName.isEmpty && !snippetCommand.isEmpty else { return }
                        let newSnippet = Snippet(name: snippetName, command: snippetCommand, iconName: snippetIcon)
                        viewModel.addSnippet(newSnippet)
                        snippetName = ""
                        snippetCommand = ""
                        isPresentingAddSnippet = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(width: 360)
        }
    }
}
