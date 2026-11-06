import AppKit
import Foundation

/// Lê a página do link e busca o logotipo padrão do site (apple-touch-icon, ícones declarados
/// na página ou /favicon.ico). Devolve o logotipo em PNG e a cor principal dele.
enum BuscadorLogo {
    struct Resultado {
        let png: Data
        let cor: String?
    }

    private static let sessao: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 10
        c.timeoutIntervalForResource = 20
        c.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
            "Accept-Language": "pt-BR,pt;q=0.9,en;q=0.8"
        ]
        return URLSession(configuration: c)
    }()

    static func buscar(para endereco: URL) async -> Resultado? {
        var candidatos: [(URL, Int)] = []
        var base = endereco

        if let (dados, resposta) = try? await sessao.data(from: endereco) {
            base = resposta.url ?? endereco
            let html = String(decoding: dados.prefix(400_000), as: UTF8.self)
            candidatos += icones(noHTML: html, base: base)
        }
        if let host = base.host ?? endereco.host {
            candidatos.append((URL(string: "https://\(host)/apple-touch-icon.png")!, 150))
            candidatos.append((URL(string: "https://\(host)/favicon.ico")!, 10))
        }

        var tentados = Set<URL>()
        for (url, _) in candidatos.sorted(by: { $0.1 > $1.1 }) where !tentados.contains(url) {
            tentados.insert(url)
            guard let (dados, resposta) = try? await sessao.data(from: url),
                  (resposta as? HTTPURLResponse)?.statusCode ?? 200 < 400,
                  let imagem = NSImage(data: dados),
                  imagem.isValid,
                  let png = pngQuadrado(imagem, lado: 128)
            else { continue }
            return Resultado(png: png, cor: corPrincipal(imagem))
        }
        return nil
    }

    // MARK: - Leitura do HTML

    /// Extrai os ícones declarados em <link rel="..."> com uma nota: maior é melhor.
    private static func icones(noHTML html: String, base: URL) -> [(URL, Int)] {
        guard let tagRegex = try? NSRegularExpression(pattern: "<link\\b[^>]*>", options: .caseInsensitive) else { return [] }
        var resultado: [(URL, Int)] = []
        let ns = html as NSString
        for m in tagRegex.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let tag = ns.substring(with: m.range)
            guard let rel = atributo("rel", em: tag)?.lowercased(),
                  rel.contains("icon"),
                  let href = atributo("href", em: tag),
                  !href.lowercased().hasSuffix(".svg"),
                  let url = URL(string: href.replacingOccurrences(of: "&amp;", with: "&"), relativeTo: base)?.absoluteURL
            else { continue }
            var nota = 32
            if let tamanhos = atributo("sizes", em: tag),
               let n = tamanhos.lowercased().split(separator: " ").compactMap({ Int($0.split(separator: "x").first ?? "") }).max() {
                nota = n
            }
            if rel.contains("apple-touch-icon") { nota += 1000 }
            if rel.contains("mask-icon") { nota = 1 }
            resultado.append((url, nota))
        }
        return resultado
    }

    private static func atributo(_ nome: String, em tag: String) -> String? {
        let padrao = "\\b\(nome)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let r = try? NSRegularExpression(pattern: padrao, options: .caseInsensitive),
              let m = r.firstMatch(in: tag, range: NSRange(location: 0, length: (tag as NSString).length))
        else { return nil }
        for i in 1...3 where m.range(at: i).location != NSNotFound {
            return (tag as NSString).substring(with: m.range(at: i))
        }
        return nil
    }

    // MARK: - Imagem

    private static func pngQuadrado(_ imagem: NSImage, lado: Int) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        let tamanho = imagem.size
        let escala = min(CGFloat(lado) / max(tamanho.width, 1), CGFloat(lado) / max(tamanho.height, 1))
        let w = tamanho.width * escala, h = tamanho.height * escala
        imagem.draw(in: NSRect(x: (CGFloat(lado) - w) / 2, y: (CGFloat(lado) - h) / 2, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    /// Média das cores mais vivas do logotipo, ignorando transparente, branco e preto.
    private static func corPrincipal(_ imagem: NSImage) -> String? {
        let lado = 24
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: lado, pixelsHigh: lado, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        imagem.draw(in: NSRect(x: 0, y: 0, width: lado, height: lado))
        NSGraphicsContext.restoreGraphicsState()

        var soma = (r: 0.0, g: 0.0, b: 0.0, peso: 0.0)
        var todos = (r: 0.0, g: 0.0, b: 0.0, n: 0.0)
        for x in 0..<lado {
            for y in 0..<lado {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), c.alphaComponent > 0.5 else { continue }
                let r = Double(c.redComponent), g = Double(c.greenComponent), b = Double(c.blueComponent)
                todos = (todos.r + r, todos.g + g, todos.b + b, todos.n + 1)
                let maior = max(r, g, b), menor = min(r, g, b)
                let saturacao = maior == 0 ? 0 : (maior - menor) / maior
                guard maior > 0.15, saturacao > 0.2 else { continue }
                let peso = saturacao * saturacao
                soma = (soma.r + r * peso, soma.g + g * peso, soma.b + b * peso, soma.peso + peso)
            }
        }
        let (r, g, b): (Double, Double, Double)
        if soma.peso > 0 {
            (r, g, b) = (soma.r / soma.peso, soma.g / soma.peso, soma.b / soma.peso)
        } else if todos.n > 0 {
            (r, g, b) = (todos.r / todos.n, todos.g / todos.n, todos.b / todos.n)
        } else {
            return nil
        }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
