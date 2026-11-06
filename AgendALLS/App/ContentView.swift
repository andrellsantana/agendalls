import SwiftUI

/// Os mini apps da suíte. Só os marcados como disponíveis já funcionam nesta versão.
enum MiniApp: String, CaseIterable, Identifiable {
    case ponto, tarefas, links, cadastro, remedios, senhas

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .ponto: "Ponto"
        case .tarefas: "Tarefas"
        case .links: "Links"
        case .cadastro: "Cadastro"
        case .remedios: "Remédios"
        case .senhas: "Senhas"
        }
    }

    var icone: String {
        switch self {
        case .ponto: "clock"
        case .tarefas: "checklist"
        case .links: "square.grid.2x2"
        case .cadastro: "person.text.rectangle"
        case .remedios: "pills"
        case .senhas: "lock"
        }
    }

    var disponivel: Bool { [.ponto, .tarefas, .links, .cadastro].contains(self) }
}

struct ContentView: View {
    @State private var selecao: MiniApp? = .ponto

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                List(selection: $selecao) {
                    Section("Mini apps") {
                        ForEach(MiniApp.allCases) { app in
                            Label(app.nome, systemImage: app.icone)
                                .foregroundStyle(app.disponivel ? .primary : .secondary)
                                .tag(app)
                        }
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
            } detail: {
                Group {
                    switch selecao {
                    case .ponto?:
                        PontoView()
                    case .tarefas?:
                        TarefasView()
                    case .links?:
                        LinksView()
                    case .cadastro?:
                        CadastroView()
                    case let app?:
                        EmBreveView(app: app)
                    case nil:
                        ContentUnavailableView("Escolha um mini app", systemImage: "sidebar.left")
                    }
                }
                .navigationTitle(selecao?.nome ?? Versao.nome)
            }
            Rodape()
        }
    }
}

private struct EmBreveView: View {
    let app: MiniApp

    var body: some View {
        ContentUnavailableView {
            Label(app.nome, systemImage: app.icone)
        } description: {
            Text("Este mini app chega numa próxima versão.")
        }
    }
}
