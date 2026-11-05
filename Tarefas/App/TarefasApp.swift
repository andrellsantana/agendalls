import SwiftUI

@main
struct TarefasApp: App {
    @State private var store = TarefasStore()

    var body: some Scene {
        WindowGroup("Tarefas") {
            ContentView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "pt_BR"))
                .frame(minWidth: 720, minHeight: 480)
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nova tarefa") { store.pedidoNovaTarefa = true }
                    .keyboardShortcut("n")
            }
        }
    }
}
