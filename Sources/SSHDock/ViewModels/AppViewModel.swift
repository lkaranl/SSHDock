import Foundation
import Combine
import SwiftUI

public extension Notification.Name {
    static let openShortcutsManager = Notification.Name("SSHDockOpenShortcutsManager")
    static let openNewTab = Notification.Name("SSHDockOpenNewTab")
    static let closeCurrentTab = Notification.Name("SSHDockCloseCurrentTab")
}

public class AppViewModel: ObservableObject {
    @Published public var groups: [HostGroup] = []
    @Published public var hosts: [Host] = []
    @Published public var snippets: [Snippet] = []
    @Published public var customShortcuts: [CustomShortcut] = []
    
    @Published public var activeSessions: [SSHSession] = []
    @Published public var selectedSessionId: UUID?
    
    @Published public var selectedHostId: UUID?
    @Published public var selectedGroupId: UUID?
    @Published public var searchText: String = ""
    
    // State para modais
    @Published public var isPresentingHostForm: Bool = false
    @Published public var hostToEdit: Host? = nil
    @Published public var isPresentingGroupForm: Bool = false
    @Published public var isPresentingSnippetForm: Bool = false
    @Published public var isPresentingShortcutsSheet: Bool = false
    
    /// Mensagem de erro a ser exibida no alerta global da UI (nil = sem erro)
    @Published public var errorMessage: String? = nil
    
    private let storage = StorageManager.shared
    private let keychain = KeychainManager.shared
    
    /// Exibe um alerta com a mensagem de erro na UI
    public func presentError(_ message: String) {
        errorMessage = message
    }
    
    /// Exibe um alerta a partir de um erro (usa a LocalizedError, quando disponível)
    public func presentError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
    
    public init() {
        loadData()
        
        NotificationCenter.default.addObserver(
            forName: .openShortcutsManager,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isPresentingShortcutsSheet = true
        }
        
        NotificationCenter.default.addObserver(
            forName: .openNewTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openNewSessionForCurrentHost()
        }
        
        NotificationCenter.default.addObserver(
            forName: .closeCurrentTab,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.closeCurrentSession()
        }
    }
    
    public func loadData() {
        do {
            let loadedGroups = try storage.loadGroups()
            let loadedHosts = try storage.loadHosts()
            let loadedSnippets = try storage.loadSnippets()
            let loadedShortcuts = try storage.loadShortcuts()
            
            if loadedGroups.isEmpty && loadedHosts.isEmpty {
                // Inicializa com dados de demonstração
                self.groups = MockData.sampleGroups
                self.hosts = MockData.sampleHosts
                self.snippets = MockData.sampleSnippets
                self.customShortcuts = MockData.sampleShortcuts
                saveData()
            } else {
                self.groups = loadedGroups
                self.hosts = loadedHosts
                self.snippets = loadedSnippets.isEmpty ? MockData.sampleSnippets : loadedSnippets
                self.customShortcuts = loadedShortcuts.isEmpty ? MockData.sampleShortcuts : loadedShortcuts
            }
        } catch let error as StorageError {
            switch error {
            case .decodingFailed, .encodingFailed:
                // Arquivo corrompido: NÃO sobrescreve (preserva os dados para
                // possível recuperação manual). Avisa o usuário e usa dados em memória.
                presentError(error)
            case .readFailed, .writeFailed:
                // Arquivo inexistente é o caso normal do primeiro launch:
                // inicializa com dados de demonstração
                self.groups = MockData.sampleGroups
                self.hosts = MockData.sampleHosts
                self.snippets = MockData.sampleSnippets
                self.customShortcuts = MockData.sampleShortcuts
                saveData()
            }
        } catch {
            presentError(error)
            self.groups = []
            self.hosts = []
            self.snippets = []
            self.customShortcuts = []
        }
        
        // Verifica integridade: referências de grupos órfãs e credenciais
        // do Keychain sem host correspondente
        sanitizeData()
    }
    
    // MARK: - Integridade dos Dados
    
    /// Corrige referências órfãs após o carregamento:
    /// 1. Hosts apontando para grupos inexistentes → desvincula o grupo
    /// 2. Credenciais no Keychain sem host correspondente → remove do Keychain
    private func sanitizeData() {
        var correctedGroupRefs = 0
        var removedCredentials = 0
        
        // 1. Hosts com groupId inexistente (grupo deletado fora do fluxo normal,
        //    arquivo editado manualmente, restauração de backup parcial etc.)
        let validGroupIds = Set(groups.map { $0.id })
        for i in hosts.indices {
            if let gid = hosts[i].groupId, !validGroupIds.contains(gid) {
                hosts[i].groupId = nil
                correctedGroupRefs += 1
            }
        }
        if correctedGroupRefs > 0 {
            saveData()
        }
        
        // 2. Credenciais órfãs no Keychain (host deletado sem limpeza,
        //    app encerrado no meio de uma deleção, etc.)
        let validAccounts = Set(hosts.map { $0.keychainAccountKey })
        removedCredentials = keychain.deleteOrphanCredentials(keeping: validAccounts)
        
        if correctedGroupRefs > 0 || removedCredentials > 0 {
            print("[SSHDock] Sanitização: \(correctedGroupRefs) referência(s) de grupo corrigida(s), \(removedCredentials) credencial(is) órfã(s) removida(s).")
        }
    }
    
    public func saveData() {
        do {
            try storage.saveGroups(groups)
            try storage.saveHosts(hosts)
            try storage.saveSnippets(snippets)
            try storage.saveShortcuts(customShortcuts)
        } catch {
            presentError(error)
        }
    }
    
    // MARK: - Gestão de Hosts
    public func addOrUpdateHost(_ host: Host, secretCredential: String?) {
        do {
            if let secret = secretCredential, !secret.isEmpty {
                try keychain.saveCredential(secret: secret, for: host.keychainAccountKey)
            }
        } catch {
            presentError("Não foi possível salvar a credencial no Keychain: \(error.localizedDescription)")
            return
        }
        
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        saveData()
    }
    
    /// Remove a credencial de um host do Keychain (ex.: migração para modo Agente SSH)
    public func removeHostCredential(for host: Host) {
        do {
            try keychain.deleteCredential(for: host.keychainAccountKey)
        } catch {
            presentError("Não foi possível remover a credencial do Keychain: \(error.localizedDescription)")
        }
    }
    
    public func deleteHost(_ host: Host) {
        hosts.removeAll { $0.id == host.id }
        do {
            try keychain.deleteCredential(for: host.keychainAccountKey)
        } catch {
            presentError("Não foi possível remover a credencial do Keychain: \(error.localizedDescription)")
        }
        saveData()
        
        // Fecha sessões ativas deste host se houver
        activeSessions.removeAll { $0.host.id == host.id }
        if selectedSessionId == nil, let first = activeSessions.first {
            selectedSessionId = first.id
        }
    }
    
    // MARK: - Gestão de Grupos
    public func addGroup(_ group: HostGroup) {
        groups.append(group)
        saveData()
    }
    
    public func deleteGroup(_ group: HostGroup) {
        groups.removeAll { $0.id == group.id }
        // Desvincula hosts deste grupo
        for i in 0..<hosts.count {
            if hosts[i].groupId == group.id {
                hosts[i].groupId = nil
            }
        }
        saveData()
    }
    
    // MARK: - Gestão de Snippets
    public func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveData()
    }
    
    public func deleteSnippet(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        saveData()
    }
    
    // MARK: - Gestão de Atalhos Customizados
    public func addCustomShortcut(_ shortcut: CustomShortcut) {
        customShortcuts.append(shortcut)
        saveData()
    }
    
    public func updateCustomShortcut(_ shortcut: CustomShortcut) {
        if let index = customShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            customShortcuts[index] = shortcut
            saveData()
        }
    }
    
    public func deleteCustomShortcut(_ shortcut: CustomShortcut) {
        customShortcuts.removeAll { $0.id == shortcut.id }
        saveData()
    }
    
    public func toggleCustomShortcut(_ shortcut: CustomShortcut) {
        if let index = customShortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            customShortcuts[index].isEnabled.toggle()
            saveData()
        }
    }
    
    // MARK: - Controle de Sessões SSH / Abas
    
    /// Retorna as sessões ativas agrupadas por Host mantendo a ordem de abertura
    public var groupedActiveSessions: [(host: Host, sessions: [SSHSession])] {
        var result: [(host: Host, sessions: [SSHSession])] = []
        var hostOrder: [UUID] = []
        var dict: [UUID: (Host, [SSHSession])] = [:]
        
        for session in activeSessions {
            let hostId = session.host.id
            if dict[hostId] == nil {
                dict[hostId] = (session.host, [session])
                hostOrder.append(hostId)
            } else {
                dict[hostId]?.1.append(session)
            }
        }
        
        for id in hostOrder {
            if let entry = dict[id] {
                result.append(entry)
            }
        }
        
        return result
    }
    
    public func openSession(for host: Host, forceNew: Bool = false) {
        let existingSessions = activeSessions.filter { $0.host.id == host.id }
        
        if !forceNew && !existingSessions.isEmpty {
            // Se não for forçada nova aba e já houver sessões deste host, seleciona a ativa ou a última
            if let currentSelected = selectedSessionId, existingSessions.contains(where: { $0.id == currentSelected }) {
                return
            }
            selectedSessionId = existingSessions.last?.id
            return
        }
        
        let sessionIndex = existingSessions.count + 1
        let title = existingSessions.isEmpty ? host.name : "\(host.name) #\(sessionIndex)"
        
        let newSession = SSHSession(host: host, title: title, state: .connecting)
        activeSessions.append(newSession)
        selectedSessionId = newSession.id
    }
    
    public func openNewSessionForCurrentHost() {
        guard let currentId = selectedSessionId,
              let currentSession = activeSessions.first(where: { $0.id == currentId }) else {
            if let firstHost = hosts.first {
                openSession(for: firstHost, forceNew: true)
            }
            return
        }
        openSession(for: currentSession.host, forceNew: true)
    }
    
    public func closeCurrentSession() {
        guard let currentId = selectedSessionId else { return }
        closeSession(id: currentId)
    }
    
    public func closeSession(id: UUID) {
        activeSessions.removeAll { $0.id == id }
        if selectedSessionId == id {
            selectedSessionId = activeSessions.last?.id
        }
    }
    
    public func closeAllSessionsForHost(hostId: UUID) {
        activeSessions.removeAll { $0.host.id == hostId }
        if let currentId = selectedSessionId, !activeSessions.contains(where: { $0.id == currentId }) {
            selectedSessionId = activeSessions.last?.id
        }
    }
    
    public func updateSessionState(id: UUID, state: ConnectionState) {
        if let index = activeSessions.firstIndex(where: { $0.id == id }) {
            activeSessions[index].state = state
        }
    }
    
    /// Reconecta uma sessão que falhou: encerra o processo antigo e abre um novo
    /// (novo ID força a criação de um novo PTY/Processo SSH), mantendo a posição da aba.
    public func reconnectSession(id: UUID) {
        guard let index = activeSessions.firstIndex(where: { $0.id == id }) else { return }
        let host = activeSessions[index].host
        let title = activeSessions[index].title
        
        let newSession = SSHSession(host: host, title: title, state: .connecting)
        activeSessions[index] = newSession
        selectedSessionId = newSession.id
    }
    
    // MARK: - Filtros
    public var filteredHosts: [Host] {
        if searchText.isEmpty {
            return hosts
        }
        return hosts.filter { host in
            host.name.localizedCaseInsensitiveContains(searchText) ||
            host.hostname.localizedCaseInsensitiveContains(searchText) ||
            host.username.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    public func hostsForGroup(_ groupId: UUID?) -> [Host] {
        filteredHosts.filter { $0.groupId == groupId }
    }
    
    public var unassignedHosts: [Host] {
        filteredHosts.filter { $0.groupId == nil }
    }
}
