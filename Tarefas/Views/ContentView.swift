import SwiftUI

enum Modo: String, CaseIterable, Identifiable {
    case lista = "Lista", mesa = "Mesa"
    var id: Self { self }
    var icone: String { self == .lista ? "list.number" : "rectangle.on.rectangle.angled" }
}

struct ContentView: View {
    @Environment(TarefasStore.self) private var store
    @AppStorage("modo") private var modo: Modo = .lista
    @State private var editando: Tarefa?

    var body: some View {
        @Bindable var store = store
        Group {
            switch modo {
            case .lista: ListaView(editando: $editando)
            case .mesa:  MesaView(editando: $editando)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Visualização", selection: $modo) {
                    ForEach(Modo.allCases) { Label($0.rawValue, systemImage: $0.icone).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItem(placement: .primaryAction) {
                Button { store.pedidoNovaTarefa = true } label: { Label("Nova tarefa", systemImage: "plus") }
            }
        }
        .sheet(isPresented: $store.pedidoNovaTarefa) {
            EditorTarefaView(tarefa: Tarefa(id: nil, titulo: ""))
        }
        .sheet(item: $editando) { EditorTarefaView(tarefa: $0) }
        .alert("Erro", isPresented: .constant(store.erro != nil)) {
            Button("OK") { store.erro = nil }
        } message: { Text(store.erro ?? "") }
    }
}
