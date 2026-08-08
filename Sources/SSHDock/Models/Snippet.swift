import Foundation

public struct Snippet: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var command: String
    public var iconName: String
    public var autoExecute: Bool
    
    public init(
        id: UUID = UUID(),
        name: String,
        command: String,
        iconName: String = "terminal.fill",
        autoExecute: Bool = true
    ) {
        self.id = id
        self.name = name
        self.command = command
        self.iconName = iconName
        self.autoExecute = autoExecute
    }
}
