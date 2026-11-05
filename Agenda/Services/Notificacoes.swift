import Foundation
import UserNotifications

enum Notificacoes {
    static func pedirPermissao() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func agendar(_ a: Agendamento) {
        guard let id = a.id else { return }
        cancelar(id: id)
        guard let minutos = a.lembreteMinutos else { return }
        let quando = a.data.addingTimeInterval(TimeInterval(-minutos * 60))
        guard quando > .now else { return }

        let conteudo = UNMutableNotificationContent()
        conteudo.title = a.titulo
        conteudo.body = a.cliente.isEmpty
            ? "Começa às \(a.data.formatted(date: .omitted, time: .shortened))"
            : "\(a.cliente) — às \(a.data.formatted(date: .omitted, time: .shortened))"
        conteudo.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: quando)
        let gatilho = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "ag-\(id)", content: conteudo, trigger: gatilho))
    }

    static func cancelar(id: Int64) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ag-\(id)"])
    }
}
