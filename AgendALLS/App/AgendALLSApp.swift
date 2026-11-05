import SwiftUI

@main
struct AgendALLSApp: App {
    @State private var ponto = PontoStore()

    var body: some Scene {
        WindowGroup("AgendALLS") {
            ContentView()
                .environment(ponto)
                .frame(minWidth: 960, minHeight: 640)
                .task { await AlarmeManager.pedirPermissaoDeNotificacao() }
        }
        .defaultSize(width: 1180, height: 760)

        Settings {
            ConfiguracoesView()
                .environment(ponto)
        }
    }
}
