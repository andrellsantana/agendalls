import SwiftUI

struct RemediosView: View {
    @Environment(RemediosStore.self) private var store
    @State private var editando: Remedio?
    @State private var aberto: Remedio?
    @State private var repondo: Remedio?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !store.acabando.isEmpty {
                    AvisoEstoque(remedios: store.acabando) { repondo = $0 }
                }
                FaixaDeHoje()

                HStack {
                    Text("Meus remédios").font(.title3.bold())
                    Spacer()
                    Button {
                        editando = Remedio(id: 0, nome: "", laboratorio: "", dosagem: "", horarios: ["08:00"], objetivo: "",
                                           estoque: 30, porDose: 1, avisoDias: 7, tom: 0)
                    } label: {
                        Label("Novo remédio", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n")
                }

                if store.remedios.isEmpty {
                    ContentUnavailableView(
                        "Nenhum remédio",
                        systemImage: "pills",
                        description: Text("Clique em Novo remédio para cadastrar o primeiro.")
                    )
                    .padding(.top, 30)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                        ForEach(store.remedios) { r in
                            CartaoRemedio(remedio: r)
                                .onTapGesture { aberto = r }
                                .contextMenu {
                                    Button("Registrar doses de hoje…") { aberto = r }
                                    Button("Repor estoque…") { repondo = r }
                                    Button("Editar…") { editando = r }
                                    Divider()
                                    Button("Excluir", role: .destructive) { store.excluir(r) }
                                }
                        }
                    }
                    Text("Clique num remédio para registrar se tomou hoje na hora certa. Botão direito: repor estoque, editar ou excluir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .sheet(item: $editando) { EditorRemedio(remedio: $0) }
        .sheet(item: $aberto) { r in DosesDoRemedio(id: r.id) }
        .sheet(item: $repondo) { ReporEstoque(remedio: $0) }
        .alert("Erro", isPresented: Binding(get: { store.erro != nil }, set: { if !$0 { store.erro = nil } })) {
            Button("OK") { store.erro = nil }
        } message: {
            Text(store.erro ?? "")
        }
    }
}

// MARK: - Hoje

private struct FaixaDeHoje: View {
    @Environment(RemediosStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Hoje").font(.title3.bold())
                Text(store.resumoDeHoje).font(.callout).foregroundStyle(.secondary)
            }
            if store.dosesDeHoje.isEmpty {
                Text("Cadastre um remédio com horários para ver as doses do dia.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(store.dosesDeHoje) { dose in
                            BlocoDose(remedio: dose.remedio, horario: dose.horario)
                        }
                    }
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(nsColor: .separatorColor)))
    }
}

/// Uma dose do dia; clicar abre as opções de registro.
private struct BlocoDose: View {
    @Environment(RemediosStore.self) private var store
    let remedio: Remedio
    let horario: String
    @State private var opcoes = false

    var body: some View {
        let registro = store.registro(remedio, horario)
        Button {
            opcoes = true
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(horario).font(.title3.bold().monospacedDigit())
                Text(remedio.nome).font(.callout.weight(.semibold)).lineLimit(1)
                Text(remedio.dosagem).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Label(rotulo(registro), systemImage: registro?.situacao.icone ?? "circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(registro?.situacao.cor ?? Color.secondary)
                    .padding(.top, 4)
            }
            .frame(width: 150, alignment: .leading)
            .padding(12)
            .background(registro.map { $0.situacao.cor.opacity(0.1) } ?? remedio.corClara, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(registro.map { $0.situacao.cor.opacity(0.45) } ?? remedio.corBorda))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $opcoes, arrowEdge: .bottom) {
            OpcoesDose(remedio: remedio, horario: horario) { opcoes = false }
        }
    }

    private func rotulo(_ r: RegistroDose?) -> String {
        guard let r else { return "Registrar" }
        if r.situacao == .atrasada, let h = r.horaReal { return "Tomei às \(h)" }
        return r.situacao.curto
    }
}

/// Opções para registrar uma dose de hoje.
private struct OpcoesDose: View {
    @Environment(RemediosStore.self) private var store
    let remedio: Remedio
    let horario: String
    let aoTerminar: () -> Void
    @State private var horaReal = Date().semSegundos
    @State private var informandoHora = false

    var body: some View {
        let atual = store.registro(remedio, horario)
        VStack(alignment: .leading, spacing: 10) {
            Text("\(remedio.nome) · \(horario)").font(.headline)
            Text("Hoje, \(remedio.dosagem)").font(.caption).foregroundStyle(.secondary)

            Button {
                store.registrar(remedio, horario, .naHora)
                aoTerminar()
            } label: {
                Label(SituacaoDose.naHora.nome, systemImage: SituacaoDose.naHora.icone)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(.green)

            if informandoHora {
                HStack {
                    DatePicker("Tomei às", selection: $horaReal, displayedComponents: .hourAndMinute)
                    Button("OK") {
                        store.registrar(remedio, horario, .atrasada, horaReal: Formatos.hora(horaReal))
                        aoTerminar()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                Button {
                    informandoHora = true
                } label: {
                    Label(SituacaoDose.atrasada.nome + "…", systemImage: SituacaoDose.atrasada.icone)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(.orange)
            }

            Button {
                store.registrar(remedio, horario, .naoTomei)
                aoTerminar()
            } label: {
                Label(SituacaoDose.naoTomei.nome, systemImage: SituacaoDose.naoTomei.icone)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(.red)

            if atual != nil {
                Divider()
                Button("Limpar registro") {
                    store.registrar(remedio, horario, nil)
                    aoTerminar()
                }
                .buttonStyle(.link)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(16)
        .frame(width: 280)
    }
}

/// Janela aberta ao clicar num remédio: todas as doses dele hoje.
private struct DosesDoRemedio: View {
    @Environment(RemediosStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let id: Int64

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let r = store.remedios.first(where: { $0.id == id }) {
                HStack(spacing: 12) {
                    IconeRemedio(remedio: r, tamanho: 40)
                    VStack(alignment: .leading) {
                        Text(r.nome).font(.title2.bold())
                        Text([r.laboratorio, r.dosagem].filter { !$0.isEmpty }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Hoje eu tomei na hora certa?").font(.headline)
                if r.horarios.isEmpty {
                    Text("Este remédio não tem horários cadastrados.").foregroundStyle(.secondary)
                }
                ForEach(r.horarios, id: \.self) { h in
                    LinhaDose(remedio: r, horario: h)
                }
                Text(textoEstoque(r)).font(.callout).foregroundStyle(r.estoqueAcabando ? Color.orange : Color.secondary)
            }
            HStack {
                Spacer()
                Button("Fechar") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
    }
}

private struct LinhaDose: View {
    @Environment(RemediosStore.self) private var store
    let remedio: Remedio
    let horario: String
    @State private var horaReal = Date().semSegundos

    var body: some View {
        let atual = store.registro(remedio, horario)?.situacao
        HStack(spacing: 10) {
            Text(horario).font(.title3.bold().monospacedDigit()).frame(width: 64, alignment: .leading)
            ForEach(SituacaoDose.allCases) { s in
                Button {
                    if atual == s {
                        store.registrar(remedio, horario, nil)
                    } else {
                        store.registrar(remedio, horario, s, horaReal: s == .atrasada ? Formatos.hora(horaReal) : nil)
                    }
                } label: {
                    Label(s.curto, systemImage: s.icone)
                        .font(.callout.weight(atual == s ? .bold : .regular))
                }
                .buttonStyle(.bordered)
                .tint(atual == s ? s.cor : .secondary)
            }
            if atual == .atrasada || atual == nil {
                DatePicker("Hora", selection: $horaReal, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .help("Horário em que tomou, se fora do horário")
            }
        }
    }
}

// MARK: - Cards

private struct CartaoRemedio: View {
    @Environment(RemediosStore.self) private var store
    let remedio: Remedio

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconeRemedio(remedio: remedio, tamanho: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(remedio.nome).font(.headline)
                    if !remedio.laboratorio.isEmpty {
                        Text(remedio.laboratorio).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if remedio.estoqueAcabando {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("Estoque acabando")
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Dosagem").foregroundStyle(.secondary)
                    Text(remedio.dosagem.isEmpty ? "—" : remedio.dosagem).fontWeight(.semibold)
                }
                GridRow {
                    Text("Objetivo").foregroundStyle(.secondary)
                    Text(remedio.objetivo.isEmpty ? "—" : remedio.objetivo)
                }
            }
            .font(.callout)

            HStack(spacing: 6) {
                ForEach(remedio.horarios, id: \.self) { h in
                    let s = store.registro(remedio, h)?.situacao
                    HStack(spacing: 3) {
                        if let s { Image(systemName: s.icone) }
                        Text(h)
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .foregroundStyle(s?.cor ?? remedio.corTexto)
                    .background((s?.cor.opacity(0.12)) ?? remedio.corClara, in: Capsule())
                }
            }

            BarraEstoque(remedio: remedio)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12)
                .fill(remedio.cor)
                .frame(height: 4)
        }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct BarraEstoque: View {
    let remedio: Remedio

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(textoEstoque(remedio))
                .font(.caption.weight(remedio.estoqueAcabando ? .semibold : .regular))
                .foregroundStyle(remedio.estoqueAcabando ? Color.orange : Color.secondary)
            if let dias = remedio.diasRestantes {
                GeometryReader { geo in
                    let fracao = min(Double(dias) / Double(max(remedio.avisoDias * 4, 1)), 1)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.15))
                        Capsule()
                            .fill(remedio.estoqueAcabando ? Color.orange : remedio.cor)
                            .frame(width: geo.size.width * fracao)
                    }
                }
                .frame(height: 5)
            }
        }
    }
}

private func textoEstoque(_ r: Remedio) -> String {
    guard let dias = r.diasRestantes else { return "Estoque: \(r.estoque) unidade(s)" }
    let duracao = dias == 1 ? "1 dia" : "\(dias) dias"
    return "Estoque: \(r.estoque) unidade(s) · dura cerca de \(duracao)"
}

private struct IconeRemedio: View {
    let remedio: Remedio
    let tamanho: CGFloat

    var body: some View {
        Image(systemName: "pills.fill")
            .font(.system(size: tamanho * 0.45))
            .foregroundStyle(remedio.corTexto)
            .frame(width: tamanho, height: tamanho)
            .background(remedio.corClara, in: RoundedRectangle(cornerRadius: tamanho * 0.28))
            .overlay(RoundedRectangle(cornerRadius: tamanho * 0.28).strokeBorder(remedio.corBorda))
            .accessibilityHidden(true)
    }
}

private struct AvisoEstoque: View {
    let remedios: [Remedio]
    let repor: (Remedio) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Estoque acabando", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            ForEach(remedios) { r in
                HStack {
                    Text(r.nome).fontWeight(.semibold)
                    Text(textoEstoque(r)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Repor…") { repor(r) }
                }
                .font(.callout)
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.orange.opacity(0.4)))
    }
}

// MARK: - Formulários

private struct EditorRemedio: View {
    @Environment(RemediosStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var remedio: Remedio
    @State private var horas: [Date] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(remedio.id == 0 ? "Novo remédio" : "Editar remédio").font(.title2.bold())
            Form {
                TextField("Nome", text: $remedio.nome)
                TextField("Laboratório", text: $remedio.laboratorio)
                TextField("Dosagem", text: $remedio.dosagem, prompt: Text("Ex.: 50 mg · 1 comprimido"))
                TextField("Objetivo", text: $remedio.objetivo, prompt: Text("Para que serve"))
                LabeledContent("Horários") {
                    VStack(alignment: .trailing, spacing: 6) {
                        ForEach(horas.indices, id: \.self) { i in
                            HStack {
                                DatePicker("Horário \(i + 1)", selection: $horas[i], displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Button {
                                    horas.remove(at: i)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .disabled(horas.count <= 1)
                            }
                        }
                        Button("+ Horário") { horas.append(Date.hoje(minutos: 12 * 60)) }
                            .buttonStyle(.link)
                    }
                }
                Section("Estoque") {
                    Stepper("Unidades em casa: \(remedio.estoque)", value: $remedio.estoque, in: 0...9999)
                    Stepper("Unidades por dose: \(remedio.porDose)", value: $remedio.porDose, in: 1...20)
                    Stepper("Avisar quando durar \(remedio.avisoDias) dias ou menos", value: $remedio.avisoDias, in: 0...60)
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    var r = remedio
                    r.nome = r.nome.trimmingCharacters(in: .whitespaces)
                    r.horarios = horas.map { Formatos.hora($0) }
                    store.salvar(r)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(remedio.nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 500, height: 600)
        .onAppear {
            horas = remedio.horarios.compactMap { h in
                let p = h.split(separator: ":").compactMap { Int($0) }
                return p.count == 2 ? Date.hoje(minutos: p[0] * 60 + p[1]) : nil
            }
            if horas.isEmpty { horas = [Date.hoje(minutos: 8 * 60)] }
        }
    }
}

private struct ReporEstoque: View {
    @Environment(RemediosStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let remedio: Remedio
    @State private var unidades = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Repor estoque").font(.title2.bold())
            Text("\(remedio.nome) · hoje: \(remedio.estoque) unidade(s)").foregroundStyle(.secondary)
            Stepper("Acrescentar \(unidades) unidade(s)", value: $unidades, in: 1...9999)
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Repor") {
                    store.reporEstoque(remedio, unidades: unidades)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
