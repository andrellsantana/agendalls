import SwiftUI

struct ListaView: View {
    @Environment(TarefasStore.self) private var store
    @Binding var editando: Tarefa?

    var body: some View {
        if store.tarefas.isEmpty {
            ContentUnavailableView("Nenhuma tarefa", systemImage: "checklist",
                                   description: Text("Clique em + ou use ⌘N para criar uma tarefa."))
        } else {
            List {
                ForEach(store.tarefas) { tarefa in
                    LinhaTarefa(tarefa: tarefa, prioridade: store.prioridade(de: tarefa))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) { editando = tarefa }
                        .contextMenu {
                            Button("Editar…") { editando = tarefa }
                            Divider()
                            Button("Excluir", role: .destructive) { store.excluir(tarefa) }
                        }
                }
                .onMove { store.mover(de: $0, para: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }
}

private struct LinhaTarefa: View {
    @Environment(TarefasStore.self) private var store
    let tarefa: Tarefa
    let prioridade: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Arraste para mudar a prioridade")
            Text("\(prioridade)")
                .font(.callout.monospacedDigit().bold())
                .frame(width: 26, height: 22)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
            Toggle("", isOn: Binding(
                get: { tarefa.concluida },
                set: { var t = tarefa; t.concluida = $0; store.atualizar(t) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(tarefa.titulo)
                    .strikethrough(tarefa.concluida)
                    .foregroundStyle(tarefa.concluida ? .secondary : .primary)
                if !tarefa.notas.isEmpty {
                    Text(tarefa.notas).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
