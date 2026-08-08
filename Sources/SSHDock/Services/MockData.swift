import Foundation

public struct MockData {
    public static let sampleGroups: [HostGroup] = [
        HostGroup(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Home Lab", iconName: "house.fill", colorHex: "#FF9500"),
        HostGroup(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Cloud Production", iconName: "cloud.fill", colorHex: "#007AFF"),
        HostGroup(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Bancos de Dados", iconName: "externaldrive.fill", colorHex: "#34C759")
    ]
    
    public static let sampleHosts: [Host] = [
        Host(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            name: "Raspberry Pi Cluster Primary",
            hostname: "192.168.1.100",
            port: 22,
            username: "pi",
            authMethod: .password,
            groupId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        ),
        Host(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            name: "Media Server (Jellyfin)",
            hostname: "192.168.1.150",
            port: 2222,
            username: "admin",
            authMethod: .sshKey(keyPath: "~/.ssh/id_ed25519"),
            groupId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        ),
        Host(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            name: "AWS Web App Gateway",
            hostname: "ec2-54-209-12-88.compute-1.amazonaws.com",
            port: 22,
            username: "ubuntu",
            authMethod: .sshKey(keyPath: "~/.ssh/aws_prod.pem"),
            groupId: UUID(uuidString: "22222222-2222-2222-2222-222222222222")
        ),
        Host(
            id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
            name: "PostgreSQL Primary Node",
            hostname: "db.internal.corp",
            port: 22,
            username: "postgres",
            authMethod: .password,
            groupId: UUID(uuidString: "33333333-3333-3333-3333-333333333333")
        )
    ]
    
    public static let sampleSnippets: [Snippet] = [
        Snippet(name: "Iniciar Fish Shell", command: "exec fish", iconName: "terminal.fill"),
        Snippet(name: "Status do Sistema", command: "systemctl status", iconName: "activity", autoExecute: false),
        Snippet(name: "Containers Docker", command: "docker ps -a", iconName: "shippingbox.fill"),
        Snippet(name: "Uso de Disco", command: "df -h", iconName: "chart.bar.fill"),
        Snippet(name: "Logs do Kernel", command: "sudo dmesg -T | tail -n 50", iconName: "list.bullet.rectangle.fill", autoExecute: false),
        Snippet(name: "Uso de Memória", command: "free -h", iconName: "memorychip")
    ]
}
