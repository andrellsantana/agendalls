import SwiftUI

struct Remedio: Identifiable, Hashable {
    var id: Int64
    var nome: String
    var laboratorio: String
    var dosagem: String
    /// Horários do dia, "HH:mm", em ordem.
    var horarios: [String]
    var objetivo: String
    /// Unidades em casa (comprimidos, cápsulas, doses…).
    var estoque: Int
    /// Unidades gastas em cada dose.
    var porDose: Int
    /// Avisar quando o estoque der para menos que estes dias.
    var avisoDias: Int
    /// Tom da cor do remédio (0–1).
    var tom: Double

    /// Quantos dias o estoque ainda dura. `nil` se não há horários.
    var diasRestantes: Int? {
        let porDia = porDose * horarios.count
        guard porDia > 0 else { return nil }
        return estoque / porDia
    }

    var estoqueAcabando: Bool {
        guard let dias = diasRestantes else { return false }
        return dias <= avisoDias
    }

    var cor: Color { Color(hue: tom, saturation: 0.55, brightness: 0.62) }
    var corClara: Color { Color(hue: tom, saturation: 0.18, brightness: 0.98) }
    var corBorda: Color { Color(hue: tom, saturation: 0.3, brightness: 0.86) }
    var corTexto: Color { Color(hue: tom, saturation: 0.6, brightness: 0.32) }
}

/// O que aconteceu com uma dose de hoje.
enum SituacaoDose: String, CaseIterable, Identifiable {
    case naHora = "na_hora"
    case atrasada = "atrasada"
    case naoTomei = "nao_tomei"

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .naHora: "Tomei na hora certa"
        case .atrasada: "Tomei fora do horário"
        case .naoTomei: "Não tomei"
        }
    }

    var curto: String {
        switch self {
        case .naHora: "Na hora"
        case .atrasada: "Fora do horário"
        case .naoTomei: "Não tomei"
        }
    }

    var icone: String {
        switch self {
        case .naHora: "checkmark.circle.fill"
        case .atrasada: "clock.badge.exclamationmark.fill"
        case .naoTomei: "xmark.circle.fill"
        }
    }

    var cor: Color {
        switch self {
        case .naHora: .green
        case .atrasada: .orange
        case .naoTomei: .red
        }
    }

    /// Dose tomada gasta estoque.
    var gastaEstoque: Bool { self != .naoTomei }
}

struct RegistroDose: Hashable {
    var situacao: SituacaoDose
    /// Horário em que realmente tomou, quando fora do horário.
    var horaReal: String?
}
