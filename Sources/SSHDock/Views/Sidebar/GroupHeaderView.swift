import SwiftUI

public struct GroupHeaderView: View {
    public let group: HostGroup
    public let onDelete: () -> Void
    
    public init(group: HostGroup, onDelete: @escaping () -> Void) {
        self.group = group
        self.onDelete = onDelete
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: group.iconName)
                .foregroundColor(Color(hex: group.colorHex))
                .font(.system(size: 13, weight: .semibold))
            
            Text(group.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Excluir Grupo", systemImage: "trash")
            }
        }
    }
}
