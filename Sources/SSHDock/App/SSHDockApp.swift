import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Garante que o aplicativo SPM executado via terminal abra a janela e venha para o primeiro plano
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SSHDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Aumentar Fonte") {
                    TerminalFontManager.shared.increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: .command)
                
                Button("Aumentar Fonte (Alternativo)") {
                    TerminalFontManager.shared.increaseFontSize()
                }
                .keyboardShortcut("=", modifiers: .command)
                
                Button("Diminuir Fonte") {
                    TerminalFontManager.shared.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: .command)
                
                Button("Tamanho Padrão da Fonte") {
                    TerminalFontManager.shared.resetFontSize()
                }
                .keyboardShortcut("0", modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                Button("Atalhos de Teclado...") {
                    NotificationCenter.default.post(name: .openShortcutsManager, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
            }
        }
    }
}
