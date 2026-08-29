import AppKit
import Combine

public extension Notification.Name {
    static let terminalFontSizeChanged = Notification.Name("SSHDockTerminalFontSizeChanged")
}

public final class TerminalFontManager: ObservableObject {
    public static let shared = TerminalFontManager()
    
    public static let defaultFontSize: CGFloat = 13.0
    public static let minFontSize: CGFloat = 8.0
    public static let maxFontSize: CGFloat = 36.0
    
    private let fontSizeKey = "SSHDockTerminalFontSize"
    
    @Published public var fontSize: CGFloat {
        didSet {
            UserDefaults.standard.set(Double(fontSize), forKey: fontSizeKey)
            NotificationCenter.default.post(name: .terminalFontSizeChanged, object: fontSize)
        }
    }
    
    /// Lista de nomes de famílias de fontes Nerd Fonts conhecidas em ordem de preferência
    private let preferredNerdFonts = [
        "Hack Nerd Font",
        "HackNerdFontComplete-Regular",
        "MesloLGS NF",
        "MesloLGS Nerd Font",
        "JetBrainsMono Nerd Font",
        "JetBrainsMonoNF-Regular",
        "FiraCode Nerd Font",
        "FiraCodeNF-Reg",
        "Cascadia Code NF",
        "CascadiaMono NF",
        "SauceCodePro Nerd Font",
        "MonaspiceNe Nerd Font"
    ]
    
    private init() {
        let saved = UserDefaults.standard.double(forKey: fontSizeKey)
        if saved >= Double(Self.minFontSize) && saved <= Double(Self.maxFontSize) {
            self.fontSize = CGFloat(saved)
        } else {
            self.fontSize = Self.defaultFontSize
        }
    }
    
    /// Aumenta o tamanho da fonte do terminal (Zoom In)
    public func increaseFontSize() {
        fontSize = min(fontSize + 1.0, Self.maxFontSize)
    }
    
    /// Diminui o tamanho da fonte do terminal (Zoom Out)
    public func decreaseFontSize() {
        fontSize = max(fontSize - 1.0, Self.minFontSize)
    }
    
    /// Restaura o tamanho da fonte para o padrão de 13pt
    public func resetFontSize() {
        fontSize = Self.defaultFontSize
    }
    
    /// Retorna a melhor fonte para o terminal, priorizando Nerd Fonts instaladas
    public func getBestTerminalFont(size: CGFloat? = nil) -> NSFont {
        let targetSize = size ?? fontSize
        let fontManager = NSFontManager.shared
        let availableFamilies = fontManager.availableFontFamilies
        let availableFontNames = fontManager.availableFonts
        
        // 1. Procura por nome exato da família ou fonte
        for fontName in preferredNerdFonts {
            if availableFamilies.contains(fontName) || availableFontNames.contains(fontName) {
                if let font = NSFont(name: fontName, size: targetSize) {
                    return font
                }
            }
        }
        
        // 2. Busca qualquer fonte no sistema que contenha "Nerd" ou "NF" no nome
        for family in availableFamilies {
            if family.localizedCaseInsensitiveContains("Nerd") || family.localizedCaseInsensitiveContains("NF") {
                if let font = NSFont(name: family, size: targetSize) {
                    return font
                }
            }
        }
        
        // 3. Fallback para fonte monoespaçada do sistema macOS (SF Mono / Menlo)
        return NSFont.monospacedSystemFont(ofSize: targetSize, weight: .regular)
    }
}
