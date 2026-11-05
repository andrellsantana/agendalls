import Foundation

enum Formatos {
    private static let horaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let diaFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "17:07"
    static func hora(_ data: Date) -> String { horaFormatter.string(from: data) }

    /// Chave do dia para o banco: "2026-11-05"
    static func chaveDoDia(_ data: Date = Date()) -> String { diaFormatter.string(from: data) }

    /// "25 min", "1h", "1h05"
    static func duracao(minutos: Int) -> String {
        let m = abs(minutos)
        let h = m / 60, r = m % 60
        if h == 0 { return "\(r) min" }
        return r == 0 ? "\(h)h" : "\(h)h" + String(format: "%02d", r)
    }

    /// "+30 min" ou "−1h05"
    static func duracaoComSinal(minutos: Int) -> String {
        (minutos >= 0 ? "+" : "−") + duracao(minutos: minutos)
    }
}

enum Versao {
    static var nome: String { "AgendALLS" }
    static var atual: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    static var desenvolvedor: String { "André S." }
}
