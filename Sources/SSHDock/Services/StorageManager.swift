import Foundation

/// Erros de persistência com mensagens prontas para exibição ao usuário.
public enum StorageError: Error, LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case writeFailed(String, underlying: Error)
    case readFailed(String, underlying: Error)
    
    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let file):
            return "Não foi possível codificar os dados de \"\(file)\" para salvar."
        case .decodingFailed(let file):
            return "Não foi possível ler os dados de \"\(file)\" (arquivo corrompido ou em formato incompatível)."
        case .writeFailed(let file, let underlying):
            return "Falha ao salvar \"\(file)\": \(underlying.localizedDescription)"
        case .readFailed(let file, let underlying):
            return "Falha ao ler \"\(file)\": \(underlying.localizedDescription)"
        }
    }
}

public class StorageManager {
    public static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let appFolderURL: URL
    
    private let hostsFileURL: URL
    private let groupsFileURL: URL
    private let snippetsFileURL: URL
    private let shortcutsFileURL: URL
    
    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appFolderURL = appSupport.appendingPathComponent("SSHDock", isDirectory: true)
        
        if !fileManager.fileExists(atPath: appFolderURL.path) {
            try? fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        }
        
        hostsFileURL = appFolderURL.appendingPathComponent("hosts.json")
        groupsFileURL = appFolderURL.appendingPathComponent("groups.json")
        snippetsFileURL = appFolderURL.appendingPathComponent("snippets.json")
        shortcutsFileURL = appFolderURL.appendingPathComponent("shortcuts.json")
    }
    
    // MARK: - Genéricos (com tratamento de erro)
    
    private func load<T: Decodable>(_ url: URL, as type: T.Type, fileLabel: String) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw StorageError.decodingFailed(fileLabel)
        } catch {
            throw StorageError.readFailed(fileLabel, underlying: error)
        }
    }
    
    private func save<T: Encodable>(_ value: T, to url: URL, fileLabel: String) throws {
        do {
            let data = try JSONEncoder().encode(value)
            try data.write(to: url, options: .atomic)
        } catch let error as EncodingError {
            throw StorageError.encodingFailed(fileLabel)
        } catch {
            throw StorageError.writeFailed(fileLabel, underlying: error)
        }
    }
    
    // MARK: - Hosts
    public func loadHosts() throws -> [Host] {
        try load(hostsFileURL, as: [Host].self, fileLabel: "hosts")
    }
    
    public func saveHosts(_ hosts: [Host]) throws {
        try save(hosts, to: hostsFileURL, fileLabel: "hosts")
    }
    
    // MARK: - Groups
    public func loadGroups() throws -> [HostGroup] {
        try load(groupsFileURL, as: [HostGroup].self, fileLabel: "grupos")
    }
    
    public func saveGroups(_ groups: [HostGroup]) throws {
        try save(groups, to: groupsFileURL, fileLabel: "grupos")
    }
    
    // MARK: - Snippets
    public func loadSnippets() throws -> [Snippet] {
        try load(snippetsFileURL, as: [Snippet].self, fileLabel: "snippets")
    }
    
    public func saveSnippets(_ snippets: [Snippet]) throws {
        try save(snippets, to: snippetsFileURL, fileLabel: "snippets")
    }
    
    // MARK: - Custom Shortcuts
    public func loadShortcuts() throws -> [CustomShortcut] {
        try load(shortcutsFileURL, as: [CustomShortcut].self, fileLabel: "atalhos")
    }
    
    public func saveShortcuts(_ shortcuts: [CustomShortcut]) throws {
        try save(shortcuts, to: shortcutsFileURL, fileLabel: "atalhos")
    }
    
    // MARK: - Wrappers seguros (para call sites onde não há UI para reportar erro)
    
    /// Versão não-throwing para uso em contexts sensíveis a performance/teclado.
    public func safeLoadShortcuts() -> [CustomShortcut] {
        (try? loadShortcuts()) ?? []
    }
}
