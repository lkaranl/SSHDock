import Foundation

public struct HostGroup: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#007AFF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.createdAt = createdAt
    }
}
