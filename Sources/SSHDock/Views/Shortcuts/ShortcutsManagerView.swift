import SwiftUI
import AppKit

public struct ShortcutsManagerView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0
    @State private var isPresentingAddEditModal: Bool = false
    @State private var editingShortcut: CustomShortcut? = nil
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Atalhos de Teclado")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Visualize os atalhos do sistema e configure atalhos personalizados para o terminal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            
            Divider()
            
            // Picker de Abas
            Picker("Categoria", selection: $selectedTab) {
                Text("Personalizados (\(viewModel.customShortcuts.count))").tag(0)
                Text("Atalhos do Sistema").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            
            // Conteúdo
            if selectedTab == 0 {
                customShortcutsListView
            } else {
                systemShortcutsListView
            }
            
            Divider()
            
            // Rodapé
            HStack {
                if selectedTab == 0 {
                    Button {
                        editingShortcut = nil
                        isPresentingAddEditModal = true
                    } label: {
                        Label("Novo Atalho", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
                
                Button("Fechar") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 580, height: 480)
        .sheet(isPresented: $isPresentingAddEditModal) {
            ShortcutFormModal(
                shortcutToEdit: editingShortcut,
                onSave: { shortcut in
                    if editingShortcut != nil {
                        viewModel.updateCustomShortcut(shortcut)
                    } else {
                        viewModel.addCustomShortcut(shortcut)
                    }
                    isPresentingAddEditModal = false
                },
                onCancel: {
                    isPresentingAddEditModal = false
                }
            )
        }
    }
    
    // MARK: - Lista de Atalhos Customizados
    private var customShortcutsListView: some View {
        Group {
            if viewModel.customShortcuts.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "keyboard")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.secondary)
                    Text("Nenhum atalho personalizado cadastrado")
                        .font(.headline)
                    Text("Crie combinações de teclas para executar comandos shell rápidos no terminal ativo.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                    Button {
                        editingShortcut = nil
                        isPresentingAddEditModal = true
                    } label: {
                        Label("Criar Primeiro Atalho", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(viewModel.customShortcuts) { shortcut in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { shortcut.isEnabled },
                                set: { _ in viewModel.toggleCustomShortcut(shortcut) }
                            ))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(shortcut.name)
                                        .font(.system(size: 13, weight: .semibold))
                                    if !shortcut.autoExecute {
                                        Text("Manual")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                    }
                                }
                                
                                Text(shortcut.command)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            KeyCapView(text: shortcut.displayKeyCombo)
                            
                            Menu {
                                Button("Editar") {
                                    editingShortcut = shortcut
                                    isPresentingAddEditModal = true
                                }
                                Button(role: .destructive) {
                                    viewModel.deleteCustomShortcut(shortcut)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .padding(4)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 24)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    // MARK: - Lista de Atalhos do Sistema
    private var systemShortcutsListView: some View {
        List {
            Section(header: Text("Visualização & Zoom").font(.caption).fontWeight(.bold)) {
                SystemShortcutRow(title: "Aumentar Fonte do Terminal", shortcut: "⌘ + / ⌘ =", description: "Aumenta em 1pt o tamanho dos caracteres do terminal.")
                SystemShortcutRow(title: "Diminuir Fonte do Terminal", shortcut: "⌘ -", description: "Diminui em 1pt o tamanho dos caracteres do terminal.")
                SystemShortcutRow(title: "Tamanho Padrão (Reset)", shortcut: "⌘ 0", description: "Restaura o tamanho padrão de 13pt da fonte.")
                SystemShortcutRow(title: "Pinça no Trackpad (Pinch)", shortcut: "Gesto de Pinça", description: "Aumenta ou diminui o zoom com dois dedos no trackpad.")
            }
            
            Section(header: Text("Gerenciamento").font(.caption).fontWeight(.bold)) {
                SystemShortcutRow(title: "Gerenciador de Atalhos", shortcut: "⌘ ⌥ K", description: "Abre a tela de cadastro e visualização de atalhos.")
            }
        }
        .listStyle(.inset)
    }
}

// MARK: - KeyCap Visual Component
public struct KeyCapView: View {
    public let text: String
    
    public init(text: String) {
        self.text = text
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            ForEach(text.components(separatedBy: " "), id: \.self) { part in
                Text(part)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
            }
        }
    }
}

// MARK: - Linha de Atalho do Sistema
private struct SystemShortcutRow: View {
    let title: String
    let shortcut: String
    let description: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            KeyCapView(text: shortcut)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Modal de Criação / Edição de Atalho
private struct ShortcutFormModal: View {
    @State private var name: String
    @State private var command: String
    @State private var key: String
    @State private var selectedModifiers: Set<ShortcutModifier>
    @State private var autoExecute: Bool
    
    let isEditing: Bool
    let shortcutId: UUID
    let onSave: (CustomShortcut) -> Void
    let onCancel: () -> Void
    
    init(shortcutToEdit: CustomShortcut?, onSave: @escaping (CustomShortcut) -> Void, onCancel: @escaping () -> Void) {
        self.isEditing = shortcutToEdit != nil
        self.shortcutId = shortcutToEdit?.id ?? UUID()
        _name = State(initialValue: shortcutToEdit?.name ?? "")
        _command = State(initialValue: shortcutToEdit?.command ?? "")
        _key = State(initialValue: shortcutToEdit?.key.uppercased() ?? "")
        _selectedModifiers = State(initialValue: Set(shortcutToEdit?.modifiers ?? [.option]))
        _autoExecute = State(initialValue: shortcutToEdit?.autoExecute ?? true)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isEditing ? "Editar Atalho de Teclado" : "Novo Atalho de Teclado")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Nome do Atalho")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Ex: Status do Docker", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Comando Shell")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Ex: docker ps -a", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
            }
            
            // Configuração da Combinação de Teclas
            VStack(alignment: .leading, spacing: 8) {
                Text("Combinação de Teclas")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    // Seletores de modificadores
                    ForEach(ShortcutModifier.allCases, id: \.self) { mod in
                        Button {
                            if selectedModifiers.contains(mod) {
                                if selectedModifiers.count > 1 {
                                    selectedModifiers.remove(mod)
                                }
                            } else {
                                selectedModifiers.insert(mod)
                            }
                        } label: {
                            Text("\(mod.symbol) \(mod.rawValue)")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(selectedModifiers.contains(mod) ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                .foregroundColor(selectedModifiers.contains(mod) ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("+")
                        .foregroundColor(.secondary)
                        .fontWeight(.bold)
                    
                    TextField("Tecla (A-Z, 0-9)", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.center)
                        .onChange(of: key) { _, newValue in
                            if newValue.count > 1 {
                                key = String(newValue.prefix(1)).uppercased()
                            } else {
                                key = newValue.uppercased()
                            }
                        }
                }
            }
            
            Toggle("Executar automaticamente ao acionar (Enviar Enter)", isOn: $autoExecute)
                .font(.subheadline)
            
            // Preview
            if !key.isEmpty && !selectedModifiers.isEmpty {
                HStack {
                    Text("Pré-visualização:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let combo = selectedModifiers.sorted(by: { $0.rawValue < $1.rawValue }).map { $0.symbol }.joined(separator: " ") + " " + key.uppercased()
                    KeyCapView(text: combo)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }
            
            HStack {
                Button("Cancelar", action: onCancel)
                Spacer()
                Button("Salvar Atalho") {
                    guard !name.isEmpty && !command.isEmpty && !key.isEmpty else { return }
                    let shortcut = CustomShortcut(
                        id: shortcutId,
                        name: name,
                        command: command,
                        key: key,
                        modifiers: Array(selectedModifiers),
                        autoExecute: autoExecute,
                        isEnabled: true
                    )
                    onSave(shortcut)
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || command.isEmpty || key.isEmpty || selectedModifiers.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .frame(width: 440)
    }
}
