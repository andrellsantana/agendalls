import SwiftUI

struct FormAgendamentoView: View {
    @Environment(AgendaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var agendamento: Agendamento

    private let opcoesLembrete: [(String, Int?)] = [
        ("Sem lembrete", nil), ("Na hora", 0), ("5 minutos antes", 5), ("15 minutos antes", 15),
        ("30 minutos antes", 30), ("1 hora antes", 60), ("1 dia antes", 1440)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Título", text: $agendamento.titulo)
                    TextField("Cliente", text: $agendamento.cliente)
                        .textContentType(.name)
                }
                Section {
                    DatePicker("Data e hora", selection: $agendamento.data)
                    Picker("Lembrete", selection: $agendamento.lembreteMinutos) {
                        ForEach(opcoesLembrete, id: \.0) { Text($0.0).tag($0.1) }
                    }
                }
                Section("Notas") {
                    TextField("Observações", text: $agendamento.notas, axis: .vertical)
                        .lineLimit(3...8)
                }
                if agendamento.id != nil {
                    Section {
                        Button("Excluir agendamento", role: .destructive) {
                            store.excluir(agendamento); dismiss()
                        }
                    }
                }
            }
            .navigationTitle(agendamento.id == nil ? "Novo agendamento" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { store.salvar(agendamento); dismiss() }
                        .disabled(agendamento.titulo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
