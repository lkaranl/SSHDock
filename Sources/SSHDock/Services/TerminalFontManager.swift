import AppKit

public final class TerminalFontManager {
    public static let shared = TerminalFontManager()
    
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
    
    private init() {}
    
    /// Retorna a melhor fonte para o terminal, priorizando Nerd Fonts instaladas
    public func getBestTerminalFont(size: CGFloat = 13.0) -> NSFont {
        let fontManager = NSFontManager.shared
        let availableFamilies = fontManager.availableFontFamilies
        let availableFontNames = fontManager.availableFonts
        
        // 1. Procura por nome exato da família ou fonte
        for fontName in preferredNerdFonts {
            if availableFamilies.contains(fontName) || availableFontNames.contains(fontName) {
                if let font = NSFont(name: fontName, size: size) {
                    return font
                }
            }
        }
        
        // 2. Busca qualquer fonte no sistema que contenha "Nerd" ou "NF" no nome
        for family in availableFamilies {
            if family.localizedCaseInsensitiveContains("Nerd") || family.localizedCaseInsensitiveContains("NF") {
                if let font = NSFont(name: family, size: size) {
                    return font
                }
            }
        }
        
        // 3. Fallback para fonte monoespaçada do sistema macOS (SF Mono / Menlo)
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
