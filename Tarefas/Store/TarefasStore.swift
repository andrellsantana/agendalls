import Foundation
import Observation

@Observable
final class TarefasStore {
    private(set) var tarefas: [Tarefa] = []
    var erro: String?
    var pedidoNovaTarefa = false
    private let db: Database?

    init(db: Database? = try? Database()) {
        self.db = db
        if db == nil { erro = "Não foi possível abrir o banco de dados." }
        recarregar()
    }

    private func tentar(_ acao: () throws -> Void) {
        do { try acao() } catch { self.erro = "\(error)" }
        recarregar()
    }

    func recarregar() {
        do { tarefas = try db?.listar() ?? [] } catch { erro = "\(error)" }
    }

    /// Cria uma tarefa no fim da lista e espalha a anotação pela mesa.
    func adicionar(titulo: String, notas: String) {
        let n = tarefas.count
        let nova = Tarefa(
            id: nil, titulo: titulo, notas: notas,
            ordem: (tarefas.map(\.ordem).max() ?? -1) + 1,
            x: 160 + Double(n % 6) * 240 + .random(in: -30...30),
            y: 160 + Double((n / 6) % 4) * 230 + .random(in: -30...30),
            rotacao: .random(in: -6...6)
        )
        tentar { try db?.salvar(nova) }
    }

    func atualizar(_ t: Tarefa) { tentar { try db?.salvar(t) } }

    func excluir(_ t: Tarefa) {
        guard let id = t.id else { return }
        tentar { try db?.excluir(id: id) }
    }

    func mover(de origem: IndexSet, para destino: Int) {
        var lista = tarefas
        lista.move(fromOffsets: origem, toOffset: destino)
        tarefas = lista   // atualiza a tela na hora
        tentar { try db?.reordenar(ids: lista.compactMap(\.id)) }
    }

    func moverNaMesa(_ t: Tarefa, para ponto: CGPoint) {
        var t = t
        t.x = ponto.x
        t.y = ponto.y
        atualizar(t)
    }

    /// Prioridade exibida (1 = mais importante).
    func prioridade(de t: Tarefa) -> Int {
        (tarefas.firstIndex { $0.id == t.id } ?? 0) + 1
    }
}
