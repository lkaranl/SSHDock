import SwiftUI

public struct HostFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AppViewModel
    
    public var hostToEdit: Host?
    
    @State private var name: String = ""
    @State private var hostname: String = ""
    @State private var portString: String = "22"
    @State private var username: String = ""
    @State private var authSelection: Int = 0 // 0 = Senha, 1 = Chave SSH
    @State private var sshKeyPath: String = "~/.ssh/id_rsa"
    @State private var secretCredential: String = "" // Senha ou Passphrase da Chave
    @State private var selectedGroupId: UUID? = nil
    @State private var isPresentingDeleteAlert: Bool = false
    @State private var keyMessage: String? = nil
    
    public init(viewModel: AppViewModel, hostToEdit: Host? = nil) {
        self.viewModel = viewModel
        self.hostToEdit = hostToEdit
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Elegante com Gradiente Nativo e Ícone
            headerView
            
            Divider()
            
            // Corpo Principal com Cards de Configuração
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Card 1: Identificação do Servidor
                    connectionCard
                    
                    // Card 2: Autenticação & Keychain
                    authenticationCard
                }
                .padding(20)
            }
            
            Divider()
            
            // Rodapé com Botões de Ação
            footerView
        }
        .frame(width: 520, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            populateIfEditing()
        }
    }
    
    // MARK: - Subviews UI Design
    
    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Color.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
                
                Image(systemName: hostToEdit == nil ? "server.rack" : "pencil.line")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(hostToEdit == nil ? "Novo Servidor SSH" : "Editar Servidor")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(hostToEdit == nil ? "Cadastre as credenciais e parâmetros de conexão" : "Atualize os parâmetros e chaves deste host")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Material.bar)
    }
    
    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Conexão & Rede", systemImage: "network")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 10) {
                // Nome do Servidor
                formRow(icon: "tag.fill", color: .blue, title: "Nome") {
                    TextField("Ex: Raspberry Pi Cluster", text: $name)
                        .textFieldStyle(.plain)
                }
                
                Divider().opacity(0.5)
                
                // IP/Host e Porta
                HStack(spacing: 12) {
                    formRow(icon: "globe", color: .cyan, title: "Host / IP") {
                        TextField("192.168.1.100 ou dev.corp.com", text: $hostname)
                            .textFieldStyle(.plain)
                    }
                    
                    formRow(icon: "number", color: .orange, title: "Porta") {
                        TextField("22", text: $portString)
                            .textFieldStyle(.plain)
                            .frame(width: 50)
                    }
                }
                
                Divider().opacity(0.5)
                
                // Usuário
                formRow(icon: "person.fill", color: .green, title: "Usuário") {
                    TextField("root, ubuntu, pi...", text: $username)
                        .textFieldStyle(.plain)
                }
                
                Divider().opacity(0.5)
                
                // Grupo / Categoria
                formRow(icon: "folder.fill", color: .purple, title: "Grupo") {
                    Picker("", selection: $selectedGroupId) {
                        Text("Sem Grupo / Geral").tag(UUID?.none)
                        Divider()
                        ForEach(viewModel.groups) { group in
                            HStack {
                                Image(systemName: group.iconName)
                                Text(group.name)
                            }.tag(UUID?.some(group.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var authenticationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Segurança & Autenticação", systemImage: "lock.shield.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                // Seletor Estilizado de Autenticação
                HStack(spacing: 10) {
                    authOptionButton(title: "Senha", icon: "lock.fill", tag: 0)
                    authOptionButton(title: "Chave SSH", icon: "key.fill", tag: 1)
                }
                
                Divider().opacity(0.5)
                
                if authSelection == 1 {
                    formRow(icon: "doc.text.fill", color: .indigo, title: "Caminho da Chave") {
                        HStack {
                            TextField("~/.ssh/id_rsa", text: $sshKeyPath)
                                .textFieldStyle(.plain)
                            
                            Button {
                                selectKeyFile()
                            } label: {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 12))
                                Text("Buscar...")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    // Ações de Criar e Exportar Chave SSH
                    HStack(spacing: 8) {
                        Button {
                            generateNewKey()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "key.badge.plus")
                                Text("Gerar Nova Chave")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button {
                            exportPublicKey()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Exportar .pub para Host")
                            }
                            .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(hostname.trimmingCharacters(in: .whitespaces).isEmpty || username.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.leading, 124)
                    
                    if let keyMsg = keyMessage {
                        Text(keyMsg)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(keyMsg.contains("✓") ? .green : .red)
                            .padding(.leading, 124)
                    }
                    
                    Divider().opacity(0.5)
                }
                
                // Campo de Senha/Passphrase
                formRow(icon: authSelection == 0 ? "key.fill" : "lock.rotation", color: .red, title: authSelection == 0 ? "Senha" : "Passphrase") {
                    SecureField(
                        authSelection == 0 ? "Senha do usuário" : "Passphrase da chave (opcional)",
                        text: $secretCredential
                    )
                    .textFieldStyle(.plain)
                }
                
                // Badge Informativo do Keychain
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                    
                    Text("Protegido por criptografia nativa no Apple Keychain")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
    
    private var footerView: some View {
        HStack(spacing: 12) {
            Button("Cancelar") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            if let host = hostToEdit {
                Button(role: .destructive) {
                    isPresentingDeleteAlert = true
                } label: {
                    Label("Excluir", systemImage: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .alert("Excluir Servidor?", isPresented: $isPresentingDeleteAlert) {
                    Button("Excluir", role: .destructive) {
                        viewModel.deleteHost(host)
                        dismiss()
                    }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Tem certeza de que deseja remover '\(host.name)'? Suas credenciais salvas no Keychain também serão removidas.")
                }
            }
            
            Spacer()
            
            Button {
                saveHost()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(hostToEdit == nil ? "Adicionar Host" : "Salvar Alterações")
                }
                .font(.system(size: 12, weight: .bold))
                .padding(.horizontal, 6)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || hostname.trimmingCharacters(in: .whitespaces).isEmpty || username.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Material.bar)
    }
    
    // MARK: - Helper Views & Functions
    
    @ViewBuilder
    private func formRow<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(width: 24, height: 24)
                
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            content()
        }
    }
    
    @ViewBuilder
    private func authOptionButton(title: String, icon: String, tag: Int) -> some View {
        let isSelected = authSelection == tag
        
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                authSelection = tag
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func populateIfEditing() {
        guard let host = hostToEdit else { return }
        name = host.name
        hostname = host.hostname
        portString = "\(host.port)"
        username = host.username
        selectedGroupId = host.groupId
        
        switch host.authMethod {
        case .password:
            authSelection = 0
        case .sshKey(let keyPath):
            authSelection = 1
            sshKeyPath = keyPath
        }
        
        if let existingSecret = KeychainManager.shared.readCredential(for: host.keychainAccountKey) {
            secretCredential = existingSecret
        }
    }
    
    private func saveHost() {
        let port = Int(portString) ?? 22
        let authMethod: AuthenticationMethod = (authSelection == 0)
            ? .password
            : .sshKey(keyPath: sshKeyPath)
        
        let keychainKey = hostToEdit?.keychainAccountKey ?? UUID().uuidString
        
        let newHost = Host(
            id: hostToEdit?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            hostname: hostname.trimmingCharacters(in: .whitespaces),
            port: port,
            username: username.trimmingCharacters(in: .whitespaces),
            authMethod: authMethod,
            groupId: selectedGroupId,
            keychainAccountKey: keychainKey,
            createdAt: hostToEdit?.createdAt ?? Date(),
            updatedAt: Date()
        )
        
        let secretToSave = secretCredential.isEmpty ? nil : secretCredential
        viewModel.addOrUpdateHost(newHost, secretCredential: secretToSave)
        dismiss()
    }
    
    private func selectKeyFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.showsHiddenFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            if path.hasPrefix(home) {
                sshKeyPath = "~" + path.dropFirst(home.count)
            } else {
                sshKeyPath = path
            }
        }
    }
    
    private func generateNewKey() {
        do {
            let keyFilename = "id_ed25519_sshdock_\(Int(Date().timeIntervalSince1970))"
            let (privPath, _) = try SSHKeyManagerService.shared.generateKeyPair(
                filename: keyFilename,
                type: "ed25519",
                passphrase: secretCredential
            )
            sshKeyPath = privPath
            keyMessage = "✓ Nova chave '\(keyFilename)' gerada com sucesso em ~/.ssh!"
        } catch {
            keyMessage = "❌ Erro: \(error.localizedDescription)"
        }
    }
    
    private func exportPublicKey() {
        let cleanHost = hostname.trimmingCharacters(in: .whitespaces)
        let cleanUser = username.trimmingCharacters(in: .whitespaces)
        guard !cleanHost.isEmpty && !cleanUser.isEmpty else { return }
        
        let pubPath = sshKeyPath.hasSuffix(".pub") ? sshKeyPath : "\(sshKeyPath).pub"
        let portInt = Int(portString) ?? 22
        let secret = secretCredential.isEmpty ? nil : secretCredential
        
        keyMessage = "⏳ Exportando chave pública para \(cleanUser)@\(cleanHost)..."
        
        Task {
            do {
                try await SSHKeyManagerService.shared.exportPublicKeyToRemoteHost(
                    publicKeyPath: pubPath,
                    hostname: cleanHost,
                    port: portInt,
                    username: cleanUser,
                    password: secret
                )
                await MainActor.run {
                    keyMessage = "✓ Chave pública exportada para \(cleanUser)@\(cleanHost) em authorized_keys!"
                }
            } catch {
                await MainActor.run {
                    keyMessage = "❌ Erro ao exportar: \(error.localizedDescription)"
                }
            }
        }
    }
}
