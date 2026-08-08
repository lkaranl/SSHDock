import SwiftUI

public struct StatusBadge: View {
    public let state: ConnectionState
    
    public init(state: ConnectionState) {
        self.state = state
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: state.iconName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .symbolEffect(.pulse, isActive: state == .connecting)
            
            Text(state.statusTitle)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .cornerRadius(6)
    }
    
    private var color: Color {
        switch state {
        case .disconnected:
            return .secondary
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}
