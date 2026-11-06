import CryptoKit
import Foundation

struct Pasta: Codable, Hashable, Identifiable {
    var id = UUID()
    var nome: String
    var paiID: UUID?
}

struct ItemSenha: Codable, Hashable, Identifiable {
    var id = UUID()
    var pastaID: UUID
    var nome: String
    var usuario = ""
    var senha = ""
    var url = ""
    var notas = ""
    /// Segredo do código de verificação em duas etapas (base32), opcional.
    var segredo2FA = ""
    var alteradaEm = Date()
    var criadaEm = Date()

    var dominio: String {
        guard let host = URL(string: url.contains("://") ? url : "https://" + url)?.host, !url.isEmpty else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var inicial: String {
        nome.first(where: \.isLetter).map { String($0).uppercased() } ?? "•"
    }
}

/// Tudo o que o Senhas guarda. É salvo inteiro, criptografado, no cofre.
struct DadosSenhas: Codable, Equatable {
    var pastas: [Pasta] = []
    var itens: [ItemSenha] = []

    static var inicial: DadosSenhas {
        let pessoal = Pasta(nome: "Pessoal")
        let trabalho = Pasta(nome: "Trabalho")
        let casa = Pasta(nome: "Casa")
        return DadosSenhas(pastas: [
            pessoal,
            Pasta(nome: "Bancos", paiID: pessoal.id),
            Pasta(nome: "E-mail", paiID: pessoal.id),
            Pasta(nome: "Redes sociais", paiID: pessoal.id),
            trabalho,
            casa,
            Pasta(nome: "Wi-Fi", paiID: casa.id),
            Pasta(nome: "Streaming", paiID: casa.id)
        ])
    }

    func filhas(de id: UUID?) -> [Pasta] {
        pastas.filter { $0.paiID == id }.sorted { $0.nome.localizedStandardCompare($1.nome) == .orderedAscending }
    }

    /// A pasta e todas as que estão dentro dela.
    func descendentes(_ id: UUID) -> Set<UUID> {
        var r: Set<UUID> = [id]
        for f in pastas where f.paiID == id { r.formUnion(descendentes(f.id)) }
        return r
    }

    func caminho(_ id: UUID) -> String {
        guard let p = pastas.first(where: { $0.id == id }) else { return "" }
        if let pai = p.paiID { return caminho(pai) + " › " + p.nome }
        return p.nome
    }

    /// Itens cuja senha aparece em mais de um item.
    var reutilizadas: Set<UUID> {
        var contagem: [String: Int] = [:]
        for i in itens where !i.senha.isEmpty { contagem[i.senha, default: 0] += 1 }
        return Set(itens.filter { (contagem[$0.senha] ?? 0) > 1 }.map(\.id))
    }

    func alertas(_ item: ItemSenha) -> [String] {
        var a: [String] = []
        if !item.senha.isEmpty, Forca.de(item.senha).rawValue <= Forca.fraca.rawValue { a.append("Senha fraca.") }
        if reutilizadas.contains(item.id) { a.append("Senha usada em outro item.") }
        return a
    }
}

// MARK: - Força da senha

enum Forca: Int, Comparable {
    case muitoFraca, fraca, media, boa, forte

    static func < (a: Forca, b: Forca) -> Bool { a.rawValue < b.rawValue }

    var nome: String {
        switch self {
        case .muitoFraca: "Muito fraca"
        case .fraca: "Fraca"
        case .media: "Média"
        case .boa: "Boa"
        case .forte: "Forte"
        }
    }

    /// Estimativa de entropia pelo tamanho e pelos tipos de caractere, com desconto para padrões óbvios.
    static func de(_ senha: String) -> Forca {
        guard !senha.isEmpty else { return .muitoFraca }
        var conjunto = 0
        if senha.contains(where: \.isLowercase) { conjunto += 26 }
        if senha.contains(where: \.isUppercase) { conjunto += 26 }
        if senha.contains(where: \.isNumber) { conjunto += 10 }
        if senha.contains(where: { !$0.isLetter && !$0.isNumber }) { conjunto += 33 }
        var bits = Double(senha.count) * log2(Double(max(conjunto, 2)))
        let unicos = Set(senha).count
        if unicos < senha.count / 2 { bits *= 0.6 }
        let comuns = ["123", "senha", "password", "qwerty", "abc", "admin", "2020", "2021", "2022", "2023", "2024", "2025", "2026"]
        if comuns.contains(where: { senha.lowercased().contains($0) }) { bits *= 0.6 }
        switch bits {
        case ..<28: return .muitoFraca
        case ..<40: return .fraca
        case ..<60: return .media
        case ..<80: return .boa
        default: return .forte
        }
    }
}

// MARK: - Gerador

enum GeradorSenha {
    static func gerar(tamanho: Int, numeros: Bool, simbolos: Bool) -> String {
        let minusculas = Array("abcdefghijkmnopqrstuvwxyz")
        let maiusculas = Array("ABCDEFGHJKLMNPQRSTUVWXYZ")
        let digitos = Array("23456789")
        let especiais = Array("!@#$%&*?-_+=")
        var grupos = [minusculas, maiusculas]
        if numeros { grupos.append(digitos) }
        if simbolos { grupos.append(especiais) }
        let todos = grupos.flatMap { $0 }
        var g = SystemRandomNumberGenerator()
        // Um de cada grupo escolhido, o resto aleatório, depois embaralha.
        var chars = grupos.map { $0.randomElement(using: &g)! }
        while chars.count < max(tamanho, grupos.count) { chars.append(todos.randomElement(using: &g)!) }
        return String(chars.shuffled(using: &g))
    }

    private static let palavras = [
        "abacate", "areia", "azul", "barco", "bolo", "brisa", "cacto", "café", "caju", "canela", "cometa", "coruja",
        "duna", "escada", "estrela", "farol", "feira", "floresta", "folha", "fogo", "gato", "girassol", "janela",
        "jardim", "lagoa", "limão", "livro", "lua", "manga", "mapa", "mar", "mesa", "montanha", "neblina", "nuvem",
        "onda", "ouro", "pedra", "pena", "pipa", "ponte", "praia", "quintal", "rio", "roda", "sabiá", "serra", "sino",
        "sol", "tambor", "tigre", "trem", "trilha", "uva", "vela", "vento", "verde", "vila", "xadrez", "zebra"
    ]

    static func frase(palavras quantidade: Int = 4, numero: Bool) -> String {
        var g = SystemRandomNumberGenerator()
        var partes = (0..<quantidade).map { _ in palavras.randomElement(using: &g)! }
        if numero { partes.append(String(Int.random(in: 10...99, using: &g))) }
        return partes.joined(separator: "-")
    }
}

// MARK: - Código de verificação em duas etapas (TOTP, RFC 6238)

enum TOTP {
    static let periodo = 30

    /// Aceita o segredo em base32 ou um endereço otpauth:// (o que o QR code contém).
    static func normalizar(_ texto: String) -> String {
        let t = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("otpauth://"),
           let c = URLComponents(string: t),
           let s = c.queryItems?.first(where: { $0.name.lowercased() == "secret" })?.value {
            return s.uppercased()
        }
        return t.replacingOccurrences(of: " ", with: "").uppercased()
    }

    static func codigo(segredo: String, em data: Date = Date()) -> String? {
        guard let chave = base32(normalizar(segredo)), !chave.isEmpty else { return nil }
        let contador = UInt64(data.timeIntervalSince1970) / UInt64(periodo)
        let mensagem = withUnsafeBytes(of: contador.bigEndian) { Data($0) }
        let mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: mensagem, using: SymmetricKey(data: chave)))
        let inicio = Int(mac[mac.count - 1] & 0x0F)
        let valor = (UInt32(mac[inicio] & 0x7F) << 24) | (UInt32(mac[inicio + 1]) << 16)
            | (UInt32(mac[inicio + 2]) << 8) | UInt32(mac[inicio + 3])
        let seis = String(format: "%06u", valor % 1_000_000)
        return String(seis.prefix(3)) + " " + String(seis.suffix(3))
    }

    static func segundosRestantes(em data: Date = Date()) -> Int {
        periodo - Int(data.timeIntervalSince1970) % periodo
    }

    private static func base32(_ s: String) -> Data? {
        let alfabeto = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var bits = 0, acumulado = 0
        var saida = Data()
        for c in s where c != "=" {
            guard let v = alfabeto.firstIndex(of: c) else { return nil }
            acumulado = (acumulado << 5) | v
            bits += 5
            if bits >= 8 {
                bits -= 8
                saida.append(UInt8((acumulado >> bits) & 0xFF))
            }
        }
        return saida
    }
}
