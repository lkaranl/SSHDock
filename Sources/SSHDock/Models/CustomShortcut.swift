import Foundation
import AppKit

public enum ShortcutModifier: String, Codable, CaseIterable, Hashable {
    case command = "Command"
    case option = "Option"
    case control = "Control"
    case shift = "Shift"
    
    public var symbol: String {
        switch self {
        case .command: return "⌘"
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        }
    }
    
    public var eventModifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .command: return .command
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        }
    }
}

public struct CustomShortcut: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var command: String
    public var key: String
    public var modifiers: [ShortcutModifier]
    public var autoExecute: Bool
    public var isEnabled: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        key: String,
        modifiers: [ShortcutModifier] = [.option],
        autoExecute: Bool = true,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.key = key.lowercased()
        self.modifiers = modifiers
        self.autoExecute = autoExecute
        self.isEnabled = isEnabled
    }
    
    /// Representação textual dos modificadores e da tecla (ex: "⌥ 1" ou "⌘ ⇧ K")
    public var displayKeyCombo: String {
        let modSymbols = modifiers.map { $0.symbol }.joined(separator: " ")
        let keyDisplay = key.uppercased()
        return modSymbols.isEmpty ? keyDisplay : "\(modSymbols) \(keyDisplay)"
    }
    
    /// Verifica se um evento de teclado do macOS corresponde a este atalho
    public func matches(event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        
        let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
        guard chars == key.lowercased() else { return false }
        
        let eventModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        var expectedFlags: NSEvent.ModifierFlags = []
        for mod in modifiers {
            expectedFlags.insert(mod.eventModifierFlag)
        }
        
        return eventModifiers == expectedFlags
    }
}
