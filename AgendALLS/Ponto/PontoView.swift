import SwiftUI

struct PontoView: View {
    @Environment(PontoStore.self) private var store

    var body: some View {
        ScrollView {
            Grid(horizontalSpacing: 20, verticalSpacing: 20) {
                GridRow {
                    CartaoEntrada()
                    CartaoSaida()
                }
                GridRow {
                    CartaoAjustes()
                    CartaoSimulacaoEAlarme()
                }
            }
            .padding(28)
        }
        .alert("Erro", isPresented: Binding(get: { store.erro != nil }, set: { if !$0 { store.erro = nil } })) {
            Button("OK") { store.erro = nil }
        } message: {
            Text(store.erro ?? "")
        }
    }
}

// MARK: - Entrada

private struct CartaoEntrada: View {
    @Environment(PontoStore.self) private var store

    var body: some View {
        Cartao(titulo: "Entrada de hoje") {
            HStack(spacing: 12) {
                DatePicker(
                    "Horário que bati o ponto",
                    selection: Binding(
                        get: { store.entrada ?? Date().semSegundos },
                        set: { store.definirEntrada($0) }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.field)
                .font(.system(size: 26, weight: .semibold).monospacedDigit())
                .frame(width: 120)

                Button("Agora") { store.definirEntrada(Date()) }
                    .controlSize(.large)
                if store.entrada != nil {
                    Button("Limpar", role: .destructive) { store.limparEntrada() }
                        .controlSize(.large)
                }
            }
            if store.entrada == nil {
                Text("Informe o horário ou clique em Agora ao bater o ponto.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Jornada: \(Formatos.duracao(minutos: store.jornadaMinutos)) entre entrada e saída, com almoço incluído. Tolerância de \(store.toleranciaMinutos) min, só na saída.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Saída padrão

private struct CartaoSaida: View {
    @Environment(PontoStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saída padrão").font(.headline).opacity(0.9)
            if let saida = store.saidaPadrao {
                Text(Formatos.hora(saida))
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                Text("Pode sair sem dever nem fazer extra entre **\(Formatos.hora(store.calculo.inicioTolerancia(saidaPadrao: saida)))** e **\(Formatos.hora(store.calculo.fimTolerancia(saidaPadrao: saida)))**.")
                    .font(.callout)
                if store.totalAjustes != 0 {
                    Text("Inclui ajustes do dia: \(Formatos.duracaoComSinal(minutos: store.totalAjustes))")
                        .font(.caption)
                        .opacity(0.9)
                }
            } else {
                Text("--:--")
                    .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
                    .opacity(0.6)
                Text("Informe a entrada para calcular.").font(.callout)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Ajustes

private struct CartaoAjustes: View {
    @Environment(PontoStore.self) private var store
    @State private var acrescentar = true
    @State private var minutos: Int?
    @State private var motivo = ""

    var body: some View {
        Cartao(titulo: "Ajustes só de hoje") {
            HStack(alignment: .bottom, spacing: 8) {
                Picker("Tipo", selection: $acrescentar) {
                    Text("Acrescentar").tag(true)
                    Text("Descontar").tag(false)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 190)

                TextField("Min", value: $minutos, format: .number)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)

                TextField("Motivo (ex.: consulta médica)", text: $motivo)
                    .onSubmit(adicionar)

                Button("Adicionar", action: adicionar)
                    .disabled((minutos ?? 0) <= 0)
            }
            .textFieldStyle(.roundedBorder)

            if store.ajustes.isEmpty {
                Text("Nenhum ajuste. Use para consulta, compensação de horas etc. Valem só para hoje.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(store.ajustes) { ajuste in
                        HStack {
                            Text(Formatos.duracaoComSinal(minutos: ajuste.minutos))
                                .fontWeight(.semibold)
                                .monospacedDigit()
                                .foregroundStyle(ajuste.minutos > 0 ? Color.blue : Color.red)
                                .frame(width: 80, alignment: .leading)
                            Text(ajuste.descricao)
                            Spacer()
                            Button {
                                store.removerAjuste(ajuste)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help("Remover ajuste")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func adicionar() {
        guard let m = minutos, m > 0 else { return }
        store.adicionarAjuste(minutos: acrescentar ? m : -m, descricao: motivo)
        minutos = nil
        motivo = ""
    }
}

// MARK: - Simulação e alarme

private struct CartaoSimulacaoEAlarme: View {
    @Environment(PontoStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Cartao(titulo: "E se eu sair às…") {
            DatePicker("Saída simulada", selection: $store.simulacao, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.field)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .frame(width: 100)

            Veredito(situacao: store.situacaoSimulada)

            Divider().padding(.vertical, 4)

            Text("Alarme").font(.headline)
            HStack {
                Toggle("Tocar alarme", isOn: Binding(get: { store.alarmeAtivo }, set: { store.definirAlarmeAtivo($0) }))
                Picker("Quando", selection: Binding(get: { store.antecedenciaAlarme }, set: { store.definirAntecedencia($0) })) {
                    Text("10 min antes (início da tolerância)").tag(10)
                    Text("5 min antes").tag(5)
                    Text("Na hora da saída padrão").tag(0)
                }
                .labelsHidden()
                .disabled(!store.alarmeAtivo)
                .fixedSize()
            }
            if let hora = store.horaDoAlarme {
                Text("Toca às **\(Formatos.hora(hora))**, em tela cheia, com som repetindo até você parar.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Button("Ver como fica o alarme") { store.testarAlarme() }
                .tint(.red)
        }
    }
}

private struct Veredito: View {
    let situacao: SituacaoSaida?

    var body: some View {
        let (texto, cor): (String, Color) = {
            switch situacao {
            case .none: return ("Informe a entrada primeiro.", .secondary)
            case .noHorario?: return ("Dentro da tolerância: conta como horário padrão.", .green)
            case .devendo(let m)?: return ("Ficaria devendo \(Formatos.duracao(minutos: m)).", .red)
            case .horaExtra(let m)?: return ("Faria \(Formatos.duracao(minutos: m)) de hora extra.", .blue)
            }
        }()
        Text(texto)
            .font(.body.weight(.semibold))
            .foregroundStyle(cor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}
