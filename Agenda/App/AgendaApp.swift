import SwiftUI

@main
struct AgendaApp: App {
    @State private var store = AgendaStore()

    var body: some Scene {
        WindowGroup {
            ListaAgendamentosView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .task { await Notificacoes.pedirPermissao() }
        }
    }
}
