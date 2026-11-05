import AppKit
import Observation
import SwiftUI
import UserNotifications

/// Alarme do ponto: cobre todas as telas de vermelho piscando e toca som em repetição até ser parado.
/// Enquanto o app estiver aberto, o alarme é em tela cheia. Se o app estiver fechado,
/// uma notificação do macOS é entregue no mesmo horário como reserva.
@MainActor
@Observable
final class AlarmeManager {
    private(set) var tocando = false

    @ObservationIgnored private var horario: Date?
    @ObservationIgnored private var limite: Date?
    @ObservationIgnored private var horarioJaDisparado: Date?
    @ObservationIgnored private var textoSaida = ""
    @ObservationIgnored private var textoFimTolerancia = ""
    @ObservationIgnored private var janelas: [NSWindow] = []
    @ObservationIgnored private var som: NSSound?
    @ObservationIgnored private var relogio: Timer?

    private static let idNotificacao = "agendalls.ponto.alarme"

    init() {
        relogio = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.verificar() }
        }
    }

    static func pedirPermissaoDeNotificacao() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    /// Define o próximo horário do alarme. `nil` desliga.
    func agendar(horario: Date?, limite: Date?, saida: String, fimTolerancia: String) {
        if horario != self.horario { horarioJaDisparado = nil }
        self.horario = horario
        self.limite = limite
        textoSaida = saida
        textoFimTolerancia = fimTolerancia
        agendarNotificacao(horario)
    }

    func testar(saida: String, fimTolerancia: String) {
        textoSaida = saida
        textoFimTolerancia = fimTolerancia
        disparar()
    }

    /// "Já bati, parar"
    func parar() {
        fecharJanelas()
        if let horario { horarioJaDisparado = horario }
    }

    /// "Adiar 2 min"
    func adiar() {
        fecharJanelas()
        let novo = Date().addingTimeInterval(120)
        horario = novo
        horarioJaDisparado = nil
        if let l = limite, l < novo { limite = novo.addingTimeInterval(30 * 60) }
        agendarNotificacao(novo)
    }

    // MARK: - Interno

    private func verificar() {
        guard !tocando, let h = horario, horarioJaDisparado != h else { return }
        let agora = Date()
        let fim = limite ?? h.addingTimeInterval(60 * 60)
        if agora >= h && agora < fim {
            horarioJaDisparado = h
            disparar()
        }
    }

    private func disparar() {
        guard !tocando else { return }
        tocando = true

        for tela in NSScreen.screens {
            let janela = JanelaAlarme(
                contentRect: tela.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            janela.level = .screenSaver
            janela.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            janela.isReleasedWhenClosed = false
            janela.backgroundColor = .black
            janela.contentView = NSHostingView(rootView: AlarmeView(
                saida: textoSaida,
                fimTolerancia: textoFimTolerancia,
                aoParar: { [weak self] in self?.parar() },
                aoAdiar: { [weak self] in self?.adiar() }
            ))
            janela.setFrame(tela.frame, display: true)
            janela.makeKeyAndOrderFront(nil)
            janelas.append(janela)
        }
        NSApp.activate()

        let s = NSSound(named: NSSound.Name("Sosumi")) ?? NSSound(named: NSSound.Name("Glass"))
        s?.loops = true
        s?.volume = 1
        s?.play()
        som = s
    }

    private func fecharJanelas() {
        som?.stop()
        som = nil
        janelas.forEach { $0.orderOut(nil) }
        janelas.removeAll()
        tocando = false
    }

    private func agendarNotificacao(_ horario: Date?) {
        let central = UNUserNotificationCenter.current()
        central.removePendingNotificationRequests(withIdentifiers: [Self.idNotificacao])
        guard let horario, horario > Date() else { return }

        let conteudo = UNMutableNotificationContent()
        conteudo.title = "Bata o ponto!"
        conteudo.body = "Saída padrão às \(textoSaida). Tolerância até \(textoFimTolerancia)."
        conteudo.sound = .default
        conteudo.interruptionLevel = .timeSensitive

        let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: horario)
        let gatilho = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
        central.add(UNNotificationRequest(identifier: Self.idNotificacao, content: conteudo, trigger: gatilho))
    }
}

/// Janela sem bordas que aceita cliques e teclado.
final class JanelaAlarme: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Conteúdo da tela de alarme.
struct AlarmeView: View {
    let saida: String
    let fimTolerancia: String
    let aoParar: @MainActor () -> Void
    let aoAdiar: @MainActor () -> Void

    @State private var piscando = false

    var body: some View {
        ZStack {
            (piscando ? Color(red: 0.48, green: 0, blue: 0.09) : Color(red: 0.78, green: 0.06, blue: 0.18))
                .ignoresSafeArea()
            VStack(spacing: 26) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 120))
                    .rotationEffect(.degrees(piscando ? -14 : 14))
                    .accessibilityHidden(true)
                Text("BATA O PONTO!")
                    .font(.system(size: 76, weight: .heavy))
                Text("Saída padrão às \(saida). Tolerância até \(fimTolerancia).")
                    .font(.title)
                HStack(spacing: 18) {
                    Button { aoParar() } label: {
                        Text("Já bati, parar")
                            .font(.title2.bold())
                            .foregroundStyle(Color(red: 0.63, green: 0, blue: 0.11))
                            .padding(.horizontal, 30).padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)

                    Button { aoAdiar() } label: {
                        Text("Adiar 2 min")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 30).padding(.vertical, 14)
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                piscando = true
            }
        }
    }
}
