import SwiftUI

/// Janela de Configurações (menu AgendALLS › Ajustes…, ou ⌘,).
struct ConfiguracoesView: View {
    @Environment(PontoStore.self) private var ponto

    var body: some View {
        TabView {
            Form {
                Section {
                    Stepper(
                        "Tempo entre entrada e saída: \(Formatos.duracao(minutos: ponto.jornadaMinutos))",
                        value: Binding(get: { ponto.jornadaMinutos }, set: { ponto.definirJornada($0) }),
                        in: 240...720,
                        step: 15
                    )
                    Text("Inclui o almoço. Padrão: 9h (8h trabalhadas + 1h de almoço).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Stepper(
                        "Tolerância na saída: \(ponto.toleranciaMinutos) min",
                        value: Binding(get: { ponto.toleranciaMinutos }, set: { ponto.definirTolerancia($0) }),
                        in: 0...30
                    )
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("Ponto", systemImage: "clock") }

            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text(Versao.nome).font(.title.bold())
                Text("Versão \(Versao.atual)").foregroundStyle(.secondary)
                Text("Desenvolvido por \(Versao.desenvolvedor)")
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .tabItem { Label("Sobre", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 300)
    }
}
