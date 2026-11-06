import SwiftUI

/// Uma tarefa como recorte de jornal rasgado.
struct RecorteJornal: View {
    let tarefa: Tarefa
    let prioridade: Int
    var marcando = false
    var aoTocarPalavra: (Int) -> Void = { _ in }

    private static let amarelo = Color(red: 1, green: 0.898, blue: 0)
    private static let tinta = Color.black

    private var semente: UInt64 { UInt64(bitPattern: tarefa.id) &* 2_654_435_761 &+ 7 }

    private var estilo: EstiloManchete { EstiloManchete.todos[Int(tarefa.id % Int64(EstiloManchete.todos.count))] }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Nº \(prioridade)")
                Spacer()
                Text("TAREFAS")
            }
            .font(.custom("Times New Roman", size: 9).weight(.semibold))
            .tracking(0.6)

            Rectangle().frame(height: 1.5)

            FlowLayout(espaco: 4, entreLinhas: 1) {
                ForEach(Array(tarefa.palavras.enumerated()), id: \.offset) { indice, palavra in
                    let destacada = tarefa.destaques.contains(indice)
                    Text(estilo.maiusculas ? palavra.uppercased() : palavra)
                        .font(estilo.fonte)
                        .strikethrough(tarefa.feita, color: .red)
                        .padding(.horizontal, destacada ? 2 : 0)
                        .background {
                            if destacada {
                                Rectangle().fill(Self.amarelo).padding(.vertical, 2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { aoTocarPalavra(indice) }
                        .allowsHitTesting(marcando)
                }
            }

            if tarefa.notas.isEmpty {
                LinhasDeTexto(semente: semente)
            } else {
                Text(tarefa.notas)
                    .font(.custom("Times New Roman", size: 11))
                    .lineSpacing(1)
                    .lineLimit(7)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Self.tinta)
        .padding(.horizontal, 15)
        .padding(.vertical, 18)
        .frame(width: 200, alignment: .leading)
        .background { PapelJornal(papel: tarefa.papel, verso: tarefa.notas + " " + tarefa.titulo) }
        .overlay(alignment: .topTrailing) {
            if tarefa.feita {
                Text("FEITO")
                    .font(.custom("Times New Roman", size: 14).weight(.heavy))
                    .foregroundStyle(Color(red: 0.7, green: 0.07, blue: 0.16))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color(red: 0.7, green: 0.07, blue: 0.16), lineWidth: 2))
                    .rotationEffect(.degrees(-14))
                    .padding(.top, 30)
                    .padding(.trailing, 12)
            }
        }
        .clipShape(BordaRasgada(semente: semente))
    }
}

/// Fonte da manchete: cada recorte usa uma, como recortes de jornais diferentes.
struct EstiloManchete {
    let fonte: Font
    let maiusculas: Bool

    static let todos: [EstiloManchete] = [
        EstiloManchete(fonte: .custom("Times New Roman", size: 20).bold(), maiusculas: false),
        EstiloManchete(fonte: .custom("Rockwell", size: 18).weight(.heavy), maiusculas: false),
        EstiloManchete(fonte: .custom("Arial Black", size: 16), maiusculas: false),
        EstiloManchete(fonte: .custom("Futura-CondensedExtraBold", size: 20), maiusculas: true)
    ]
}

/// Fundo do recorte: cor do papel, textura de papel-jornal e o verso aparecendo.
private struct PapelJornal: View {
    let papel: PapelNota
    let verso: String

    var body: some View {
        ZStack {
            papel.cor
            Text(String(repeating: verso + " ", count: 14))
                .font(.custom("Times New Roman", size: 10))
                .foregroundStyle(.black.opacity(0.06))
                .multilineTextAlignment(.leading)
                .scaleEffect(x: -1, y: 1)
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            Image("TexturaPapel")
                .resizable(resizingMode: .tile)
                .blendMode(.multiply)
                .opacity(0.55)
        }
        .accessibilityHidden(true)
    }
}

/// Linhas cinzas imitando colunas de texto, quando a tarefa não tem anotações.
private struct LinhasDeTexto: View {
    let semente: UInt64

    var body: some View {
        var g = GeradorSemente(semente: semente)
        let larguras = (0..<5).map { _ in Double.random(in: 0.55...1, using: &g) }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(larguras.indices, id: \.self) { i in
                GeometryReader { geo in
                    Capsule()
                        .fill(.black.opacity(0.18))
                        .frame(width: geo.size.width * larguras[i], height: 3)
                }
                .frame(height: 3)
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
    }
}

/// Retângulo com as quatro bordas irregulares, como papel rasgado à mão.
struct BordaRasgada: Shape {
    let semente: UInt64

    func path(in r: CGRect) -> Path {
        var g = GeradorSemente(semente: semente)
        func rasgo(_ a: CGPoint, _ b: CGPoint, normal: CGVector, maximo: CGFloat, em p: inout Path) {
            let comprimento = hypot(b.x - a.x, b.y - a.y)
            let passos = max(Int(comprimento / 7), 2)
            for i in 1...passos {
                let t = CGFloat(i) / CGFloat(passos)
                let profundidade = i == passos ? 0 : CGFloat.random(in: 0...maximo, using: &g)
                p.addLine(to: CGPoint(
                    x: a.x + (b.x - a.x) * t + normal.dx * profundidade,
                    y: a.y + (b.y - a.y) * t + normal.dy * profundidade
                ))
            }
        }
        let tl = CGPoint(x: r.minX, y: r.minY), tr = CGPoint(x: r.maxX, y: r.minY)
        let br = CGPoint(x: r.maxX, y: r.maxY), bl = CGPoint(x: r.minX, y: r.maxY)
        var p = Path()
        p.move(to: tl)
        rasgo(tl, tr, normal: CGVector(dx: 0, dy: 1), maximo: 5, em: &p)
        rasgo(tr, br, normal: CGVector(dx: -1, dy: 0), maximo: 3, em: &p)
        rasgo(br, bl, normal: CGVector(dx: 0, dy: -1), maximo: 6, em: &p)
        rasgo(bl, tl, normal: CGVector(dx: 1, dy: 0), maximo: 3, em: &p)
        p.closeSubpath()
        return p
    }
}

/// Coloca as palavras lado a lado, quebrando a linha quando não cabem.
struct FlowLayout: Layout {
    var espaco: CGFloat = 4
    var entreLinhas: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largura = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, alturaLinha: CGFloat = 0, maiorX: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > 0 && x + t.width > largura {
                x = 0
                y += alturaLinha + entreLinhas
                alturaLinha = 0
            }
            x += t.width + espaco
            maiorX = max(maiorX, x - espaco)
            alturaLinha = max(alturaLinha, t.height)
        }
        return CGSize(width: proposal.width ?? maiorX, height: y + alturaLinha)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, alturaLinha: CGFloat = 0
        for s in subviews {
            let t = s.sizeThatFits(.unspecified)
            if x > bounds.minX && x + t.width > bounds.maxX {
                x = bounds.minX
                y += alturaLinha + entreLinhas
                alturaLinha = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(t))
            x += t.width + espaco
            alturaLinha = max(alturaLinha, t.height)
        }
    }
}
