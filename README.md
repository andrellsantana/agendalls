# Tarefas

App nativo para macOS 14+ em Swift + SwiftUI, com persistência em SQLite (API nativa `sqlite3`, sem dependências).

## Funcionalidades
- **Lista**: tarefas numeradas por prioridade; arraste e solte para reordenar. Marque como concluída pela caixa de seleção.
- **Mesa**: cada tarefa vira um recorte de jornal rasgado sobre uma mesa de madeira. Arraste os recortes para onde quiser; a posição fica salva.
- Criar com **⌘N** ou o botão **+**; editar com clique duplo; excluir pelo menu de contexto (clique direito).

## Como abrir no Xcode
O projeto é gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open Tarefas.xcodeproj
```

O banco fica em `~/Library/Application Support/Tarefas/tarefas.sqlite`.

## Estrutura
- `Tarefas/Database/Database.swift`: conexão SQLite, tabela e CRUD
- `Tarefas/Store/TarefasStore.swift`: estado observável usado pelas telas
- `Tarefas/Views/ListaView.swift`: lista com arrastar e soltar
- `Tarefas/Views/MesaView.swift`: mesa, recortes e borda rasgada
