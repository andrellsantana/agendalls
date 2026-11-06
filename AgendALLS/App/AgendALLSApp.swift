import SwiftUI

@main
struct AgendALLSApp: App {
    @State private var ponto = PontoStore()
    @State private var tarefas = TarefasStore()
    @State private var links = LinksStore()

    var body: some Scene {
        WindowGroup("AgendALLS") {
            ContentView()
                .environment(ponto)
                .environment(tarefas)
                .environment(links)
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
