# AgendALLS

Suíte de mini apps para macOS, em Swift + SwiftUI, com dados em SQLite.
Desenvolvido por André S.

## Versão 0.4.0

- **Ponto**: calcula a saída padrão (9h entre entrada e saída, almoço incluído), mostra a janela de tolerância de ±10 min, aceita ajustes só do dia, simula "e se eu sair às…" e toca um alarme em tela cheia na hora de bater o ponto.
- **Tarefas**: lista com prioridade por arrastar e soltar, e mesa com recortes de jornal rasgado (arrastáveis, marca-texto nas palavras do título, 6 cores de papel, 6 fundos de mesa). Botão direito: feito / não feito, editar, excluir.
- **Links**: cards por categoria (tags coloridas com #), em ordem alfabética; o logotipo é buscado no próprio site e dá a cor ao card; clique duplo abre no Safari ou no navegador escolhido em Configurações; arraste um card para outra categoria; botão direito: editar, mover, excluir.
- **Cadastro**: dados pessoais, documentos (com botão de copiar), contato, endereço, perfil, experiência, formação, idiomas, habilidades, programas e interesses; foto enquadrada no círculo; impressão e PDF em quatro modelos (currículo no tema azul-marinho, ficha completa, só documentos, personalizado). Abre só com Touch ID, tranca após 1 minuto sem uso e fica criptografado no banco.
- Os outros mini apps ( Cadastro, Remédios, Senhas) aparecem na barra lateral e chegam nas próximas versões.

## Requisitos

- macOS 14 ou mais novo
- Xcode 16 (gratuito na App Store) para compilar

## Como compilar e instalar (gratuito)

1. Baixe o código: botão verde **Code → Download ZIP** no GitHub e descompacte.
2. Abra `AgendALLS.xcodeproj` com dois cliques.
3. Para testar: clique em ▶︎ (ou ⌘R).
4. Para instalar: **Product → Archive**, depois **Distribute App → Custom → Copy App**, salve e arraste `AgendALLS.app` para **Aplicativos**.

O projeto já vem com assinatura local ("Sign to Run Locally"), que não exige conta de desenvolvedor.

## Onde ficam os dados

`~/Library/Application Support/AgendALLS/agendalls.sqlite` — entra automaticamente no backup do Time Machine.

## Para quem for mexer no código

- `AgendALLS/` — código-fonte (um grupo por mini app).
- `scripts/gerar_projeto.rb` — regera o `AgendALLS.xcodeproj` a partir das pastas (`gem install xcodeproj`).
- `scripts/gerar_icone.py` — regera o ícone a partir da caricatura (`pip install pillow`).
- `.github/workflows/compilar.yml` — compila no GitHub a cada envio, para pegar erros cedo.
