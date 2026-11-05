import SwiftUI

struct EditorTarefaView: View {
    @Environment(TarefasStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var tarefa: Tarefa

    private var tituloValido: Bool { !tarefa.titulo.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tarefa.id == nil ? "Nova tarefa" : "Editar tarefa").font(.title2.bold())
            Form {
                TextField("Título", text: $tarefa.titulo)
                TextField("Anotações", text: $tarefa.notas, axis: .vertical)
                    .lineLimit(4...10)
                if tarefa.id != nil {
                    Toggle("Concluída", isOn: $tarefa.concluida)
                }
            }
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    if tarefa.id == nil {
                        store.adicionar(titulo: tarefa.titulo, notas: tarefa.notas)
                    } else {
                        store.atualizar(tarefa)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!tituloValido)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}
