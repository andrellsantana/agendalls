import Foundation
import Observation

/// Estado do mini app Ponto: a entrada de hoje, os ajustes de hoje e as preferências.
@MainActor
@Observable
final class PontoStore {
    private(set) var entrada: Date?
    private(set) var ajustes: [Ajuste] = []
    var simulacao: Date = Date().semSegundos
    private(set) var alarmeAtivo = true
    /// Minutos antes da saída padrão em que o alarme toca (10, 5 ou 0).
    private(set) var antecedenciaAlarme = 10
    private(set) var jornadaMinutos = 540
    private(set) var toleranciaMinutos = 10
    var erro: String?

    let alarme = AlarmeManager()
    private let banco: BancoDeDados
    @ObservationIgnored private var diaCarregado = ""
    @ObservationIgnored private var relogio: Timer?

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
        carregarPreferencias()
        carregarDia()
        // Ao virar o dia, a entrada e os ajustes do dia anterior saem da tela.
        relogio = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.diaCarregado != Formatos.chaveDoDia() else { return }
                self.carregarDia()
            }
        }
    }

    // MARK: - Cálculos

    var calculo: PontoCalculo {
        PontoCalculo(jornadaMinutos: jornadaMinutos, toleranciaMinutos: toleranciaMinutos)
    }

    var totalAjustes: Int { calculo.totalAjustes(ajustes) }

    var saidaPadrao: Date? {
        entrada.map { calculo.saidaPadrao(entrada: $0, ajustes: ajustes) }
    }

    var horaDoAlarme: Date? {
        guard alarmeAtivo, let saida = saidaPadrao else { return nil }
        return saida.addingTimeInterval(TimeInterval(-antecedenciaAlarme * 60))
    }

    var situacaoSimulada: SituacaoSaida? {
        saidaPadrao.map { calculo.situacao(saida: simulacao, saidaPadrao: $0) }
    }

    // MARK: - Ações

    func definirEntrada(_ data: Date) {
        let hora = data.semSegundos
        let minutos = hora.minutosDoDia
        entrada = Date.hoje(minutos: minutos)
        salvar {
            try banco.executar(
                "INSERT INTO ponto_dia (data, entrada_min) VALUES (?, ?) ON CONFLICT(data) DO UPDATE SET entrada_min = excluded.entrada_min",
                [.texto(diaCarregado), .inteiro(minutos)]
            )
        }
        if let saida = saidaPadrao { simulacao = saida }
        reagendarAlarme()
    }

    func limparEntrada() {
        entrada = nil
        salvar { try banco.executar("DELETE FROM ponto_dia WHERE data = ?", [.texto(diaCarregado)]) }
        reagendarAlarme()
    }

    func adicionarAjuste(minutos: Int, descricao: String) {
        guard minutos != 0 else { return }
        let texto = descricao.trimmingCharacters(in: .whitespacesAndNewlines)
        let rotulo = texto.isEmpty ? (minutos > 0 ? "Acréscimo" : "Desconto") : texto
        salvar {
            let id = try banco.executar(
                "INSERT INTO ponto_ajuste (data, minutos, descricao) VALUES (?, ?, ?)",
                [.texto(diaCarregado), .inteiro(minutos), .texto(rotulo)]
            )
            ajustes.append(Ajuste(id: id, minutos: minutos, descricao: rotulo))
        }
        reagendarAlarme()
    }

    func removerAjuste(_ ajuste: Ajuste) {
        salvar { try banco.executar("DELETE FROM ponto_ajuste WHERE id = ?", [.inteiro(Int(ajuste.id))]) }
        ajustes.removeAll { $0.id == ajuste.id }
        reagendarAlarme()
    }

    func definirAlarmeAtivo(_ ativo: Bool) {
        alarmeAtivo = ativo
        banco.definirConfig("ponto.alarme_ativo", ativo ? "1" : "0")
        reagendarAlarme()
    }

    func definirAntecedencia(_ minutos: Int) {
        antecedenciaAlarme = minutos
        banco.definirConfig("ponto.antecedencia", String(minutos))
        reagendarAlarme()
    }

    func definirJornada(_ minutos: Int) {
        jornadaMinutos = minutos
        banco.definirConfig("ponto.jornada", String(minutos))
        reagendarAlarme()
    }

    func definirTolerancia(_ minutos: Int) {
        toleranciaMinutos = minutos
        banco.definirConfig("ponto.tolerancia", String(minutos))
        reagendarAlarme()
    }

    func testarAlarme() {
        let saida = saidaPadrao ?? Date().addingTimeInterval(600)
        alarme.testar(saida: Formatos.hora(saida), fimTolerancia: Formatos.hora(calculo.fimTolerancia(saidaPadrao: saida)))
    }

    // MARK: - Persistência

    private func carregarPreferencias() {
        if let v = banco.config("ponto.alarme_ativo") { alarmeAtivo = v == "1" }
        if let v = banco.config("ponto.antecedencia").flatMap(Int.init) { antecedenciaAlarme = v }
        if let v = banco.config("ponto.jornada").flatMap(Int.init) { jornadaMinutos = v }
        if let v = banco.config("ponto.tolerancia").flatMap(Int.init) { toleranciaMinutos = v }
    }

    private func carregarDia() {
        diaCarregado = Formatos.chaveDoDia()
        entrada = nil
        ajustes = []
        do {
            if let minutos = try banco.consultar("SELECT entrada_min FROM ponto_dia WHERE data = ?", [.texto(diaCarregado)]).first?.first?.inteiro {
                entrada = Date.hoje(minutos: minutos)
            }
            ajustes = try banco.consultar(
                "SELECT id, minutos, descricao FROM ponto_ajuste WHERE data = ? ORDER BY id",
                [.texto(diaCarregado)]
            ).map { linha in
                Ajuste(id: Int64(linha[0].inteiro ?? 0), minutos: linha[1].inteiro ?? 0, descricao: linha[2].texto ?? "")
            }
        } catch {
            self.erro = "\(error)"
        }
        simulacao = saidaPadrao ?? Date().semSegundos
        reagendarAlarme()
    }

    private func salvar(_ acao: () throws -> Void) {
        do { try acao() } catch { self.erro = "\(error)" }
    }

    private func reagendarAlarme() {
        guard let horario = horaDoAlarme, let saida = saidaPadrao else {
            alarme.agendar(horario: nil, limite: nil, saida: "", fimTolerancia: "")
            return
        }
        let fim = calculo.fimTolerancia(saidaPadrao: saida)
        alarme.agendar(
            horario: horario,
            limite: fim.addingTimeInterval(30 * 60),
            saida: Formatos.hora(saida),
            fimTolerancia: Formatos.hora(fim)
        )
    }
}
