import SwiftUI

@main
struct AgendALLSApp: App {
    @State private var ponto = PontoStore()
    @State private var tarefas = TarefasStore()
    @State private var links = LinksStore()
    @State private var remedios = RemediosStore()
    @State private var cofre: Cofre
    @State private var cadastro: CadastroStore

    init() {
        let cofre = Cofre()
        let cadastro = CadastroStore()
        // Ao trancar, os dados sensíveis saem da memória.
        cofre.aoTrancar.append { [weak cadastro] in cadastro?.descarregar() }
        _cofre = State(initialValue: cofre)
        _cadastro = State(initialValue: cadastro)
    }

    var body: some Scene {
        WindowGroup("AgendALLS") {
            ContentView()
                .environment(ponto)
                .environment(tarefas)
                .environment(links)
                .environment(cofre)
                .environment(cadastro)
                .environment(remedios)
                .frame(minWidth: 960, minHeight: 640)
                .task { await AlarmeManager.pedirPermissaoDeNotificacao() }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            // ⌘N cria uma nova tarefa em vez de abrir outra janela.
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            ConfiguracoesView()
                .environment(ponto)
                .environment(links)
        }
    }
}
