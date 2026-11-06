import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class CadastroStore {
    private(set) var dados = DadosCadastro()
    private(set) var carregado = false
    var erro: String?

    private let banco: BancoDeDados
    @ObservationIgnored private var salvamento: Task<Void, Never>?
    private static let chave = "cadastro"

    init(banco: BancoDeDados = .compartilhado) {
        self.banco = banco
    }

    /// Lê e decifra os dados (chamado depois do Touch ID).
    func carregar() {
        do {
            if let bruto = try banco.lerCofre(Self.chave) {
                dados = try JSONDecoder().decode(DadosCadastro.self, from: bruto)
            } else {
                dados = DadosCadastro()
            }
            carregado = true
        } catch {
            erro = "Não foi possível abrir o cadastro: \(error)"
        }
    }

    /// Grava o que estiver pendente e apaga os dados da memória.
    func descarregar() {
        if salvamento != nil {
            salvamento?.cancel()
            gravarAgora()
        }
        dados = DadosCadastro()
        carregado = false
    }

    func alterar(_ mudanca: (inout DadosCadastro) -> Void) {
        guard carregado else { return }
        mudanca(&dados)
        agendarGravacao()
    }

    func campo(_ chave: String) -> String { dados.valor(chave) }

    func definirFoto(de url: URL) {
        guard let imagem = NSImage(contentsOf: url), let jpeg = Self.jpegReduzido(imagem, maiorLado: 900) else {
            erro = "Não foi possível abrir essa imagem."
            return
        }
        alterar {
            $0.foto = jpeg
            $0.fotoZoom = 1
            $0.fotoX = 0.5
            $0.fotoY = 0.5
        }
    }

    // MARK: - Gravação

    private func agendarGravacao() {
        salvamento?.cancel()
        salvamento = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.gravarAgora()
        }
    }

    private func gravarAgora() {
        salvamento = nil
        guard carregado else { return }
        do {
            try banco.gravarCofre(Self.chave, JSONEncoder().encode(dados))
        } catch {
            erro = "Não foi possível salvar: \(error)"
        }
    }

    private static func jpegReduzido(_ imagem: NSImage, maiorLado: CGFloat) -> Data? {
        guard let cg = imagem.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let escala = min(1, maiorLado / CGFloat(max(cg.width, cg.height)))
        let w = Int(CGFloat(cg.width) * escala), h = Int(CGFloat(cg.height) * escala)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let reduzida = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: reduzida).representation(using: .jpeg, properties: [.compressionFactor: 0.88])
    }
}
