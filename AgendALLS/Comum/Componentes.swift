import SwiftUI

/// Caixa com título usada nas telas dos mini apps.
struct Cartao<Conteudo: View>: View {
    let titulo: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(titulo).font(.headline)
            conteudo
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(nsColor: .separatorColor)))
    }
}

/// Rodapé da janela: nome, versão e desenvolvedor.
struct Rodape: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 16, height: 16)
                .accessibilityHidden(true)
            Text(Versao.nome).fontWeight(.semibold)
            Text("versão \(Versao.atual)").foregroundStyle(.secondary)
            Spacer()
            Text("Desenvolvido por \(Versao.desenvolvedor)").foregroundStyle(.secondary)
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .frame(height: 26)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}
