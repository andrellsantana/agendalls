# Agenda

App de agendamentos para iOS 17+ em Swift + SwiftUI, com persistência em SQLite (API nativa `sqlite3`, sem dependências).

## Funcionalidades
- Lista de agendamentos agrupada por dia
- Criar, editar e excluir (deslizar ou dentro do formulário)
- Campos: título, cliente, data/hora, notas
- Lembretes por notificação local

## Como abrir no Xcode
O projeto é gerado com [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
brew install xcodegen
xcodegen generate
open Agenda.xcodeproj
```

## Estrutura
- `Agenda/Database/Database.swift`: conexão SQLite, migração e CRUD
- `Agenda/Store/AgendaStore.swift`: estado observável usado pelas telas
- `Agenda/Services/Notificacoes.swift`: lembretes locais
- `Agenda/Views/`: telas SwiftUI
