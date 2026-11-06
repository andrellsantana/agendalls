import SwiftUI
import UniformTypeIdentifiers

/// Foto sempre preenchendo o círculo inteiro. `x`/`y` (0–1) escolhem que parte da foto aparece;
/// `zoom` (1–3) aproxima. Igual em qualquer tamanho, para a prévia e a impressão baterem.
struct FotoCircular: View {
    let foto: Data?
    let zoom: Double
    let x: Double
    let y: Double
    let diametro: CGFloat

    var body: some View {
        ZStack {
            Color(red: 0.87, green: 0.89, blue: 0.92)
            if let foto, let imagem = NSImage(data: foto) {
                let g = FotoCircular.geometria(imagem.size, diametro: diametro, zoom: zoom)
                Image(nsImage: imagem)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: g.width, height: g.height)
                    .offset(
                        x: (g.width - diametro) * (0.5 - x),
                        y: (g.height - diametro) * (0.5 - y)
                    )
            } else {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(diametro * 0.2)
                    .offset(y: diametro * 0.08)
                    .foregroundStyle(Color(red: 0.6, green: 0.65, blue: 0.72))
            }
        }
        .frame(width: diametro, height: diametro)
        .clipShape(Circle())
    }

    /// Tamanho da foto desenhada para cobrir o círculo com o zoom dado.
    static func geometria(_ tamanho: CGSize, diametro: CGFloat, zoom: Double) -> CGSize {
        let proporcao = tamanho.width / max(tamanho.height, 1)
        let lado = diametro * zoom
        return proporcao >= 1
            ? CGSize(width: lado * proporcao, height: lado)
            : CGSize(width: lado, height: lado / proporcao)
    }
}

/// Editor da foto: escolher arquivo, arrastar para enquadrar e zoom.
struct EditorFoto: View {
    @Environment(CadastroStore.self) private var store
    @State private var inicio: (x: Double, y: Double)?
    @State private var escolhendo = false
    private let diametro: CGFloat = 150

    var body: some View {
        let d = store.dados
        HStack(alignment: .center, spacing: 20) {
            FotoCircular(foto: d.foto, zoom: d.fotoZoom, x: d.fotoX, y: d.fotoY, diametro: diametro)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
                .gesture(arrastar(d))
                .help(d.foto == nil ? "" : "Arraste para enquadrar o rosto")

            VStack(alignment: .leading, spacing: 10) {
                Text("Foto do currículo").font(.headline)
                Button("Escolher foto…") { escolhendo = true }
                if d.foto != nil {
                    HStack {
                        Image(systemName: "minus.magnifyingglass")
                        Slider(value: Binding(get: { store.dados.fotoZoom }, set: { v in store.alterar { $0.fotoZoom = v } }), in: 1...3)
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .frame(maxWidth: 260)
                    Text("Arraste a foto dentro do círculo para enquadrar o rosto.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Remover foto", role: .destructive) { store.alterar { $0.foto = nil } }
                        .buttonStyle(.link)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
        .fileImporter(isPresented: $escolhendo, allowedContentTypes: [.image]) { resultado in
            if case .success(let url) = resultado {
                let acesso = url.startAccessingSecurityScopedResource()
                store.definirFoto(de: url)
                if acesso { url.stopAccessingSecurityScopedResource() }
            }
        }
    }

    private func arrastar(_ d: DadosCadastro) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { valor in
                guard let foto = d.foto, let imagem = NSImage(data: foto) else { return }
                if inicio == nil { inicio = (store.dados.fotoX, store.dados.fotoY) }
                guard let ini = inicio else { return }
                let g = FotoCircular.geometria(imagem.size, diametro: diametro, zoom: store.dados.fotoZoom)
                let sobraX = max(g.width - diametro, 1), sobraY = max(g.height - diametro, 1)
                let nx = min(max(ini.x - valor.translation.width / sobraX, 0), 1)
                let ny = min(max(ini.y - valor.translation.height / sobraY, 0), 1)
                store.alterar { $0.fotoX = nx; $0.fotoY = ny }
            }
            .onEnded { _ in inicio = nil }
    }
}
