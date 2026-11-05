import Foundation

/// Ajuste de um dia específico: positivo acrescenta tempo à saída, negativo desconta.
struct Ajuste: Identifiable, Hashable {
    var id: Int64
    var minutos: Int
    var descricao: String
}

/// Resultado de sair num determinado horário.
enum SituacaoSaida: Equatable {
    /// Dentro da tolerância: conta como horário padrão.
    case noHorario
    /// Saiu antes da tolerância: deve a diferença inteira (em minutos).
    case devendo(Int)
    /// Saiu depois da tolerância: faz a diferença inteira como hora extra (em minutos).
    case horaExtra(Int)
}

/// Regras do ponto. Não guarda estado: só calcula.
struct PontoCalculo {
    /// Tempo entre entrada e saída, já incluindo o almoço (padrão: 9h = 8h trabalhadas + 1h de almoço).
    var jornadaMinutos = 540
    /// Tolerância antes e depois da saída padrão (padrão: 10 min). Vale só para a saída.
    var toleranciaMinutos = 10

    func totalAjustes(_ ajustes: [Ajuste]) -> Int {
        ajustes.reduce(0) { $0 + $1.minutos }
    }

    func saidaPadrao(entrada: Date, ajustes: [Ajuste]) -> Date {
        entrada.addingTimeInterval(TimeInterval((jornadaMinutos + totalAjustes(ajustes)) * 60))
    }

    func inicioTolerancia(saidaPadrao: Date) -> Date {
        saidaPadrao.addingTimeInterval(TimeInterval(-toleranciaMinutos * 60))
    }

    func fimTolerancia(saidaPadrao: Date) -> Date {
        saidaPadrao.addingTimeInterval(TimeInterval(toleranciaMinutos * 60))
    }

    /// Fora da tolerância conta a diferença inteira em relação à saída padrão.
    func situacao(saida: Date, saidaPadrao: Date) -> SituacaoSaida {
        let diferenca = Int((saida.timeIntervalSince(saidaPadrao) / 60).rounded())
        if abs(diferenca) <= toleranciaMinutos { return .noHorario }
        return diferenca < 0 ? .devendo(-diferenca) : .horaExtra(diferenca)
    }
}

extension Date {
    /// Mesmo horário, sem os segundos.
    var semSegundos: Date {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: self)
        return cal.date(from: c) ?? self
    }

    /// Minutos desde a meia-noite.
    var minutosDoDia: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Hoje, no horário dado em minutos desde a meia-noite.
    static func hoje(minutos: Int) -> Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(minutos * 60))
    }
}
