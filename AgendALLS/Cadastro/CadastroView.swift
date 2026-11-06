import SwiftUI

struct CadastroView: View {
    @Environment(Cofre.self) private var cofre
    @Environment(CadastroStore.self) private var store

    var body: some View {
        Group {
            if cofre.desbloqueado && store.carregado {
                CadastroAberto()
            } else {
                TelaBloqueada(
                    titulo: "Cadastro bloqueado",
                    motivo: "abrir o seu cadastro"
                )
            }
        }
        .onChange(of: cofre.desbloqueado) { _, aberto in
            if aberto { store.carregar() } else { store.descarregar() }
        }
        .onAppear {
            if cofre.desbloqueado && !store.carregado { store.carregar() }
        }
        .alert("Erro", isPresented: Binding(get: { store.erro != nil }, set: { if !$0 { store.erro = nil } })) {
            Button("OK") { store.erro = nil }
        } message: {
            Text(store.erro ?? "")
        }
    }
}

/// Tela mostrada enquanto o cofre está trancado.
struct TelaBloqueada: View {
    @Environment(Cofre.self) private var cofre
    let titulo: String
    let motivo: String

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 46))
                .foregroundStyle(.secondary)
            Text(titulo).font(.title2.bold())
            Text("Use o Touch ID ou a senha do Mac para desbloquear. Tranca sozinho após 1 minuto sem uso.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button {
                Task { await cofre.desbloquear(motivo: motivo) }
            } label: {
                Label("Desbloquear", systemImage: "touchid")
                    .padding(.horizontal, 10)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            if let m = cofre.mensagem {
                Text(m).font(.caption).foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CadastroAberto: View {
    @Environment(Cofre.self) private var cofre
    @State private var secao: SecaoCadastro = .pessoal

    var body: some View {
        HStack(spacing: 0) {
            List(SecaoCadastro.allCases, selection: Binding(get: { secao }, set: { if let s = $0 { secao = s } })) { s in
                Label(s.nome, systemImage: s.icone).tag(s)
            }
            .listStyle(.sidebar)
            .frame(width: 200)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(secao.nome).font(.title2.bold())
                        Spacer()
                        Button {
                            cofre.trancar()
                        } label: {
                            Label("Bloquear", systemImage: "lock")
                        }
                    }
                    EditorDaSecao(secao: secao)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 380)

            Divider()

            PainelImpressao()
                .frame(width: 360)
        }
    }
}

// MARK: - Editores

private struct EditorDaSecao: View {
    @Environment(CadastroStore.self) private var store
    let secao: SecaoCadastro

    var body: some View {
        switch secao.tipo {
        case .campos(let campos):
            if secao == .pessoal { EditorFoto() }
            ForEach(campos.indices, id: \.self) { i in
                let c = campos[i]
                CampoCopiavel(rotulo: c.rotulo, texto: Binding(
                    get: { store.campo(c.chave) },
                    set: { v in store.alterar { $0.campos[c.chave] = v } }
                ))
            }
            CamposExtras(secao: secao)

        case .texto(let chave, let dica):
            Text(dica).font(.callout).foregroundStyle(.secondary)
            TextEditor(text: Binding(get: { store.dados[keyPath: chave] }, set: { v in store.alterar { $0[keyPath: chave] = v } }))
                .font(.body)
                .frame(minHeight: 220)
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))

        case .experiencias:
            ForEach(store.dados.experiencias) { e in
                Entrada(aoRemover: { store.alterar { $0.experiencias.removeAll { $0.id == e.id } } }) {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            campoExp(e, "Cargo", \.cargo)
                            campoExp(e, "Empresa", \.empresa)
                        }
                        GridRow {
                            campoExp(e, "Cidade", \.cidade)
                            campoExp(e, "Período", \.periodo)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Realizações (uma por linha)").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: ligacaoExp(e, \.realizacoes))
                            .frame(minHeight: 70)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
                    }
                }
            }
            Button("+ Adicionar experiência") { store.alterar { $0.experiencias.append(Experiencia()) } }

        case .formacao:
            ForEach(store.dados.formacao) { f in
                Entrada(aoRemover: { store.alterar { $0.formacao.removeAll { $0.id == f.id } } }) {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                        GridRow {
                            campoForm(f, "Curso", \.curso)
                            campoForm(f, "Instituição", \.instituicao)
                        }
                        GridRow {
                            campoForm(f, "Cidade", \.cidade)
                            campoForm(f, "Período", \.periodo)
                        }
                    }
                }
            }
            Button("+ Adicionar formação") { store.alterar { $0.formacao.append(Formacao()) } }

        case .programas:
            Text("Clique nas bolinhas para definir o nível.").font(.callout).foregroundStyle(.secondary)
            ForEach(store.dados.programas) { p in
                HStack(spacing: 12) {
                    TextField("Programa", text: Binding(
                        get: { store.dados.programas.first { $0.id == p.id }?.nome ?? "" },
                        set: { v in store.alterar { d in if let i = d.programas.firstIndex(where: { $0.id == p.id }) { d.programas[i].nome = v } } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    HStack(spacing: 5) {
                        ForEach(1...5, id: \.self) { n in
                            Button {
                                store.alterar { d in if let i = d.programas.firstIndex(where: { $0.id == p.id }) { d.programas[i].nivel = n } }
                            } label: {
                                Circle()
                                    .fill(n <= p.nivel ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Nível \(n)")
                        }
                    }
                    Button {
                        store.alterar { $0.programas.removeAll { $0.id == p.id } }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                }
            }
            Button("+ Adicionar programa") { store.alterar { $0.programas.append(Programa()) } }
        }
    }

    private func ligacaoExp(_ e: Experiencia, _ kp: WritableKeyPath<Experiencia, String>) -> Binding<String> {
        Binding(
            get: { store.dados.experiencias.first { $0.id == e.id }?[keyPath: kp] ?? "" },
            set: { v in store.alterar { d in if let i = d.experiencias.firstIndex(where: { $0.id == e.id }) { d.experiencias[i][keyPath: kp] = v } } }
        )
    }

    private func campoExp(_ e: Experiencia, _ rotulo: String, _ kp: WritableKeyPath<Experiencia, String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.caption).foregroundStyle(.secondary)
            TextField(rotulo, text: ligacaoExp(e, kp)).textFieldStyle(.roundedBorder)
        }
    }

    private func campoForm(_ f: Formacao, _ rotulo: String, _ kp: WritableKeyPath<Formacao, String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.caption).foregroundStyle(.secondary)
            TextField(rotulo, text: Binding(
                get: { store.dados.formacao.first { $0.id == f.id }?[keyPath: kp] ?? "" },
                set: { v in store.alterar { d in if let i = d.formacao.firstIndex(where: { $0.id == f.id }) { d.formacao[i][keyPath: kp] = v } } }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }
}

private struct Entrada<Conteudo: View>: View {
    let aoRemover: () -> Void
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { conteudo }
            .padding(14)
            .padding(.trailing, 20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
            .overlay(alignment: .topTrailing) {
                Button(action: aoRemover) { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .help("Remover")
            }
    }
}

/// Campo de texto com botão para copiar o valor.
private struct CampoCopiavel: View {
    let rotulo: String
    @Binding var texto: String
    @State private var copiado = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField(rotulo, text: $texto)
                    .textFieldStyle(.roundedBorder)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(texto, forType: .string)
                    copiado = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copiado = false
                    }
                } label: {
                    Image(systemName: copiado ? "checkmark" : "doc.on.doc")
                        .frame(width: 16)
                }
                .help("Copiar \(rotulo)")
                .disabled(texto.isEmpty)
            }
        }
    }
}

private struct CamposExtras: View {
    @Environment(CadastroStore.self) private var store
    let secao: SecaoCadastro
    @State private var pedindoNome = false
    @State private var novoRotulo = ""

    var body: some View {
        ForEach(store.dados.extras.filter { $0.secao == secao.rawValue }) { extra in
            HStack(alignment: .bottom) {
                CampoCopiavel(rotulo: extra.rotulo, texto: Binding(
                    get: { store.dados.extras.first { $0.id == extra.id }?.valor ?? "" },
                    set: { v in store.alterar { d in if let i = d.extras.firstIndex(where: { $0.id == extra.id }) { d.extras[i].valor = v } } }
                ))
                Button {
                    store.alterar { $0.extras.removeAll { $0.id == extra.id } }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remover campo")
            }
        }
        Button("+ Adicionar campo") {
            novoRotulo = ""
            pedindoNome = true
        }
        .alert("Novo campo", isPresented: $pedindoNome) {
            TextField("Nome do campo", text: $novoRotulo)
            Button("Cancelar", role: .cancel) {}
            Button("Adicionar") {
                let r = novoRotulo.trimmingCharacters(in: .whitespaces)
                if !r.isEmpty { store.alterar { $0.extras.append(CampoExtra(secao: secao.rawValue, rotulo: r)) } }
            }
        } message: {
            Text("Ex.: Cartão do SUS, Reservista, OAB…")
        }
    }
}

// MARK: - Impressão

private struct PainelImpressao: View {
    @Environment(CadastroStore.self) private var store
    @State private var modelo: ModeloImpressao = .curriculo
    @State private var secoesPersonalizadas: Set<SecaoCadastro> = [.documentos, .contato]
    @State private var ampliado = false

    private var folha: FolhaA4 {
        FolhaA4(dados: store.dados, modelo: modelo, secoes: secoesPersonalizadas)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Gerar impressão").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(ModeloImpressao.allCases) { m in
                    Button {
                        modelo = m
                    } label: {
                        Text(m.nome)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 26)
                    }
                    .buttonStyle(.bordered)
                    .tint(modelo == m ? .accentColor : .secondary)
                }
            }
            if modelo == .personalizado {
                FlowLayout(espaco: 6, entreLinhas: 6) {
                    ForEach(SecaoCadastro.deCampos) { s in
                        Toggle(s.nome, isOn: Binding(
                            get: { secoesPersonalizadas.contains(s) },
                            set: { if $0 { secoesPersonalizadas.insert(s) } else { secoesPersonalizadas.remove(s) } }
                        ))
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    }
                }
            }

            Button {
                ampliado = true
            } label: {
                folha
                    .scaleEffect(312 / FolhaA4.tamanho.width, anchor: .topLeading)
                    .frame(width: 312, height: 312 * FolhaA4.tamanho.height / FolhaA4.tamanho.width, alignment: .topLeading)
                    .clipped()
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .help("Clique para ampliar")
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

            HStack {
                Button("Imprimir…") { Exportador.imprimir(folha) }
                    .frame(maxWidth: .infinity)
                Button("Baixar PDF") {
                    let nome = store.campo("nome").isEmpty ? "Cadastro" : store.campo("nome")
                    Exportador.salvarPDF(folha, nomeSugerido: "\(modelo.nome) – \(nome).pdf")
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .underPageBackgroundColor))
        .sheet(isPresented: $ampliado) {
            VStack(spacing: 12) {
                folha
                    .scaleEffect(0.85, anchor: .topLeading)
                    .frame(width: FolhaA4.tamanho.width * 0.85, height: FolhaA4.tamanho.height * 0.85, alignment: .topLeading)
                    .clipped()
                    .shadow(radius: 6)
                Button("Fechar") { ampliado = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)
        }
    }
}
