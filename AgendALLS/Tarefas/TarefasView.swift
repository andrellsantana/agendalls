import SwiftUI

struct TarefasView: View {
    @Environment(TarefasStore.self) private var store
    @State private var editando: Tarefa?
    @State private var criando = false

    var body: some View {
        Group {
            switch store.modo {
            case .lista: ListaTarefasView(editando: $editando)
            case .mesa: MesaView(editando: $editando)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Visualização", selection: Binding(get: { store.modo }, set: { store.definirModo($0) })) {
                    Label("Lista", systemImage: "list.number").tag(ModoTarefas.lista)
                    Label("Mesa", systemImage: "rectangle.on.rectangle.angled").tag(ModoTarefas.mesa)
                }
                .pickerStyle(.segmented)
                .labelStyle(.titleOnly)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    criando = true
                } label: {
                    Label("Nova tarefa", systemImage: "plus")
                }
                .keyboardShortcut("n")
                .help("Nova tarefa (⌘N)")
            }
        }
        .sheet(isPresented: $criando) { EditorTarefaView(tarefa: nil) }
        .sheet(item: $editando) { EditorTarefaView(tarefa: $0) }
        .alert("Erro", isPresented: Binding(get: { store.erro != nil }, set: { if !$0 { store.erro = nil } })) {
            Button("OK") { store.erro = nil }
        } message: {
            Text(store.erro ?? "")
        }
    }
}

/// Menu do botão direito, igual na lista e na mesa.
struct MenuTarefa: View {
    @Environment(TarefasStore.self) private var store
    let tarefa: Tarefa
    @Binding var editando: Tarefa?

    var body: some View {
        Picker("Situação", selection: Binding(get: { tarefa.feita }, set: { store.definirFeita(tarefa, $0) })) {
            Text("Feito").tag(true)
            Text("Não feito").tag(false)
        }
        .pickerStyle(.inline)
        .labelsHidden()
        Divider()
        Button("Editar…") { editando = tarefa }
        Button("Excluir", role: .destructive) { store.excluir(tarefa) }
    }
}

struct EditorTarefaView: View {
    @Environment(TarefasStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let tarefa: Tarefa?
    @State private var titulo = ""
    @State private var notas = ""
    @State private var feita = false

    private var valido: Bool { !titulo.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tarefa == nil ? "Nova tarefa" : "Editar tarefa").font(.title2.bold())
            Form {
                TextField("Título", text: $titulo)
                TextField("Anotações", text: $notas, axis: .vertical)
                    .lineLimit(4...10)
                if tarefa != nil {
                    Toggle("Feito", isOn: $feita)
                }
            }
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    if var t = tarefa {
                        let mudouTitulo = t.titulo != titulo
                        t.titulo = titulo
                        t.notas = notas
                        t.feita = feita
                        if mudouTitulo { t.destaques = [] }
                        store.atualizar(t)
                    } else {
                        store.adicionar(titulo: titulo, notas: notas)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!valido)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            titulo = tarefa?.titulo ?? ""
            notas = tarefa?.notas ?? ""
            feita = tarefa?.feita ?? false
        }
    }
}
