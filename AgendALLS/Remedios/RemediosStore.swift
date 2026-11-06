import Foundation
import Observation

@MainActor
@Observable
final class RemediosStore {
    /// Em ordem alfabética.
    private(set) var remedios: [Remedio] = []
    /// Registros de hoje, por "id@HH:mm".
    private(set) var registrosDeHoje: [String: RegistroDose] = [:]
    var erro: String?

    private let banco: BancoDeDados
    @ObservationIgnored private var diaCarregado = ""
    @ObservationIgnored private var relogio: Timer?

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
        recarregar()
        relogio = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.diaCarregado != Formatos.chaveDoDia() else { return }
                self.recarregar()
            }
        }
    }

    // MARK: - Consultas

    struct DoseDoDia: Identifiable, Hashable {
        let remedio: Remedio
        let horario: String
        var id: String { "\(remedio.id)@\(horario)" }
    }

    /// Todas as doses de hoje em ordem de horário.
    var dosesDeHoje: [DoseDoDia] {
        remedios.flatMap { r in r.horarios.map { DoseDoDia(remedio: r, horario: $0) } }
            .sorted { ($0.horario, $0.remedio.nome) < ($1.horario, $1.remedio.nome) }
    }

    func registro(_ remedio: Remedio, _ horario: String) -> RegistroDose? {
        registrosDeHoje["\(remedio.id)@\(horario)"]
    }

    var resumoDeHoje: String {
        let total = dosesDeHoje.count
        let tomadas = dosesDeHoje.filter { registro($0.remedio, $0.horario)?.situacao.gastaEstoque == true }.count
        return total == 0 ? "Nenhuma dose hoje" : "\(tomadas) de \(total) doses tomadas"
    }

    var acabando: [Remedio] { remedios.filter(\.estoqueAcabando) }

    // MARK: - Remédios

    func salvar(_ r: Remedio) {
        let horarios = Array(Set(r.horarios)).sorted().joined(separator: ",")
        do {
            if r.id == 0 {
                let tom = Double((remedios.count * 67 + 210) % 360) / 360
                try banco.executar(
                    "INSERT INTO remedio (nome, laboratorio, dosagem, horarios, objetivo, estoque, por_dose, aviso_dias, tom, criado_em) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    [.texto(r.nome), .texto(r.laboratorio), .texto(r.dosagem), .texto(horarios), .texto(r.objetivo),
                     .inteiro(r.estoque), .inteiro(max(r.porDose, 1)), .inteiro(r.avisoDias), .real(tom), .real(Date().timeIntervalSince1970)]
                )
            } else {
                try banco.executar(
                    "UPDATE remedio SET nome = ?, laboratorio = ?, dosagem = ?, horarios = ?, objetivo = ?, estoque = ?, por_dose = ?, aviso_dias = ? WHERE id = ?",
                    [.texto(r.nome), .texto(r.laboratorio), .texto(r.dosagem), .texto(horarios), .texto(r.objetivo),
                     .inteiro(r.estoque), .inteiro(max(r.porDose, 1)), .inteiro(r.avisoDias), .inteiro(Int(r.id))]
                )
            }
        } catch {
            erro = "\(error)"
        }
        recarregar()
    }

    func excluir(_ r: Remedio) {
        do {
            try banco.executar("DELETE FROM remedio_dose WHERE remedio_id = ?", [.inteiro(Int(r.id))])
            try banco.executar("DELETE FROM remedio WHERE id = ?", [.inteiro(Int(r.id))])
        } catch {
            erro = "\(error)"
        }
        recarregar()
    }

    func reporEstoque(_ r: Remedio, unidades: Int) {
        guard unidades > 0 else { return }
        ajustarEstoque(r.id, unidades)
        recarregar()
    }

    // MARK: - Doses

    /// Registra (ou troca) o que aconteceu com uma dose de hoje. `nil` apaga o registro.
    /// Dose tomada desconta do estoque; desfazer devolve.
    func registrar(_ r: Remedio, _ horario: String, _ situacao: SituacaoDose?, horaReal: String? = nil) {
        let anterior = registro(r, horario)
        var delta = 0
        if anterior?.situacao.gastaEstoque == true { delta += r.porDose }
        if situacao?.gastaEstoque == true { delta -= r.porDose }
        do {
            if let situacao {
                try banco.executar(
                    "INSERT INTO remedio_dose (remedio_id, data, horario, situacao, hora_real) VALUES (?, ?, ?, ?, ?) ON CONFLICT(remedio_id, data, horario) DO UPDATE SET situacao = excluded.situacao, hora_real = excluded.hora_real",
                    [.inteiro(Int(r.id)), .texto(diaCarregado), .texto(horario), .texto(situacao.rawValue),
                     situacao == .atrasada ? (horaReal.map { .texto($0) } ?? .nulo) : .nulo]
                )
            } else {
                try banco.executar(
                    "DELETE FROM remedio_dose WHERE remedio_id = ? AND data = ? AND horario = ?",
                    [.inteiro(Int(r.id)), .texto(diaCarregado), .texto(horario)]
                )
            }
        } catch {
            erro = "\(error)"
        }
        if delta != 0 { ajustarEstoque(r.id, delta) }
        recarregar()
    }

    // MARK: - Persistência

    private func ajustarEstoque(_ id: Int64, _ delta: Int) {
        do {
            try banco.executar("UPDATE remedio SET estoque = MAX(estoque + ?, 0) WHERE id = ?", [.inteiro(delta), .inteiro(Int(id))])
        } catch {
            erro = "\(error)"
        }
    }

    private func recarregar() {
        diaCarregado = Formatos.chaveDoDia()
        do {
            remedios = try banco.consultar(
                "SELECT id, nome, laboratorio, dosagem, horarios, objetivo, estoque, por_dose, aviso_dias, tom FROM remedio"
            ).map { l in
                Remedio(
                    id: Int64(l[0].inteiro ?? 0),
                    nome: l[1].texto ?? "",
                    laboratorio: l[2].texto ?? "",
                    dosagem: l[3].texto ?? "",
                    horarios: (l[4].texto ?? "").split(separator: ",").map(String.init).sorted(),
                    objetivo: l[5].texto ?? "",
                    estoque: l[6].inteiro ?? 0,
                    porDose: l[7].inteiro ?? 1,
                    avisoDias: l[8].inteiro ?? 7,
                    tom: l[9].real ?? 0
                )
            }
            .sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }

            var registros: [String: RegistroDose] = [:]
            for l in try banco.consultar("SELECT remedio_id, horario, situacao, hora_real FROM remedio_dose WHERE data = ?", [.texto(diaCarregado)]) {
                guard let situacao = SituacaoDose(rawValue: l[2].texto ?? "") else { continue }
                registros["\(l[0].inteiro ?? 0)@\(l[1].texto ?? "")"] = RegistroDose(situacao: situacao, horaReal: l[3].texto)
            }
            registrosDeHoje = registros
        } catch {
            erro = "\(error)"
        }
    }
}
