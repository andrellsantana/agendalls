import SwiftUI

struct ListaAgendamentosView: View {
    @Environment(AgendaStore.self) private var store
    @State private var editando: Agendamento?

    var body: some View {
        NavigationStack {
            Group {
                if store.agendamentos.isEmpty {
                    ContentUnavailableView("Nenhum agendamento", systemImage: "calendar",
                                           description: Text("Toque em + para criar o primeiro."))
                } else {
                    List {
                        ForEach(store.porDia, id: \.dia) { grupo in
                            Section(grupo.dia.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                                ForEach(grupo.itens) { item in
                                    Button { editando = item } label: { LinhaAgendamento(item: item) }
                                        .tint(.primary)
                                        .swipeActions {
                                            Button("Excluir", role: .destructive) { store.excluir(item) }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Agenda")
            .toolbar {
                Button { editando = .novo() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Novo agendamento")
            }
            .sheet(item: $editando) { item in
                FormAgendamentoView(agendamento: item)
            }
            .alert("Erro", isPresented: .constant(store.erro != nil)) {
                Button("OK") { store.erro = nil }
            } message: { Text(store.erro ?? "") }
        }
    }
}

private struct LinhaAgendamento: View {
    let item: Agendamento
    var body: some View {
        HStack(spacing: 12) {
            Text(item.data.formatted(date: .omitted, time: .shortened))
                .font(.headline.monospacedDigit())
                .frame(width: 56, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.titulo).font(.body)
                if !item.cliente.isEmpty {
                    Text(item.cliente).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if item.lembreteMinutos != nil {
                Image(systemName: "bell.fill").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
