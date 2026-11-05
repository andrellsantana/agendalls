import Foundation

struct Tarefa: Identifiable, Hashable {
    var id: Int64?
    var titulo: String
    var notas: String = ""
    var concluida: Bool = false
    /// Posição na lista: 0 é a mais prioritária.
    var ordem: Int = 0
    /// Posição da anotação na mesa.
    var x: Double = 0
    var y: Double = 0
    /// Inclinação da anotação na mesa, em graus.
    var rotacao: Double = 0
}
