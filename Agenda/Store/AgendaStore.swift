import Foundation
import Observation

@Observable
final class AgendaStore {
    private(set) var agendamentos: [Agendamento] = []
    var erro: String?
    private let db: Database?

    init(db: Database? = try? Database()) {
        self.db = db
        if db == nil { erro = "Não foi possível abrir o banco de dados." }
        recarregar()
    }

    /// Agendamentos agrupados por dia, em ordem cronológica.
    var porDia: [(dia: Date, itens: [Agendamento])] {
        let grupos = Dictionary(grouping: agendamentos) { Calendar.current.startOfDay(for: $0.data) }
        return grupos.keys.sorted().map { ($0, grupos[$0]!) }
    }

    func recarregar() {
        do { agendamentos = try db?.listar() ?? [] } catch { self.erro = "\(error)" }
    }

    func salvar(_ a: Agendamento) {
        do {
            var salvo = a
            salvo.id = try db?.salvar(a)
            Notificacoes.agendar(salvo)
            recarregar()
        } catch { self.erro = "\(error)" }
    }

    func excluir(_ a: Agendamento) {
        guard let id = a.id else { return }
        do {
            try db?.excluir(id: id)
            Notificacoes.cancelar(id: id)
            recarregar()
        } catch { self.erro = "\(error)" }
    }
}
