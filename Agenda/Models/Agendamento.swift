import Foundation

struct Agendamento: Identifiable, Hashable {
    var id: Int64?
    var titulo: String
    var cliente: String
    var data: Date
    var notas: String
    var lembreteMinutos: Int?   // nil = sem lembrete

    static func novo() -> Agendamento {
        let proximaHora = Calendar.current.nextDate(
            after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now
        return Agendamento(id: nil, titulo: "", cliente: "", data: proximaHora, notas: "", lembreteMinutos: 15)
    }
}
