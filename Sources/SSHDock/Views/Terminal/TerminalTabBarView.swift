import SwiftUI

public struct TerminalTabBarView: View {
    @ObservedObject var viewModel: AppViewModel
    
    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.groupedActiveSessions, id: \.host.id) { group in
                    let host = group.host
                    let sessions = group.sessions
                    
                    if sessions.count == 1, let session = sessions.first {
                        // Aba Individual Simples
                        singleTab(host: host, session: session)
                    } else {
                        // Grupo de Abas Múltiplas do mesmo Host
                        groupedTabs(host: host, sessions: sessions)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .background(Material.bar)
    }
    
    // MARK: - Aba Única
    private func singleTab(host: Host, session: SSHSession) -> some View {
        let isSelected = viewModel.selectedSessionId == session.id
        
        return HStack(spacing: 6) {
            Image(systemName: session.state.iconName)
                .font(.system(size: 10))
                .foregroundColor(statusColor(for: session.state))
            
            Text(host.name)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .lineLimit(1)
            
            // Botão Adicionar outra aba neste Host
            Button {
                viewModel.openSession(for: host, forceNew: true)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Nova aba em \(host.name) (⌘ T)")
            
            // Botão Fechar Sessão
            Button {
                viewModel.closeSession(id: session.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(2)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Fechar Sessão (⌘ W)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isSelected ? Color(NSColor.windowBackgroundColor) : Color.primary.opacity(0.04))
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .overlay(
            RoundedCornerShape(radius: 6, corners: [.topLeft, .topRight])
                .stroke(isSelected ? Color.primary.opacity(0.1) : Color.clear, lineWidth: 1)
        )
        .onTapGesture {
            viewModel.selectedSessionId = session.id
        }
        .contextMenu {
            Button {
                viewModel.openSession(for: host, forceNew: true)
            } label: {
                Label("Nova Aba em \(host.name)", systemImage: "plus")
            }
            Divider()
            Button(role: .destructive) {
                viewModel.closeSession(id: session.id)
            } label: {
                Label("Fechar Aba", systemImage: "xmark")
            }
        }
    }
    
    // MARK: - Grupo de Abas do Host
    private func groupedTabs(host: Host, sessions: [SSHSession]) -> some View {
        let isAnySelected = sessions.contains(where: { $0.id == viewModel.selectedSessionId })
        
        return HStack(spacing: 4) {
            // Cabeçalho do Grupo do Servidor
            HStack(spacing: 4) {
                Image(systemName: "server.rack")
                    .font(.system(size: 9))
                    .foregroundColor(.accentColor)
                
                Text(host.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Button {
                    viewModel.openSession(for: host, forceNew: true)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.accentColor)
                        .padding(2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Nova aba em \(host.name) (⌘ T)")
            }
            .padding(.leading, 6)
            .padding(.trailing, 2)
            
            // Sub-abas numeradas (#1, #2, #3...)
            ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                let isSelected = viewModel.selectedSessionId == session.id
                
                HStack(spacing: 4) {
                    Image(systemName: session.state.iconName)
                        .font(.system(size: 8))
                        .foregroundColor(statusColor(for: session.state))
                    
                    Text("#\(index + 1)")
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .primary : .secondary)
                    
                    Button {
                        viewModel.closeSession(id: session.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Fechar Aba #\(index + 1)")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isSelected ? Color(NSColor.windowBackgroundColor) : Color.primary.opacity(0.06))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .onTapGesture {
                    viewModel.selectedSessionId = session.id
                }
                .contextMenu {
                    Button {
                        viewModel.openSession(for: host, forceNew: true)
                    } label: {
                        Label("Nova Aba neste Servidor", systemImage: "plus")
                    }
                    Divider()
                    Button(role: .destructive) {
                        viewModel.closeSession(id: session.id)
                    } label: {
                        Label("Fechar Aba #\(index + 1)", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        viewModel.closeAllSessionsForHost(hostId: host.id)
                    } label: {
                        Label("Fechar Todas as Abas de \(host.name)", systemImage: "xmark.circle")
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(isAnySelected ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
        .cornerRadius(6, corners: [.topLeft, .topRight])
        .overlay(
            RoundedCornerShape(radius: 6, corners: [.topLeft, .topRight])
                .stroke(isAnySelected ? Color.primary.opacity(0.15) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func statusColor(for state: ConnectionState) -> Color {
        switch state {
        case .disconnected: return .secondary
        case .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
}

// Extensão utilitária para arrendondamento de cantos específicos no SwiftUI
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = NSBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadius: radius)
        return Path(path.cgPath)
    }
}

extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo, .cubicCurveTo:
                path.addCurve(to: points[0], control1: points[1], control2: points[2])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[0], control: points[1])
            case .closePath:
                path.closeSubpath()
            @unknown default:
                break
            }
        }
        return path
    }
}

struct RectCorner: OptionSet {
    let rawValue: Int
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

extension NSBezierPath {
    convenience init(roundedRect rect: CGRect, byRoundingCorners corners: RectCorner, cornerRadius: CGFloat) {
        self.init()
        let topLeft = corners.contains(.topLeft)
        let topRight = corners.contains(.topRight)
        let bottomLeft = corners.contains(.bottomLeft)
        let bottomRight = corners.contains(.bottomRight)
        
        let minX = rect.minX
        let minY = rect.minY
        let maxX = rect.maxX
        let maxY = rect.maxY
        
        move(to: CGPoint(x: minX + (topLeft ? cornerRadius : 0), y: maxY))
        
        if topRight {
            line(to: CGPoint(x: maxX - cornerRadius, y: maxY))
            curve(to: CGPoint(x: maxX, y: maxY - cornerRadius), controlPoint1: CGPoint(x: maxX, y: maxY), controlPoint2: CGPoint(x: maxX, y: maxY - cornerRadius))
        } else {
            line(to: CGPoint(x: maxX, y: maxY))
        }
        
        if bottomRight {
            line(to: CGPoint(x: maxX, y: minY + cornerRadius))
            curve(to: CGPoint(x: maxX - cornerRadius, y: minY), controlPoint1: CGPoint(x: maxX, y: minY), controlPoint2: CGPoint(x: maxX - cornerRadius, y: minY))
        } else {
            line(to: CGPoint(x: maxX, y: minY))
        }
        
        if bottomLeft {
            line(to: CGPoint(x: minX + cornerRadius, y: minY))
            curve(to: CGPoint(x: minX, y: minY + cornerRadius), controlPoint1: CGPoint(x: minX, y: minY), controlPoint2: CGPoint(x: minX, y: minY + cornerRadius))
        } else {
            line(to: CGPoint(x: minX, y: minY))
        }
        
        if topLeft {
            line(to: CGPoint(x: minX, y: maxY - cornerRadius))
            curve(to: CGPoint(x: minX + cornerRadius, y: maxY), controlPoint1: CGPoint(x: minX, y: maxY), controlPoint2: CGPoint(x: minX + cornerRadius, y: maxY))
        } else {
            line(to: CGPoint(x: minX, y: maxY))
        }
        close()
    }
}
