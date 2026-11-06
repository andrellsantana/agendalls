import AppKit
import SwiftUI

struct LinkSalvo: Identifiable, Hashable {
    var id: Int64
    var titulo: String
    var url: String
    var categoria: String
    /// Cor principal do logotipo, em hexadecimal ("#1A73E8"). `nil` enquanto não foi encontrada.
    var cor: String?
    var temLogo: Bool

    var dominio: String {
        guard let host = URL(string: url)?.host else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var inicial: String {
        String(dominio.first.map { String($0).uppercased() } ?? "?")
    }
}

enum CoresLink {
    /// Tom (0–1) estável a partir de um texto, para tags e logotipos sem cor.
    static func tom(_ texto: String) -> Double {
        var h = 0
        for u in texto.unicodeScalars { h = (h &* 31 &+ Int(u.value)) % 360 }
        return Double(abs(h)) / 360
    }

    static func cor(hex: String?) -> NSColor? {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Tom e saturação do card: vêm do logotipo; sem logotipo, do domínio.
    static func tomESaturacao(_ link: LinkSalvo) -> (Double, Double) {
        if let c = cor(hex: link.cor)?.usingColorSpace(.sRGB) {
            var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            return (Double(h), Double(s))
        }
        return (tom(link.dominio), 0.55)
    }

    static func fundoCard(_ link: LinkSalvo) -> LinearGradient {
        let (h, s) = tomESaturacao(link)
        let sat = min(s, 0.7)
        return LinearGradient(
            colors: [
                Color(hue: h, saturation: sat * 0.12, brightness: 0.985),
                Color(hue: h, saturation: sat * 0.28, brightness: 0.94)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func bordaCard(_ link: LinkSalvo) -> Color {
        let (h, s) = tomESaturacao(link)
        return Color(hue: h, saturation: min(s, 0.7) * 0.35, brightness: 0.84)
    }

    static func textoCard(_ link: LinkSalvo) -> Color {
        let (h, s) = tomESaturacao(link)
        return Color(hue: h, saturation: min(s, 0.7) * 0.6, brightness: 0.2)
    }

    static func textoSecundarioCard(_ link: LinkSalvo) -> Color {
        let (h, s) = tomESaturacao(link)
        return Color(hue: h, saturation: min(s, 0.7) * 0.45, brightness: 0.38)
    }

    static func monograma(_ link: LinkSalvo) -> Color {
        let (h, s) = tomESaturacao(link)
        return Color(hue: h, saturation: max(min(s, 0.75), 0.35), brightness: 0.45)
    }

    static func tag(_ categoria: String, forte: Bool) -> (fundo: Color, borda: Color, texto: Color) {
        let h = tom(categoria)
        if forte {
            return (Color(hue: h, saturation: 0.55, brightness: 0.45), Color(hue: h, saturation: 0.55, brightness: 0.45), .white)
        }
        return (Color(hue: h, saturation: 0.12, brightness: 0.97), Color(hue: h, saturation: 0.3, brightness: 0.82), Color(hue: h, saturation: 0.6, brightness: 0.32))
    }
}

/// Navegador instalado que abre endereços da web.
struct Navegador: Identifiable, Hashable {
    let id: String // bundle identifier
    let nome: String
    let url: URL

    static let safari = "com.apple.Safari"

    static func instalados() -> [Navegador] {
        guard let exemplo = URL(string: "https://www.apple.com") else { return [] }
        var vistos = Set<String>()
        return NSWorkspace.shared.urlsForApplications(toOpen: exemplo).compactMap { url in
            guard let id = Bundle(url: url)?.bundleIdentifier, !vistos.contains(id) else { return nil }
            vistos.insert(id)
            let nome = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            return Navegador(id: id, nome: nome, url: url)
        }
        .sorted { $0.nome.localizedCaseInsensitiveCompare($1.nome) == .orderedAscending }
    }
}
