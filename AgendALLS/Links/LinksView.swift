import SwiftUI

struct LinksView: View {
    @Environment(LinksStore.self) private var store
    @State private var editando: LinkSalvo?
    @State private var alvoDoArraste: String?

    var body: some View {
        VStack(spacing: 0) {
            FormularioNovoLink()
                .padding(.horizontal, 28)
                .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !store.categorias.isEmpty {
                        FiltroDeCategorias()
                    }
                    if store.links.isEmpty {
                        ContentUnavailableView(
                            "Nenhum link",
                            systemImage: "square.grid.2x2",
                            description: Text("Informe título, link e categoria acima e clique em Adicionar.")
                        )
                        .padding(.top, 40)
                    }
                    ForEach(store.categorias.filter { store.filtro == nil || store.filtro == $0 }, id: \.self) { categoria in
                        secao(categoria)
                    }
                    if !store.links.isEmpty {
                        Text("Clique duas vezes num card para abrir no \(store.nomeDoNavegador). Arraste um card até outra categoria para movê-lo. Botão direito: editar, mover ou excluir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(28)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $editando) { EditorLinkView(link: $0) }
        .alert("Erro", isPresented: Binding(get: { store.erro != nil }, set: { if !$0 { store.erro = nil } })) {
            Button("OK") { store.erro = nil }
        } message: {
            Text(store.erro ?? "")
        }
    }

    private func secao(_ categoria: String) -> some View {
        let destacada = alvoDoArraste == categoria
        return VStack(alignment: .leading, spacing: 12) {
            TagCategoria(nome: categoria, forte: false)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                ForEach(store.links(da: categoria)) { link in
                    CartaoLink(link: link, logo: store.logos[link.id], buscando: store.buscando.contains(link.id))
                        .onTapGesture(count: 2) { store.abrir(link) }
                        .help("Clique duas vezes para abrir no \(store.nomeDoNavegador)")
                        .draggable(String(link.id)) {
                            CartaoLink(link: link, logo: store.logos[link.id], buscando: false)
                                .frame(width: 200)
                        }
                        .contextMenu { menu(link) }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(destacada ? CoresLink.tag(categoria, forte: true).borda : .clear, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
        )
        .padding(-10)
        .dropDestination(for: String.self) { itens, _ in
            guard let id = itens.first.flatMap(Int64.init), let link = store.links.first(where: { $0.id == id }) else { return false }
            store.mover(link, para: categoria)
            return true
        } isTargeted: { dentro in
            alvoDoArraste = dentro ? categoria : (alvoDoArraste == categoria ? nil : alvoDoArraste)
        }
    }

    @ViewBuilder
    private func menu(_ link: LinkSalvo) -> some View {
        Button("Abrir no \(store.nomeDoNavegador)") { store.abrir(link) }
        Button("Editar…") { editando = link }
        Menu("Mover para") {
            ForEach(store.categorias.filter { $0 != link.categoria }, id: \.self) { c in
                Button("#\(c)") { store.mover(link, para: c) }
            }
        }
        Button("Buscar logotipo de novo") { store.buscarLogo(link) }
        Divider()
        Button("Excluir", role: .destructive) { store.excluir(link) }
    }
}

// MARK: - Card

struct CartaoLink: View {
    let link: LinkSalvo
    let logo: NSImage?
    let buscando: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                LogoLink(link: link, logo: logo, buscando: buscando)
                Text(link.titulo)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(CoresLink.textoCard(link))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 1)
            }
            Spacer(minLength: 6)
            Text(link.dominio)
                .font(.caption)
                .foregroundStyle(CoresLink.textoSecundarioCard(link))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(14)
        .frame(height: 96)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CoresLink.fundoCard(link), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(CoresLink.bordaCard(link)))
        .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

private struct LogoLink: View {
    let link: LinkSalvo
    let logo: NSImage?
    let buscando: Bool

    var body: some View {
        ZStack {
            if let logo {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .background(.white)
            } else {
                CoresLink.monograma(link)
                Text(link.inicial)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(.white)
                if buscando {
                    ProgressView().controlSize(.small).tint(.white)
                        .background(CoresLink.monograma(link))
                }
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

// MARK: - Tags

struct TagCategoria: View {
    let nome: String
    let forte: Bool

    var body: some View {
        let c = CoresLink.tag(nome, forte: forte)
        Text("#\(nome)")
            .font(.caption.weight(.bold))
            .foregroundStyle(c.texto)
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(c.fundo, in: Capsule())
            .overlay(Capsule().strokeBorder(c.borda, lineWidth: 1.5))
    }
}

private struct FiltroDeCategorias: View {
    @Environment(LinksStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { store.filtro = nil } label: {
                    Text("Todas")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.filtro == nil ? Color.white : Color.primary)
                        .padding(.horizontal, 14)
                        .frame(height: 26)
                        .background(store.filtro == nil ? Color.primary : Color.clear, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                ForEach(store.categorias, id: \.self) { c in
                    Button { store.filtro = (store.filtro == c ? nil : c) } label: {
                        TagCategoria(nome: c, forte: store.filtro == c)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.filtro == c ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Formulários

private struct FormularioNovoLink: View {
    @Environment(LinksStore.self) private var store
    @State private var titulo = ""
    @State private var endereco = ""
    @State private var categoria = ""

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            campo("Título") { TextField("Ex.: Extrato do banco", text: $titulo) }
            campo("Link") { TextField("https://…", text: $endereco).onSubmit(adicionar) }
            campo("Categoria") { CampoCategoria(texto: $categoria) }
                .frame(maxWidth: 200)
            Button("Adicionar", action: adicionar)
                .keyboardShortcut(.defaultAction)
                .disabled(endereco.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .textFieldStyle(.roundedBorder)
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
    }

    private func campo<C: View>(_ rotulo: String, @ViewBuilder _ conteudo: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rotulo).font(.caption).foregroundStyle(.secondary)
            conteudo()
        }
    }

    private func adicionar() {
        guard !endereco.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        store.adicionar(titulo: titulo, url: endereco, categoria: categoria)
        titulo = ""
        endereco = ""
    }
}

/// Campo de categoria com a lista das já existentes.
private struct CampoCategoria: View {
    @Environment(LinksStore.self) private var store
    @Binding var texto: String

    var body: some View {
        HStack(spacing: 4) {
            TextField("Escolha ou crie", text: $texto)
            Menu {
                ForEach(store.categorias, id: \.self) { c in
                    Button("#\(c)") { texto = c }
                }
            } label: {
                Image(systemName: "chevron.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.categorias.isEmpty)
            .help("Categorias existentes")
        }
    }
}

struct EditorLinkView: View {
    @Environment(LinksStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let link: LinkSalvo
    @State private var titulo = ""
    @State private var endereco = ""
    @State private var categoria = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editar link").font(.title2.bold())
            Form {
                TextField("Título", text: $titulo)
                TextField("Link", text: $endereco)
                LabeledContent("Categoria") { CampoCategoria(texto: $categoria) }
            }
            HStack {
                Spacer()
                Button("Cancelar", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    var l = link
                    l.titulo = titulo
                    l.url = endereco
                    l.categoria = categoria
                    store.atualizar(l)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(endereco.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear {
            titulo = link.titulo
            endereco = link.url
            categoria = link.categoria
        }
    }
}
