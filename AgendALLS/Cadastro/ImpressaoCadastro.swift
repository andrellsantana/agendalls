import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Folha A4 (595 × 842 pt) do modelo escolhido.
struct FolhaA4: View {
    let dados: DadosCadastro
    let modelo: ModeloImpressao
    let secoes: Set<SecaoCadastro>

    static let tamanho = CGSize(width: 595, height: 842)

    var body: some View {
        Group {
            if modelo == .curriculo {
                CurriculoA4(d: dados)
            } else {
                FichaA4(d: dados, secoes: secoesDaFicha)
            }
        }
        .frame(width: Self.tamanho.width, height: Self.tamanho.height, alignment: .top)
        .background(.white)
        .environment(\.colorScheme, .light)
    }

    private var secoesDaFicha: [SecaoCadastro] {
        switch modelo {
        case .fichaCompleta: SecaoCadastro.deCampos
        case .documentos: [.documentos]
        case .personalizado, .curriculo: SecaoCadastro.deCampos.filter { secoes.contains($0) }
        }
    }
}

// MARK: - Currículo (tema azul-marinho com foto no círculo)

private struct CurriculoA4: View {
    let d: DadosCadastro
    private let marinho = Color(red: 0.243, green: 0.325, blue: 0.447)
    private let cinza = Color(red: 0.953, green: 0.953, blue: 0.953)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 30) {
                FotoCircular(foto: d.foto, zoom: d.fotoZoom, x: d.fotoX, y: d.fotoY, diametro: 118)
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 3))
                VStack(alignment: .leading, spacing: 10) {
                    Text(d.valor("nome").isEmpty ? "Seu nome" : d.valor("nome"))
                        .font(.system(size: 36, weight: .regular))
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text(d.valor("cargo").uppercased())
                        .font(.system(size: 14, weight: .light))
                        .tracking(0.8)
                        .opacity(0.85)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.leading, 48)
            .padding(.trailing, 36)
            .frame(height: 150)
            .background(marinho)

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    bloco("CONTATO") {
                        contato("phone.fill", d.valor("telefone"))
                        contato("envelope", d.valor("email"))
                        contato("mappin.and.ellipse", d.valor("cidade"))
                        contato("link", d.valor("linkedin"))
                    }
                    lista("IDIOMAS", DadosCadastro.linhas(d.idiomas), marcador: false)
                    lista("HABILIDADES", DadosCadastro.linhas(d.habilidades), marcador: true)
                    if !d.programas.isEmpty {
                        bloco("PROGRAMAS") {
                            ForEach(d.programas) { p in
                                HStack {
                                    Text(p.nome)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        ForEach(1...5, id: \.self) { n in
                                            Circle()
                                                .fill(n <= p.nivel ? Color.black : Color(white: 0.78))
                                                .frame(width: 6, height: 6)
                                        }
                                    }
                                }
                                .font(.system(size: 9))
                            }
                        }
                    }
                    lista("INTERESSES", DadosCadastro.linhas(d.interesses), marcador: true)
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 22, leading: 22, bottom: 18, trailing: 18))
                .frame(width: 205, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 16) {
                    if !d.perfil.isEmpty {
                        bloco("PERFIL PROFISSIONAL") {
                            Text(d.perfil).font(.system(size: 9.5)).lineSpacing(2)
                        }
                    }
                    if !d.experiencias.isEmpty {
                        bloco("EXPERIÊNCIA PROFISSIONAL") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(d.experiencias) { e in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.cargo).font(.system(size: 10.5, weight: .bold))
                                        linhaLocal(e.empresa, e.cidade, e.periodo)
                                        ForEach(DadosCadastro.linhas(e.realizacoes), id: \.self) { r in
                                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                                Text("•")
                                                Text(r)
                                            }
                                            .font(.system(size: 8.5))
                                            .padding(.leading, 6)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if !d.formacao.isEmpty {
                        bloco("FORMAÇÃO ACADÊMICA") {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(d.formacao) { f in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(f.curso).font(.system(size: 10.5, weight: .bold))
                                        linhaLocal(f.instituicao, f.cidade, f.periodo)
                                    }
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(EdgeInsets(top: 22, leading: 22, bottom: 18, trailing: 26))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(cinza)
            }
        }
        .foregroundStyle(Color(white: 0.07))
    }

    private func bloco<C: View>(_ titulo: String, @ViewBuilder _ conteudo: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.system(size: 13, weight: .medium))
                Rectangle().frame(height: 1)
            }
            conteudo()
        }
    }

    @ViewBuilder
    private func lista(_ titulo: String, _ itens: [String], marcador: Bool) -> some View {
        if !itens.isEmpty {
            bloco(titulo) {
                ForEach(itens, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        if marcador { Text("•") }
                        Text(item)
                    }
                    .font(.system(size: 9))
                }
            }
        }
    }

    @ViewBuilder
    private func contato(_ icone: String, _ texto: String) -> some View {
        if !texto.isEmpty {
            HStack(spacing: 7) {
                Image(systemName: icone).font(.system(size: 8)).frame(width: 10)
                Text(texto).font(.system(size: 9)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func linhaLocal(_ lugar: String, _ cidade: String, _ periodo: String) -> some View {
        (Text(lugar).italic()
            + Text(cidade.isEmpty ? "" : ", \(cidade)")
            + Text(periodo.isEmpty ? "" : "  |  \(periodo)").foregroundColor(Color(white: 0.55)))
            .font(.system(size: 9.5))
    }
}

// MARK: - Fichas

private struct FichaA4: View {
    let d: DadosCadastro
    let secoes: [SecaoCadastro]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(secoes == [.documentos] ? "DOCUMENTOS" : "FICHA CADASTRAL")
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1)
                Text(d.valor("nome")).font(.system(size: 12))
                Rectangle().frame(height: 1.2)
            }
            ForEach(secoes) { secao in
                let linhas = linhasDe(secao)
                if !linhas.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(secao.nome.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(Color(red: 0.243, green: 0.325, blue: 0.447))
                        ForEach(linhas.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(linhas[i].0).foregroundStyle(Color(white: 0.4)).frame(width: 140, alignment: .leading)
                                Text(linhas[i].1)
                            }
                            .font(.system(size: 10))
                            .padding(.vertical, 2)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color(white: 0.9)).frame(height: 0.5) }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(48)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Color(white: 0.07))
    }

    private func linhasDe(_ secao: SecaoCadastro) -> [(String, String)] {
        guard case .campos(let campos) = secao.tipo else { return [] }
        let fixos = campos.map { ($0.rotulo, d.valor($0.chave)) }
        let extras = d.extras.filter { $0.secao == secao.rawValue }.map { ($0.rotulo, $0.valor) }
        return (fixos + extras).filter { !$0.1.isEmpty }
    }
}

// MARK: - PDF e impressão

@MainActor
enum Exportador {
    static func pdf(_ folha: FolhaA4) -> Data? {
        let renderizador = ImageRenderer(content: folha)
        renderizador.proposedSize = ProposedViewSize(FolhaA4.tamanho)
        let dados = NSMutableData()
        renderizador.render { tamanho, desenhar in
            var caixa = CGRect(origin: .zero, size: tamanho)
            guard let consumidor = CGDataConsumer(data: dados as CFMutableData),
                  let ctx = CGContext(consumer: consumidor, mediaBox: &caixa, nil)
            else { return }
            ctx.beginPDFPage(nil)
            desenhar(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }
        return dados.length > 0 ? dados as Data : nil
    }

    static func salvarPDF(_ folha: FolhaA4, nomeSugerido: String) {
        guard let dados = pdf(folha) else { return }
        let painel = NSSavePanel()
        painel.allowedContentTypes = [.pdf]
        painel.nameFieldStringValue = nomeSugerido
        painel.canCreateDirectories = true
        if painel.runModal() == .OK, let url = painel.url {
            try? dados.write(to: url)
        }
    }

    static func imprimir(_ folha: FolhaA4) {
        guard let dados = pdf(folha), let documento = PDFDocument(data: dados) else { return }
        let info = NSPrintInfo.shared
        info.paperSize = NSSize(width: 595, height: 842)
        info.topMargin = 0; info.bottomMargin = 0; info.leftMargin = 0; info.rightMargin = 0
        documento.printOperation(for: info, scalingMode: .pageScaleToFit, autoRotate: false)?.runModal(for: NSApp.keyWindow ?? NSWindow(), delegate: nil, didRun: nil, contextInfo: nil)
    }
}
