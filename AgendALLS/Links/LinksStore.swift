import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class LinksStore {
    private(set) var links: [LinkSalvo] = []
    private(set) var logos: [Int64: NSImage] = [:]
    /// Links cujo logotipo está sendo buscado agora.
    private(set) var buscando: Set<Int64> = []
    /// `nil` = todas as categorias.
    var filtro: String?
    private(set) var navegadorID: String = Navegador.safari
    var erro: String?

    private let banco: BancoDeDados
    private let pastaLogos: URL

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
        pastaLogos = BancoDeDados.pastaDoApp.appendingPathComponent("Logos", isDirectory: true)
        try? FileManager.default.createDirectory(at: pastaLogos, withIntermediateDirectories: true)
        if let v = banco.config("links.navegador") { navegadorID = v }
        atualizarNomeDoNavegador()
        recarregar()
    }

    // MARK: - Consultas

    /// Categorias em ordem alfabética.
    var categorias: [String] {
        Array(Set(links.map(\.categoria))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Links de uma categoria em ordem alfabética.
    func links(da categoria: String) -> [LinkSalvo] {
        links.filter { $0.categoria == categoria }
            .sorted { $0.titulo.localizedStandardCompare($1.titulo) == .orderedAscending }
    }

    private(set) var nomeDoNavegador = "Safari"

    private func atualizarNomeDoNavegador() {
        nomeDoNavegador = Navegador.instalados().first { $0.id == navegadorID }?.nome ?? "Safari"
    }

    // MARK: - Ações

    static func normalizar(_ endereco: String) -> String {
        let s = endereco.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return s }
        return s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil ? "https://" + s : s
    }

    func adicionar(titulo: String, url: String, categoria: String) {
        let endereco = Self.normalizar(url)
        guard URL(string: endereco)?.host != nil else {
            erro = "Endereço inválido: \(url)"
            return
        }
        let cat = Self.limparCategoria(categoria)
        var novo = LinkSalvo(id: 0, titulo: titulo.trimmingCharacters(in: .whitespaces), url: endereco, categoria: cat, cor: nil, temLogo: false)
        if novo.titulo.isEmpty { novo.titulo = novo.dominio }
        do {
            novo.id = try banco.executar(
                "INSERT INTO link (titulo, url, categoria, criado_em) VALUES (?, ?, ?, ?)",
                [.texto(novo.titulo), .texto(novo.url), .texto(novo.categoria), .real(Date().timeIntervalSince1970)]
            )
            links.append(novo)
            buscarLogo(novo)
        } catch {
            erro = "\(error)"
        }
    }

    func atualizar(_ link: LinkSalvo) {
        var l = link
        l.url = Self.normalizar(l.url)
        l.categoria = Self.limparCategoria(l.categoria)
        if l.titulo.trimmingCharacters(in: .whitespaces).isEmpty { l.titulo = l.dominio }
        let anterior = links.first { $0.id == l.id }
        let mudouEndereco = anterior?.dominio != l.dominio
        if mudouEndereco { l.cor = nil; l.temLogo = false }
        salvar(l)
        if mudouEndereco {
            logos[l.id] = nil
            buscarLogo(l)
        }
    }

    func mover(_ link: LinkSalvo, para categoria: String) {
        guard link.categoria != categoria else { return }
        var l = link
        l.categoria = categoria
        salvar(l)
    }

    func excluir(_ link: LinkSalvo) {
        do {
            try banco.executar("DELETE FROM link WHERE id = ?", [.inteiro(Int(link.id))])
            try? FileManager.default.removeItem(at: arquivoLogo(link.id))
            links.removeAll { $0.id == link.id }
            logos[link.id] = nil
            if let f = filtro, !categorias.contains(f) { filtro = nil }
        } catch {
            erro = "\(error)"
        }
    }

    func abrir(_ link: LinkSalvo) {
        guard let url = URL(string: link.url) else { return }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: navegadorID) {
            NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func definirNavegador(_ id: String) {
        navegadorID = id
        banco.definirConfig("links.navegador", id)
        atualizarNomeDoNavegador()
    }

    func buscarLogo(_ link: LinkSalvo) {
        guard let url = URL(string: link.url), !buscando.contains(link.id) else { return }
        buscando.insert(link.id)
        Task {
            let resultado = await BuscadorLogo.buscar(para: url)
            self.buscando.remove(link.id)
            guard var atual = self.links.first(where: { $0.id == link.id }) else { return }
            if let resultado {
                try? resultado.png.write(to: self.arquivoLogo(link.id))
                self.logos[link.id] = NSImage(data: resultado.png)
                atual.temLogo = true
                atual.cor = resultado.cor
            } else {
                atual.temLogo = false
            }
            self.salvar(atual)
        }
    }

    // MARK: - Persistência

    private static func limparCategoria(_ c: String) -> String {
        var s = c.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix("#") { s.removeFirst() }
        return s.isEmpty ? "Geral" : s
    }

    private func arquivoLogo(_ id: Int64) -> URL {
        pastaLogos.appendingPathComponent("\(id).png")
    }

    private func salvar(_ l: LinkSalvo) {
        do {
            try banco.executar(
                "UPDATE link SET titulo = ?, url = ?, categoria = ?, cor = ?, tem_logo = ? WHERE id = ?",
                [.texto(l.titulo), .texto(l.url), .texto(l.categoria), l.cor.map { .texto($0) } ?? .nulo,
                 .inteiro(l.temLogo ? 1 : 0), .inteiro(Int(l.id))]
            )
            if let i = links.firstIndex(where: { $0.id == l.id }) { links[i] = l }
            if let f = filtro, !categorias.contains(f) { filtro = nil }
        } catch {
            erro = "\(error)"
        }
    }

    private func recarregar() {
        do {
            links = try banco.consultar("SELECT id, titulo, url, categoria, cor, tem_logo FROM link").map { l in
                LinkSalvo(
                    id: Int64(l[0].inteiro ?? 0),
                    titulo: l[1].texto ?? "",
                    url: l[2].texto ?? "",
                    categoria: l[3].texto ?? "Geral",
                    cor: l[4].texto,
                    temLogo: (l[5].inteiro ?? 0) != 0
                )
            }
            for link in links where link.temLogo {
                logos[link.id] = NSImage(contentsOf: arquivoLogo(link.id))
            }
        } catch {
            erro = "\(error)"
        }
    }
}
