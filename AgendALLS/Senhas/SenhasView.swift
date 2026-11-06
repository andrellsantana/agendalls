import SwiftUI

/// O que está escolhido na árvore.
private enum Selecao: Hashable {
    case pasta(UUID)
    case saude
}

struct SenhasView: View {
    @Environment(Cofre.self) private var cofre
    @Environment(SenhasStore.self) private var store

    var body: some View {
        Group {
            if cofre.desbloqueado && store.carregado {
                SenhasAbertas()
            } else {
                TelaBloqueada(titulo: "Senhas bloqueadas", motivo: "abrir as suas senhas")
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

private struct SenhasAbertas: View {
    @Environment(SenhasStore.self) private var store
    @State private var selecao: Selecao?
    @State private var itemID: UUID?
    @State private var busca = ""
    @State private var abertas: Set<UUID> = []
    @State private var editando: ItemSenha?

    var body: some View {
        let d = store.dados
        let itens = itensVisiveis(d)
        HStack(spacing: 0) {
            ArvoreDePastas(selecao: $selecao, abertas: $abertas, busca: $busca)
                .frame(width: 240)
            Divider()
            ListaDeItens(
                titulo: tituloDaLista(d),
                itens: itens,
                itemID: $itemID,
                novo: { editando = ItemSenha(pastaID: pastaParaNovo(d), nome: "") }
            )
            .frame(width: 280)
            Divider()
            if let id = itemID, let item = d.itens.first(where: { $0.id == id }) {
                DetalheSenha(item: item, editar: { editando = item })
            } else {
                ContentUnavailableView("Escolha um item", systemImage: "key", description: Text("Ou clique em + para guardar uma senha nova."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $editando) { item in
            EditorSenha(item: item) { salvo in itemID = salvo.id }
        }
        .onAppear {
            if selecao == nil, let primeira = d.filhas(de: nil).first { selecao = .pasta(primeira.id) }
            if abertas.isEmpty { abertas = Set(d.filhas(de: nil).map(\.id)) }
        }
        .onChange(of: selecao) { _, _ in itemID = nil }
    }

    private func itensVisiveis(_ d: DadosSenhas) -> [ItemSenha] {
        let filtro = busca.trimmingCharacters(in: .whitespaces).lowercased()
        let base: [ItemSenha]
        if !filtro.isEmpty {
            base = d.itens.filter { ($0.nome + " " + $0.usuario + " " + $0.url).lowercased().contains(filtro) }
        } else if case .pasta(let id)? = selecao {
            let ids = d.descendentes(id)
            base = d.itens.filter { ids.contains($0.pastaID) }
        } else if selecao == .saude {
            base = d.itens.filter { !d.alertas($0).isEmpty }
        } else {
            base = d.itens
        }
        return base.sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
    }

    private func tituloDaLista(_ d: DadosSenhas) -> String {
        if !busca.trimmingCharacters(in: .whitespaces).isEmpty { return "Resultados" }
        switch selecao {
        case .pasta(let id)?: return d.pastas.first { $0.id == id }?.nome ?? "Senhas"
        case .saude?: return "Saúde das senhas"
        case nil: return "Todas"
        }
    }

    private func pastaParaNovo(_ d: DadosSenhas) -> UUID {
        if case .pasta(let id)? = selecao { return id }
        return d.filhas(de: nil).first?.id ?? store.novaPasta(nome: "Geral", dentroDe: nil)
    }
}

// MARK: - Árvore

private struct ArvoreDePastas: View {
    @Environment(SenhasStore.self) private var store
    @Environment(Cofre.self) private var cofre
    @Binding var selecao: Selecao?
    @Binding var abertas: Set<UUID>
    @Binding var busca: String
    @State private var nomeando: (pai: UUID?, renomear: UUID?)?
    @State private var nome = ""

    private struct Linha: Identifiable {
        let pasta: Pasta
        let nivel: Int
        let temFilhas: Bool
        var id: UUID { pasta.id }
    }

    var body: some View {
        let d = store.dados
        VStack(alignment: .leading, spacing: 8) {
            TextField("Buscar", text: $busca)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 10)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(linhas(d)) { linha in
                        botao(linha, d)
                    }
                }
                .padding(.horizontal, 8)
            }

            Button {
                nome = ""
                nomeando = (nil, nil)
            } label: {
                Label("Nova categoria", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)

            let alertas = d.itens.filter { !d.alertas($0).isEmpty }.count
            Button {
                selecao = .saude
                busca = ""
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Saúde das senhas", systemImage: alertas == 0 ? "checkmark.shield" : "exclamationmark.shield")
                        .font(.callout.weight(.semibold))
                    Text(alertas == 0 ? "Tudo certo" : "\(alertas) item(ns) com senha fraca ou repetida")
                        .font(.caption)
                }
                .foregroundStyle(alertas == 0 ? Color.green : Color.orange)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background((alertas == 0 ? Color.green : Color.orange).opacity(selecao == .saude ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)

            Button {
                cofre.trancar()
            } label: {
                Label("Bloquear", systemImage: "lock")
            }
            .buttonStyle(.borderless)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .alert(nomeando?.renomear == nil ? "Nova categoria" : "Renomear categoria", isPresented: Binding(get: { nomeando != nil }, set: { if !$0 { nomeando = nil } })) {
            TextField("Nome", text: $nome)
            Button("Cancelar", role: .cancel) { nomeando = nil }
            Button("OK") {
                let n = nome.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty, let pedido = nomeando {
                    if let id = pedido.renomear {
                        store.renomearPasta(id, n)
                    } else {
                        let id = store.novaPasta(nome: n, dentroDe: pedido.pai)
                        if let pai = pedido.pai { abertas.insert(pai) }
                        selecao = .pasta(id)
                    }
                }
                nomeando = nil
            }
        }
    }

    private func linhas(_ d: DadosSenhas) -> [Linha] {
        var r: [Linha] = []
        func visitar(_ pai: UUID?, _ nivel: Int) {
            for p in d.filhas(de: pai) {
                let filhas = !d.filhas(de: p.id).isEmpty
                r.append(Linha(pasta: p, nivel: nivel, temFilhas: filhas))
                if filhas && abertas.contains(p.id) { visitar(p.id, nivel + 1) }
            }
        }
        visitar(nil, 0)
        return r
    }

    private func botao(_ linha: Linha, _ d: DadosSenhas) -> some View {
        let escolhida = selecao == .pasta(linha.id) && busca.isEmpty
        let quantidade = d.itens.filter { d.descendentes(linha.id).contains($0.pastaID) }.count
        return HStack(spacing: 6) {
            Button {
                if abertas.contains(linha.id) { abertas.remove(linha.id) } else { abertas.insert(linha.id) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(abertas.contains(linha.id) ? 90 : 0))
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .opacity(linha.temFilhas ? 1 : 0)
            .disabled(!linha.temFilhas)
            .accessibilityLabel(abertas.contains(linha.id) ? "Recolher" : "Expandir")

            Image(systemName: abertas.contains(linha.id) && linha.temFilhas ? "folder.fill" : "folder")
                .foregroundStyle(escolhida ? Color.white : Color.accentColor)
            Text(linha.pasta.nome)
                .fontWeight(linha.nivel == 0 ? .semibold : .regular)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(quantidade)")
                .font(.caption)
                .foregroundStyle(escolhida ? Color.white.opacity(0.85) : Color.secondary)
        }
        .font(.callout)
        .foregroundStyle(escolhida ? Color.white : Color.primary)
        .padding(.leading, 6 + CGFloat(linha.nivel) * 18)
        .padding(.trailing, 8)
        .frame(height: 28)
        .background(escolhida ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture {
            selecao = .pasta(linha.id)
            busca = ""
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)), let item = d.itens.first(where: { $0.id == id }) else { return false }
            store.mover(item, para: linha.id)
            return true
        }
        .contextMenu {
            Button("Nova subcategoria…") {
                nome = ""
                nomeando = (linha.id, nil)
            }
            Button("Renomear…") {
                nome = linha.pasta.nome
                nomeando = (nil, linha.id)
            }
            Divider()
            Button("Excluir", role: .destructive) {
                store.excluirPasta(linha.id)
                if selecao == .pasta(linha.id) { selecao = nil }
            }
            .disabled(!store.podeExcluir(linha.id))
        }
    }
}

// MARK: - Lista de itens

private struct ListaDeItens: View {
    @Environment(SenhasStore.self) private var store
    let titulo: String
    let itens: [ItemSenha]
    @Binding var itemID: UUID?
    let novo: () -> Void

    var body: some View {
        let d = store.dados
        VStack(spacing: 0) {
            HStack {
                Text(titulo).font(.headline).lineLimit(1)
                Spacer()
                Button(action: novo) { Image(systemName: "plus") }
                    .help("Nova senha (⌘N)")
                    .keyboardShortcut("n")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if itens.isEmpty {
                Text("Nenhum item aqui.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(itens, selection: $itemID) { item in
                    HStack(spacing: 10) {
                        Monograma(item: item, tamanho: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.nome).fontWeight(.semibold).lineLimit(1)
                            Text(item.usuario.isEmpty ? item.dominio : item.usuario)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if !d.alertas(item).isEmpty {
                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                                .help(d.alertas(item).joined(separator: " "))
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(item.id)
                    .draggable(item.id.uuidString)
                    .contextMenu {
                        Button("Copiar usuário") { store.copiar(item.usuario) }.disabled(item.usuario.isEmpty)
                        Button("Copiar senha") { store.copiar(item.senha) }.disabled(item.senha.isEmpty)
                        Divider()
                        Button("Excluir", role: .destructive) {
                            store.excluir(item)
                            if itemID == item.id { itemID = nil }
                        }
                    }
                }
                .listStyle(.inset)
            }
            Text("Arraste um item até uma categoria para movê-lo.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(8)
        }
    }
}

private struct Monograma: View {
    let item: ItemSenha
    let tamanho: CGFloat

    var body: some View {
        Text(item.inicial)
            .font(.system(size: tamanho * 0.45, weight: .heavy))
            .foregroundStyle(.white)
            .frame(width: tamanho, height: tamanho)
            .background(Color(hue: CoresLink.tom(item.nome), saturation: 0.5, brightness: 0.55), in: RoundedRectangle(cornerRadius: tamanho * 0.25))
            .accessibilityHidden(true)
    }
}

// MARK: - Detalhe

private struct DetalheSenha: View {
    @Environment(SenhasStore.self) private var store
    let item: ItemSenha
    let editar: () -> Void
    @State private var mostrar = false
    @State private var copiado: String?

    var body: some View {
        let d = store.dados
        let forca = Forca.de(item.senha)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Monograma(item: item, tamanho: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.nome).font(.title2.bold())
                        Text(d.caminho(item.pastaID)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Editar", action: editar)
                }

                VStack(spacing: 0) {
                    linha("Usuário") {
                        Text(item.usuario.isEmpty ? "—" : item.usuario).textSelection(.enabled)
                        Spacer()
                        botaoCopiar("usuario", item.usuario)
                    }
                    Divider()
                    linha("Senha") {
                        Text(mostrar ? item.senha : String(repeating: "•", count: min(max(item.senha.count, 8), 16)))
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Spacer()
                        Button(mostrar ? "Ocultar" : "Mostrar") { mostrar.toggle() }
                        botaoCopiar("senha", item.senha)
                    }
                    Divider()
                    linha("Força") {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.secondary.opacity(0.15))
                                Capsule().fill(cor(forca)).frame(width: geo.size.width * Double(forca.rawValue + 1) / 5)
                            }
                        }
                        .frame(height: 6)
                        Text(forca.nome).font(.callout.weight(.semibold)).frame(width: 80, alignment: .trailing)
                    }
                    if !item.segredo2FA.isEmpty {
                        Divider()
                        linha("Código 2FA") {
                            TimelineView(.periodic(from: .now, by: 1)) { contexto in
                                HStack {
                                    Text(TOTP.codigo(segredo: item.segredo2FA, em: contexto.date) ?? "segredo inválido")
                                        .font(.system(.title3, design: .monospaced).weight(.bold))
                                    Spacer()
                                    Text("renova em \(TOTP.segundosRestantes(em: contexto.date)) s")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    botaoCopiar("2fa", (TOTP.codigo(segredo: item.segredo2FA, em: contexto.date) ?? "").replacingOccurrences(of: " ", with: ""))
                                }
                            }
                        }
                    }
                    if !item.url.isEmpty {
                        Divider()
                        linha("Site") {
                            if let url = URL(string: item.url.contains("://") ? item.url : "https://" + item.url) {
                                Link(item.dominio.isEmpty ? item.url : item.dominio, destination: url)
                            }
                            Spacer()
                        }
                    }
                    if !item.notas.isEmpty {
                        Divider()
                        linha("Notas") {
                            Text(item.notas).textSelection(.enabled)
                            Spacer()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))

                let alertas = d.alertas(item)
                if !alertas.isEmpty {
                    Label(alertas.joined(separator: " ") + " Sugestão: clique em Editar e gere uma senha nova.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                }

                Text("Senha alterada em \(item.alteradaEm.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("O que você copia aqui some da área de transferência depois de 1 minuto.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: item.id) { _, _ in mostrar = false }
    }

    private func linha<C: View>(_ rotulo: String, @ViewBuilder _ conteudo: () -> C) -> some View {
        HStack(spacing: 10) {
            Text(rotulo).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            conteudo()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func botaoCopiar(_ chave: String, _ texto: String) -> some View {
        Button(copiado == chave ? "Copiado ✓" : "Copiar") {
            store.copiar(texto)
            copiado = chave
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                if copiado == chave { copiado = nil }
            }
        }
        .disabled(texto.isEmpty)
    }

    private func cor(_ f: Forca) -> Color {
        switch f {
        case .muitoFraca, .fraca: .red
        case .media: .orange
        case .boa: Color(red: 0.2, green: 0.6, blue: 0.3)
        case .forte: .green
        }
    }
}

// MARK: - Editor e gerador

private struct EditorSenha: View {
    @Environment(SenhasStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var item: ItemSenha
    let aoSalvar: (ItemSenha) -> Void
    @State private var mostrar = false
    @State private var tamanho = 20.0
    @State private var numeros = true
    @State private var simbolos = true
    @State private var frase = false
    @State private var sugestao = ""

    var body: some View {
        let d = store.dados
        VStack(alignment: .leading, spacing: 14) {
            Text(d.itens.contains { $0.id == item.id } ? "Editar senha" : "Nova senha").font(.title2.bold())
            Form {
                TextField("Nome", text: $item.nome, prompt: Text("Ex.: Banco, E-mail pessoal"))
                Picker("Categoria", selection: $item.pastaID) {
                    let opcoes = pastasEmOrdem(d)
                    ForEach(opcoes.indices, id: \.self) { i in
                        Text(String(repeating: "    ", count: opcoes[i].1) + opcoes[i].0.nome).tag(opcoes[i].0.id)
                    }
                }
                TextField("Usuário", text: $item.usuario)
                HStack {
                    if mostrar {
                        TextField("Senha", text: $item.senha)
                    } else {
                        SecureField("Senha", text: $item.senha)
                    }
                    Button { mostrar.toggle() } label: { Image(systemName: mostrar ? "eye.slash" : "eye") }
                        .buttonStyle(.borderless)
                        .help(mostrar ? "Ocultar" : "Mostrar")
                }
                if !item.senha.isEmpty {
                    LabeledContent("Força", value: Forca.de(item.senha).nome)
                }
                TextField("Site", text: $item.url, prompt: Text("https://…"))
                TextField("Código 2FA (segredo)", text: $item.segredo2FA, prompt: Text("Opcional: segredo ou endereço otpauth://"))
                TextField("Notas", text: $item.notas, axis: .vertical).lineLimit(2...5)

                Section("Gerador de senha") {
                    HStack {
                        Text(sugestao)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                        Spacer()
                        Button("Gerar outra") { gerar() }
                        Button("Usar esta") {
                            item.senha = sugestao
                            mostrar = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Toggle("Frase de palavras (mais fácil de digitar)", isOn: $frase)
                    if !frase {
                        Slider(value: $tamanho, in: 8...40, step: 1) { Text("Tamanho: \(Int(tamanho))") }
                        Toggle("Números", isOn: $numeros)
                        Toggle("Símbolos", isOn: $simbolos)
                    } else {
                        Toggle("Terminar com número", isOn: $numeros)
                    }
                }
            }
            .formStyle(.grouped)
            .onChange(of: tamanho) { _, _ in gerar() }
            .onChange(of: numeros) { _, _ in gerar() }
            .onChange(of: simbolos) { _, _ in gerar() }
            .onChange(of: frase) { _, _ in gerar() }

            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    var novo = item
                    novo.nome = novo.nome.trimmingCharacters(in: .whitespaces)
                    novo.segredo2FA = novo.segredo2FA.isEmpty ? "" : TOTP.normalizar(novo.segredo2FA)
                    store.salvar(novo)
                    aoSalvar(novo)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(item.nome.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560, height: 640)
        .onAppear { gerar() }
    }

    private func gerar() {
        sugestao = frase
            ? GeradorSenha.frase(numero: numeros)
            : GeradorSenha.gerar(tamanho: Int(tamanho), numeros: numeros, simbolos: simbolos)
    }

    private func pastasEmOrdem(_ d: DadosSenhas) -> [(Pasta, Int)] {
        var r: [(Pasta, Int)] = []
        func visitar(_ pai: UUID?, _ nivel: Int) {
            for p in d.filhas(de: pai) {
                r.append((p, nivel))
                visitar(p.id, nivel + 1)
            }
        }
        visitar(nil, 0)
        return r
    }
}
