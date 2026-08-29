import Foundation

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
    
    // MARK: - Hosts
    public func loadHosts() -> [Host] {
        guard let data = try? Data(contentsOf: hostsFileURL),
              let hosts = try? JSONDecoder().decode([Host].self, from: data) else {
            return []
        }
        return hosts
    }
    
    public func saveHosts(_ hosts: [Host]) {
        if let data = try? JSONEncoder().encode(hosts) {
            try? data.write(to: hostsFileURL, options: .atomic)
        }
    }
    
    // MARK: - Groups
    public func loadGroups() -> [HostGroup] {
        guard let data = try? Data(contentsOf: groupsFileURL),
              let groups = try? JSONDecoder().decode([HostGroup].self, from: data) else {
            return []
        }
        return groups
    }
    
    public func saveGroups(_ groups: [HostGroup]) {
        if let data = try? JSONEncoder().encode(groups) {
            try? data.write(to: groupsFileURL, options: .atomic)
        }
    }
    
    // MARK: - Snippets
    public func loadSnippets() -> [Snippet] {
        guard let data = try? Data(contentsOf: snippetsFileURL),
              let snippets = try? JSONDecoder().decode([Snippet].self, from: data) else {
            return []
        }
        return snippets
    }
    
    public func saveSnippets(_ snippets: [Snippet]) {
        if let data = try? JSONEncoder().encode(snippets) {
            try? data.write(to: snippetsFileURL, options: .atomic)
        }
    }
    
    // MARK: - Custom Shortcuts
    public func loadShortcuts() -> [CustomShortcut] {
        guard let data = try? Data(contentsOf: shortcutsFileURL),
              let shortcuts = try? JSONDecoder().decode([CustomShortcut].self, from: data) else {
            return []
        }
        return shortcuts
    }
    
    public func saveShortcuts(_ shortcuts: [CustomShortcut]) {
        if let data = try? JSONEncoder().encode(shortcuts) {
            try? data.write(to: shortcutsFileURL, options: .atomic)
        }
    }
}
