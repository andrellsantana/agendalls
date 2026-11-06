import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class SenhasStore {
    private(set) var dados = DadosSenhas()
    private(set) var carregado = false
    var erro: String?

    private let banco: BancoDeDados
    @ObservationIgnored private var salvamento: Task<Void, Never>?
    private static let chave = "senhas"
    /// A área de transferência é limpa depois deste tempo, se ainda tiver a senha copiada.
    static let tempoNaAreaDeTransferencia: TimeInterval = 60

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
    }

    func carregar() {
        do {
            if let bruto = try banco.lerCofre(Self.chave) {
                dados = try JSONDecoder().decode(DadosSenhas.self, from: bruto)
            } else {
                dados = .inicial
                try banco.gravarCofre(Self.chave, JSONEncoder().encode(dados))
            }
            carregado = true
        } catch {
            erro = "Não foi possível abrir as senhas: \(error)"
        }
    }

    func descarregar() {
        if salvamento != nil {
            salvamento?.cancel()
            gravarAgora()
        }
        dados = DadosSenhas()
        carregado = false
    }

    func alterar(_ mudanca: (inout DadosSenhas) -> Void) {
        guard carregado else { return }
        mudanca(&dados)
        salvamento?.cancel()
        salvamento = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.gravarAgora()
        }
    }

    // MARK: - Pastas

    @discardableResult
    func novaPasta(nome: String, dentroDe pai: UUID?) -> UUID {
        let p = Pasta(nome: nome, paiID: pai)
        alterar { $0.pastas.append(p) }
        return p.id
    }

    func renomearPasta(_ id: UUID, _ nome: String) {
        alterar { d in if let i = d.pastas.firstIndex(where: { $0.id == id }) { d.pastas[i].nome = nome } }
    }

    /// Só exclui pasta vazia (sem itens e sem subpastas).
    func podeExcluir(_ id: UUID) -> Bool {
        !dados.itens.contains { $0.pastaID == id } && !dados.pastas.contains { $0.paiID == id }
    }

    func excluirPasta(_ id: UUID) {
        guard podeExcluir(id) else { return }
        alterar { $0.pastas.removeAll { $0.id == id } }
    }

    // MARK: - Itens

    func salvar(_ item: ItemSenha) {
        alterar { d in
            if let i = d.itens.firstIndex(where: { $0.id == item.id }) {
                var novo = item
                if d.itens[i].senha != item.senha { novo.alteradaEm = Date() }
                d.itens[i] = novo
            } else {
                d.itens.append(item)
            }
        }
    }

    func excluir(_ item: ItemSenha) {
        alterar { $0.itens.removeAll { $0.id == item.id } }
    }

    func mover(_ item: ItemSenha, para pasta: UUID) {
        alterar { d in if let i = d.itens.firstIndex(where: { $0.id == item.id }) { d.itens[i].pastaID = pasta } }
    }

    /// Copia e limpa a área de transferência depois de 1 minuto, se ninguém copiou outra coisa.
    func copiar(_ texto: String) {
        let area = NSPasteboard.general
        area.clearContents()
        area.setString(texto, forType: .string)
        let contagem = area.changeCount
        Task {
            try? await Task.sleep(for: .seconds(Self.tempoNaAreaDeTransferencia))
            if NSPasteboard.general.changeCount == contagem { NSPasteboard.general.clearContents() }
        }
    }

    private func gravarAgora() {
        salvamento = nil
        guard carregado else { return }
        do {
            try banco.gravarCofre(Self.chave, JSONEncoder().encode(dados))
        } catch {
            erro = "Não foi possível salvar: \(error)"
        }
    }
}
