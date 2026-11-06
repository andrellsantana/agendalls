import SwiftUI

struct Tarefa: Identifiable, Hashable {
    var id: Int64
    var titulo: String
    var notas: String
    var feita: Bool
    /// Posição na lista: 0 é a mais prioritária.
    var ordem: Int
    /// Centro do recorte na mesa.
    var x: Double
    var y: Double
    /// Inclinação do recorte na mesa, em graus.
    var rotacao: Double
    var papel: PapelNota
    /// Índices das palavras do título destacadas com marca-texto.
    var destaques: Set<Int>

    var palavras: [String] {
        titulo.split(whereSeparator: \.isWhitespace).map(String.init)
    }
}

enum ModoTarefas: String {
    case lista, mesa
}

/// Cores de papel das notas na mesa. Cinza é o padrão.
enum PapelNota: String, CaseIterable, Identifiable {
    case cinza, branco, ciano, verdePiscina, amareloClarinho, rosaClaro

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .cinza: "Cinza"
        case .branco: "Branco"
        case .ciano: "Ciano"
        case .verdePiscina: "Verde piscina"
        case .amareloClarinho: "Amarelo clarinho"
        case .rosaClaro: "Rosa claro"
        }
    }

    var cor: Color {
        switch self {
        case .cinza: Color(red: 0.851, green: 0.851, blue: 0.839)
        case .branco: Color(red: 0.969, green: 0.969, blue: 0.957)
        case .ciano: Color(red: 0.812, green: 0.933, blue: 0.953)
        case .verdePiscina: Color(red: 0.776, green: 0.922, blue: 0.875)
        case .amareloClarinho: Color(red: 0.973, green: 0.945, blue: 0.784)
        case .rosaClaro: Color(red: 0.969, green: 0.863, blue: 0.890)
        }
    }
}

/// Fundos da mesa.
enum FundoMesa: String, CaseIterable, Identifiable {
    case madeiraDesenhada, madeiraClara, nogueira, tabuasClaras, tabuasAvermelhadas, branco

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .madeiraDesenhada: "Madeira desenhada"
        case .madeiraClara: "Madeira clara"
        case .nogueira: "Nogueira escura"
        case .tabuasClaras: "Tábuas claras"
        case .tabuasAvermelhadas: "Tábuas avermelhadas"
        case .branco: "Branco"
        }
    }

    var imagem: String? {
        switch self {
        case .madeiraClara: "MesaMadeiraClara"
        case .nogueira: "MesaNogueira"
        case .tabuasClaras: "MesaTabuasClaras"
        case .tabuasAvermelhadas: "MesaTabuasAvermelhadas"
        case .madeiraDesenhada, .branco: nil
        }
    }
}

/// Gerador pseudoaleatório determinístico (SplitMix64): o mesmo recorte sempre tem o mesmo rasgo.
struct GeradorSemente: RandomNumberGenerator {
    private var estado: UInt64
    init(semente: UInt64) { estado = semente }
    mutating func next() -> UInt64 {
        estado &+= 0x9E37_79B9_7F4A_7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
