import Foundation
import Observation

@MainActor
@Observable
final class TarefasStore {
    /// Em ordem de prioridade.
    private(set) var tarefas: [Tarefa] = []
    private(set) var modo: ModoTarefas = .lista
    private(set) var fundo: FundoMesa = .madeiraClara
    var erro: String?

    private let banco: BancoDeDados

    /// Tamanho da mesa, em pontos.
    static let tamanhoMesa = CGSize(width: 2400, height: 1600)

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
        if let v = banco.config("tarefas.modo").flatMap(ModoTarefas.init(rawValue:)) { modo = v }
        if let v = banco.config("tarefas.fundo").flatMap(FundoMesa.init(rawValue:)) { fundo = v }
        recarregar()
    }

    func prioridade(de tarefa: Tarefa) -> Int {
        (tarefas.firstIndex { $0.id == tarefa.id } ?? 0) + 1
    }

    // MARK: - Ações

    func adicionar(titulo: String, notas: String) {
        let t = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        let n = tarefas.count
        let x = 170 + Double(n % 7) * 240 + .random(in: -30...30)
        let y = 170 + Double((n / 7) % 5) * 260 + .random(in: -30...30)
        salvar {
            try banco.executar(
                "INSERT INTO tarefa (titulo, notas, ordem, x, y, rotacao, criada_em) VALUES (?, ?, ?, ?, ?, ?, ?)",
                [.texto(t), .texto(notas), .inteiro((tarefas.map(\.ordem).max() ?? -1) + 1),
                 .real(x), .real(y), .real(.random(in: -6...6)), .real(Date().timeIntervalSince1970)]
            )
        }
        recarregar()
    }

    func atualizar(_ t: Tarefa) {
        salvar {
            try banco.executar(
                "UPDATE tarefa SET titulo = ?, notas = ?, feita = ?, ordem = ?, x = ?, y = ?, rotacao = ?, papel = ?, destaques = ? WHERE id = ?",
                [.texto(t.titulo), .texto(t.notas), .inteiro(t.feita ? 1 : 0), .inteiro(t.ordem),
                 .real(t.x), .real(t.y), .real(t.rotacao), .texto(t.papel.rawValue),
                 .texto(t.destaques.sorted().map(String.init).joined(separator: ",")), .inteiro(Int(t.id))]
            )
        }
        if let i = tarefas.firstIndex(where: { $0.id == t.id }) { tarefas[i] = t }
    }

    func excluir(_ t: Tarefa) {
        salvar { try banco.executar("DELETE FROM tarefa WHERE id = ?", [.inteiro(Int(t.id))]) }
        tarefas.removeAll { $0.id == t.id }
    }

    /// Arrastar e soltar na lista: muda a prioridade.
    func mover(de origem: IndexSet, para destino: Int) {
        var lista = tarefas
        lista.move(fromOffsets: origem, toOffset: destino)
        for i in lista.indices { lista[i].ordem = i }
        tarefas = lista
        salvar {
            try banco.executarScript("BEGIN")
            do {
                for t in lista {
                    try banco.executar("UPDATE tarefa SET ordem = ? WHERE id = ?", [.inteiro(t.ordem), .inteiro(Int(t.id))])
                }
                try banco.executarScript("COMMIT")
            } catch {
                try? banco.executarScript("ROLLBACK")
                throw error
            }
        }
    }

    func definirFeita(_ t: Tarefa, _ feita: Bool) {
        var n = t; n.feita = feita; atualizar(n)
    }

    func moverNaMesa(_ t: Tarefa, para x: Double, _ y: Double) {
        var n = t
        n.x = min(max(x, 110), Self.tamanhoMesa.width - 110)
        n.y = min(max(y, 110), Self.tamanhoMesa.height - 110)
        atualizar(n)
    }

    func alternarDestaque(_ t: Tarefa, palavra: Int) {
        var n = t
        if n.destaques.contains(palavra) { n.destaques.remove(palavra) } else { n.destaques.insert(palavra) }
        atualizar(n)
    }

    func definirPapel(_ t: Tarefa, _ papel: PapelNota) {
        var n = t; n.papel = papel; atualizar(n)
    }

    func definirModo(_ m: ModoTarefas) {
        modo = m
        banco.definirConfig("tarefas.modo", m.rawValue)
    }

    func definirFundo(_ f: FundoMesa) {
        fundo = f
        banco.definirConfig("tarefas.fundo", f.rawValue)
    }

    // MARK: - Persistência

    func recarregar() {
        do {
            tarefas = try banco.consultar(
                "SELECT id, titulo, notas, feita, ordem, x, y, rotacao, papel, destaques FROM tarefa ORDER BY ordem, id"
            ).map { l in
                Tarefa(
                    id: Int64(l[0].inteiro ?? 0),
                    titulo: l[1].texto ?? "",
                    notas: l[2].texto ?? "",
                    feita: (l[3].inteiro ?? 0) != 0,
                    ordem: l[4].inteiro ?? 0,
                    x: l[5].real ?? 0,
                    y: l[6].real ?? 0,
                    rotacao: l[7].real ?? 0,
                    papel: PapelNota(rawValue: l[8].texto ?? "") ?? .cinza,
                    destaques: Set((l[9].texto ?? "").split(separator: ",").compactMap { Int($0) })
                )
            }
        } catch {
            erro = "\(error)"
        }
    }

    private func salvar(_ acao: () throws -> Void) {
        do { try acao() } catch { erro = "\(error)" }
    }
}
