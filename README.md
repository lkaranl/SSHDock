# SSHDock 🚀

O **SSHDock** é um gerenciador de sessões SSH nativo para macOS. Projetado com **SwiftUI** e **SwiftTerm**, ele oferece uma experiência moderna, minimalista e rápida para gerenciar e conectar a todos os seus servidores em um único lugar.

---

## 🛠️ Como Compilar e Construir o Projeto (Build)

### Pré-requisitos
- macOS 14.0 (Sonoma) ou superior
- Xcode 15+ ou ferramentas de linha de comando do Swift (`Swift 5.9+`)

### 1. Compilação via Linha de Comando (Swift Package Manager)
Para compilar o projeto diretamente no terminal:

```bash
swift build
```

Para gerar a versão otimizada de produção (Release):

```bash
swift build -c release
```
O binário executável será gerado em `.build/release/SSHDock`.

### 2. Abrir e Compilar no Xcode
Para desenvolver ou compilar utilizando a IDE nativa da Apple:
1. Abra a pasta do projeto no Xcode (`open Package.swift` ou abra a pasta no Xcode).
2. Selecione o target `SSHDock` no topo.
3. Pressione `⌘ + B` para compilar ou `⌘ + R` para executar.

---

## 📖 Como Usar (Guia Rápido)

O SSHDock foi pensado para ser extremamente simples e intuitivo no seu dia a dia:

### 1. Organizar e Adicionar Servidores
- **Criar um Grupo:** Na barra lateral, clique no botão **`+` (Novo Grupo)** para criar categorias organizadas (ex: *Home Lab*, *Cloud Production*, *Bancos de Dados*).
- **Adicionar um Servidor (Host):** Clique em **`Novo Host`**, preencha o Nome, IP/Host, Usuário, Porta e escolha o método de autenticação:
  - **Senha:** Digite a senha do servidor.
  - **Chave SSH:** Selecione o arquivo da sua chave privada (ex: `~/.ssh/id_rsa`).
  - *Sua senha ou passphrase é salva automaticamente de forma 100% segura no Apple Keychain.*

### 2. Abrir uma Sessão SSH
- Basta dar **duplo clique** sobre qualquer servidor na barra lateral (ou passar o mouse e clicar no ícone de terminal).
- O aplicativo abrirá a sessão em uma **nova aba** na área principal.
- Você pode manter **múltiplas conexões simultâneas** abertas e alternar entre elas clicando nas abas no topo do terminal.

### 3. Usar Snippets de Comandos Rápidos
- Acima da tela de terminal existe uma barra de **Snippets Rápidos**.
- Clicar em qualquer snippet (ex: `iniciar fish`, `systemctl status`, `docker ps`) injetará o comando instantaneamente no terminal ativo.
- Você pode criar seus próprios snippets clicando no botão **`+`** na barra de snippets.

---

## 🏗️ Como Funciona por Dentro

O SSHDock foi construído seguindo rigorosamente as **Apple Human Interface Guidelines (HIG)** e a arquitetura moderna do ecossistema Apple:

```
┌─────────────────────────────────────────────────────────────┐
│                        SSHDock                              │
├──────────────────────────────┬──────────────────────────────┤
│       Sidebar (SwiftUI)      │    Terminal Container View   │
│  - NavigationSplitView       │  - Tab System (Abas)         │
│  - Categorias / Grupos       │  - Snippets Quick Toolbar    │
│  - Busca reativa de hosts    │  - SwiftTerm (PTY Core)      │
└──────────────┬───────────────┴──────────────┬───────────────┘
               │                              │
               ▼                              ▼
    ┌────────────────────┐          ┌────────────────────┐
    │  Keychain Service  │          │   /usr/bin/ssh     │
    │ (Security.framework)          │  (Processo Nativo) │
    └────────────────────┘          └────────────────────┘
```

1. **Interface Nativa em SwiftUI (macOS 14+)**: Utiliza `NavigationSplitView` com fundo translúcido nativo (`Vibrancy`), suporte automático a **Dark Mode** e ícones do **SF Symbols**.
2. **Segurança Extrema com Apple Keychain**: Nenhuma credencial (senha ou passphrase) é armazenada em texto puro ou `UserDefaults`. O aplicativo faz chamadas diretas à `Security.framework` do macOS (`KeychainManager`) para persistir e recuperar segredos de forma criptografada.
3. **Motor de Terminal (SwiftTerm)**: O componente `SwiftTermView` adapta a biblioteca `SwiftTerm` para SwiftUI. Ele abre um pseudo-terminal (PTY) nativo do macOS executando o binário `/usr/bin/ssh`, garantindo compatibilidade total com comandos Unix, cores ANSI, zsh, bash e fish.
4. **Arquitetura MVVM (Model-View-ViewModel)**:
   - **Models**: `Host`, `HostGroup`, `Snippet`, `SSHSession`.
   - **Services**: `KeychainManager`, `StorageManager` (JSON local em `Application Support`).
   - **ViewModels**: `AppViewModel` (gerencia a árvore de hosts e estado global de abas) e `TerminalViewModel` (prepara argumentos do SSH e credenciais).
