import SwiftUI

/// Uma grande mesa onde cada tarefa é um recorte de jornal.
struct MesaView: View {
    @Environment(TarefasStore.self) private var store
    @Binding var editando: Tarefa?
    @State private var marcando = false
    @State private var selecionada: Int64?

    var body: some View {
        let tamanho = TarefasStore.tamanhoMesa
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                FundoMesaView(fundo: store.fundo)
                    .frame(width: tamanho.width, height: tamanho.height)
                    .contentShape(Rectangle())
                    .onTapGesture { selecionada = nil }

                ForEach(store.tarefas) { tarefa in
                    RecorteArrastavel(
                        tarefa: tarefa,
                        prioridade: store.prioridade(de: tarefa),
                        marcando: marcando,
                        selecionada: $selecionada,
                        editando: $editando
                    )
                }
            }
            .frame(width: tamanho.width, height: tamanho.height)
        }
        .background(Color(red: 0.36, green: 0.22, blue: 0.13))
        .overlay {
            if store.tarefas.isEmpty {
                Text("Clique em + ou use ⌘N para colocar a primeira tarefa na mesa.")
                    .font(.title3)
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .overlay(alignment: .bottom) {
            BarraDaMesa(marcando: $marcando, selecionada: $selecionada)
                .padding(.bottom, 18)
        }
        .onChange(of: marcando) { _, novo in
            if !novo { selecionada = nil }
        }
    }
}

private struct RecorteArrastavel: View {
    @Environment(TarefasStore.self) private var store
    let tarefa: Tarefa
    let prioridade: Int
    let marcando: Bool
    @Binding var selecionada: Int64?
    @Binding var editando: Tarefa?

    @State private var deslocamento: CGSize = .zero
    @State private var arrastando = false

    var body: some View {
        let selecionado = marcando && selecionada == tarefa.id
        RecorteJornal(tarefa: tarefa, prioridade: prioridade, marcando: marcando) { indice in
            selecionada = tarefa.id
            store.alternarDestaque(tarefa, palavra: indice)
        }
        .rotationEffect(.degrees(arrastando ? 0 : tarefa.rotacao))
        .scaleEffect(arrastando ? 1.05 : 1)
        .shadow(
            color: selecionado ? Color.accentColor : .black.opacity(arrastando ? 0.45 : 0.32),
            radius: selecionado ? 6 : (arrastando ? 14 : 4),
            x: selecionado ? 0 : 2,
            y: selecionado ? 0 : (arrastando ? 10 : 3)
        )
        .onTapGesture(count: 2) {
            if !marcando { editando = tarefa }
        }
        .onTapGesture {
            if marcando { selecionada = tarefa.id }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { valor in
                    deslocamento = valor.translation
                    arrastando = true
                }
                .onEnded { valor in
                    store.moverNaMesa(tarefa, para: tarefa.x + valor.translation.width, tarefa.y + valor.translation.height)
                    deslocamento = .zero
                    arrastando = false
                },
            including: marcando ? .subviews : .all
        )
        .contextMenu { MenuTarefa(tarefa: tarefa, editando: $editando) }
        .animation(.spring(duration: 0.25), value: arrastando)
        .position(x: tarefa.x + deslocamento.width, y: tarefa.y + deslocamento.height)
        .zIndex(arrastando ? 1 : 0)
    }
}

/// Ferramentas flutuantes: fundo da mesa, marca-texto e cor do papel.
private struct BarraDaMesa: View {
    @Environment(TarefasStore.self) private var store
    @Binding var marcando: Bool
    @Binding var selecionada: Int64?

    var body: some View {
        HStack(spacing: 12) {
            Text("Mesa").fontWeight(.semibold)
            ForEach(FundoMesa.allCases) { fundo in
                Button {
                    store.definirFundo(fundo)
                } label: {
                    FundoMesaView(fundo: fundo)
                        .frame(width: 44, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(store.fundo == fundo ? Color.accentColor : Color.white.opacity(0.6), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .help(fundo.nome)
                .accessibilityLabel(fundo.nome)
            }

            Divider().frame(height: 26)

            Toggle(isOn: $marcando) {
                Label("Marca-texto", systemImage: "highlighter")
            }
            .toggleStyle(.button)
            .tint(.yellow)

            if marcando {
                if let id = selecionada, let tarefa = store.tarefas.first(where: { $0.id == id }) {
                    Text("Papel").fontWeight(.semibold)
                    ForEach(PapelNota.allCases) { papel in
                        Button {
                            store.definirPapel(tarefa, papel)
                        } label: {
                            Circle()
                                .fill(papel.cor)
                                .frame(width: 22, height: 22)
                                .overlay(Circle().strokeBorder(tarefa.papel == papel ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .help(papel.nome)
                        .accessibilityLabel(papel.nome)
                    }
                }
                Text(selecionada == nil ? "Clique numa nota para escolher palavras e papel" : "Clique nas palavras do título para marcar ou desmarcar")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
}

/// Desenha o fundo escolhido (também usado nas miniaturas).
struct FundoMesaView: View {
    let fundo: FundoMesa

    var body: some View {
        if let nome = fundo.imagem {
            GeometryReader { geo in
                Image(nome)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else if fundo == .branco {
            Color(red: 0.984, green: 0.984, blue: 0.976)
        } else {
            MadeiraDesenhada()
        }
    }
}

private struct MadeiraDesenhada: View {
    var body: some View {
        Canvas { ctx, tamanho in
            ctx.fill(
                Path(CGRect(origin: .zero, size: tamanho)),
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.55, green: 0.35, blue: 0.20), Color(red: 0.45, green: 0.27, blue: 0.15)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: tamanho.width, y: tamanho.height)
                )
            )
            var g = GeradorSemente(semente: 42)
            var y: CGFloat = 0
            let passo = max(tamanho.width / 20, 6)
            while y < tamanho.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < tamanho.width {
                    x += passo
                    p.addQuadCurve(
                        to: CGPoint(x: x, y: y + .random(in: -4...4, using: &g)),
                        control: CGPoint(x: x - passo / 2, y: y + .random(in: -10...10, using: &g))
                    )
                }
                ctx.stroke(p, with: .color(.black.opacity(.random(in: 0.04...0.12, using: &g))), lineWidth: .random(in: 0.5...2.5, using: &g))
                y += .random(in: 6...22, using: &g)
            }
        }
    }
}
