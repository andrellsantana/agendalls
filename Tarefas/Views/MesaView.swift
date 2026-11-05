import SwiftUI

/// Uma grande mesa de madeira onde cada tarefa é um recorte de jornal.
struct MesaView: View {
    @Environment(TarefasStore.self) private var store
    @Binding var editando: Tarefa?

    static let tamanho = CGSize(width: 2400, height: 1600)

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                FundoMesa()
                ForEach(store.tarefas) { tarefa in
                    RecorteArrastavel(tarefa: tarefa, editando: $editando)
                }
            }
            .frame(width: Self.tamanho.width, height: Self.tamanho.height)
        }
        .background(Color(red: 0.36, green: 0.22, blue: 0.13))
    }
}

private struct RecorteArrastavel: View {
    @Environment(TarefasStore.self) private var store
    let tarefa: Tarefa
    @Binding var editando: Tarefa?
    @State private var deslocamento: CGSize = .zero
    @State private var arrastando = false

    var body: some View {
        RecorteJornal(tarefa: tarefa, prioridade: store.prioridade(de: tarefa))
            .rotationEffect(.degrees(arrastando ? 0 : tarefa.rotacao))
            .scaleEffect(arrastando ? 1.06 : 1)
            .shadow(color: .black.opacity(arrastando ? 0.45 : 0.3),
                    radius: arrastando ? 14 : 4, x: 2, y: arrastando ? 10 : 3)
            .position(x: tarefa.x + deslocamento.width, y: tarefa.y + deslocamento.height)
            .zIndex(arrastando ? 1 : 0)
            .animation(.spring(duration: 0.25), value: arrastando)
            .onTapGesture(count: 2) { editando = tarefa }
            .gesture(
                DragGesture()
                    .onChanged { deslocamento = $0.translation; arrastando = true }
                    .onEnded { v in
                        let m = MesaView.tamanho
                        let destino = CGPoint(
                            x: min(max(tarefa.x + v.translation.width, 100), m.width - 100),
                            y: min(max(tarefa.y + v.translation.height, 100), m.height - 100))
                        store.moverNaMesa(tarefa, para: destino)
                        deslocamento = .zero
                        arrastando = false
                    }
            )
            .contextMenu {
                Button("Editar…") { editando = tarefa }
                Button(tarefa.concluida ? "Marcar como pendente" : "Marcar como concluída") {
                    var t = tarefa; t.concluida.toggle(); store.atualizar(t)
                }
                Divider()
                Button("Excluir", role: .destructive) { store.excluir(tarefa) }
            }
    }
}

/// O recorte em si: papel-jornal amarelado com bordas rasgadas.
struct RecorteJornal: View {
    let tarefa: Tarefa
    let prioridade: Int

    private var semente: UInt64 { UInt64(bitPattern: tarefa.id ?? 0) &* 2654435761 &+ 7 }

    var body: some View {
        let papel = Color(red: 0.93, green: 0.90, blue: 0.82)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Nº \(prioridade)")
                Spacer()
                Text("TAREFAS")
            }
            .font(.system(size: 9, weight: .semibold, design: .serif))
            .foregroundStyle(.black.opacity(0.55))
            Rectangle().fill(.black.opacity(0.6)).frame(height: 1.5)

            Text(tarefa.titulo)
                .font(.system(size: 17, weight: .black, design: .serif))
                .foregroundStyle(.black.opacity(0.85))
                .strikethrough(tarefa.concluida, color: .red.opacity(0.8))
                .lineLimit(4)

            if !tarefa.notas.isEmpty {
                Text(tarefa.notas)
                    .font(.system(size: 10.5, design: .serif))
                    .foregroundStyle(.black.opacity(0.7))
                    .lineSpacing(1)
                    .multilineTextAlignment(.leading)
                    .lineLimit(7)
            } else {
                TextoFalso(semente: semente)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(width: 190, alignment: .leading)
        .background {
            ZStack {
                papel
                // manchas leves de papel velho
                RadialGradient(colors: [.clear, .brown.opacity(0.18)], center: .center,
                               startRadius: 40, endRadius: 160)
            }
        }
        .clipShape(BordaRasgada(semente: semente))
        .overlay(alignment: .topTrailing) {
            if tarefa.concluida {
                Text("FEITO")
                    .font(.system(size: 13, weight: .heavy, design: .serif))
                    .foregroundStyle(.red.opacity(0.75))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(.red.opacity(0.75), lineWidth: 2))
                    .rotationEffect(.degrees(-14))
                    .padding(10)
            }
        }
    }
}

/// Linhas cinzas imitando colunas de texto de jornal.
private struct TextoFalso: View {
    let semente: UInt64
    var body: some View {
        var gerador = GeradorSemente(semente: semente)
        let larguras = (0..<5).map { _ in Double.random(in: 0.55...1, using: &gerador) }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(larguras.indices, id: \.self) { i in
                GeometryReader { g in
                    Capsule().fill(.black.opacity(0.18))
                        .frame(width: g.size.width * larguras[i], height: 3)
                }
                .frame(height: 3)
            }
        }
        .padding(.top, 2)
    }
}

/// Retângulo com as quatro bordas irregulares, como papel rasgado à mão.
struct BordaRasgada: Shape {
    let semente: UInt64

    func path(in r: CGRect) -> Path {
        var g = GeradorSemente(semente: semente)
        func rasgo(_ a: CGPoint, _ b: CGPoint, _ normal: CGVector, into p: inout Path) {
            let comprimento = hypot(b.x - a.x, b.y - a.y)
            let passos = max(Int(comprimento / 7), 2)
            for i in 1...passos {
                let t = CGFloat(i) / CGFloat(passos)
                let profundidade = i == passos ? 0 : CGFloat.random(in: 0...5, using: &g)
                p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * t + normal.dx * profundidade,
                                      y: a.y + (b.y - a.y) * t + normal.dy * profundidade))
            }
        }
        let r = r.insetBy(dx: 1, dy: 1)
        let (tl, tr) = (CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.maxX, y: r.minY))
        let (br, bl) = (CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY))
        var p = Path()
        p.move(to: tl)
        rasgo(tl, tr, CGVector(dx: 0, dy: 1), into: &p)
        rasgo(tr, br, CGVector(dx: -0.4, dy: 0), into: &p)
        rasgo(br, bl, CGVector(dx: 0, dy: -1), into: &p)
        rasgo(bl, tl, CGVector(dx: 0.4, dy: 0), into: &p)
        p.closeSubpath()
        return p
    }
}

/// Tampo de madeira desenhado com veios.
private struct FundoMesa: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.55, green: 0.35, blue: 0.20),
                                  Color(red: 0.45, green: 0.27, blue: 0.15)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            var g = GeradorSemente(semente: 42)
            var y: CGFloat = 0
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < size.width {
                    x += 120
                    p.addQuadCurve(to: CGPoint(x: x, y: y + .random(in: -4...4, using: &g)),
                                   control: CGPoint(x: x - 60, y: y + .random(in: -10...10, using: &g)))
                }
                ctx.stroke(p, with: .color(.black.opacity(.random(in: 0.04...0.12, using: &g))),
                           lineWidth: .random(in: 0.5...2.5, using: &g))
                y += .random(in: 6...22, using: &g)
            }
        }
    }
}

/// Gerador pseudoaleatório determinístico (SplitMix64): mesmo recorte, mesmo rasgo.
struct GeradorSemente: RandomNumberGenerator {
    private var estado: UInt64
    init(semente: UInt64) { estado = semente }
    mutating func next() -> UInt64 {
        estado &+= 0x9E3779B97F4A7C15
        var z = estado
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
