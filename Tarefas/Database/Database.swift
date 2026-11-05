import Foundation
import SQLite3

enum DatabaseError: Error, CustomStringConvertible {
    case falha(String)
    var description: String { if case .falha(let m) = self { return m }; return "" }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Acesso ao SQLite usando a API C nativa (sem dependências).
final class Database {
    private var db: OpaquePointer?

    init(caminho: URL? = nil) throws {
        let url: URL
        if let caminho { url = caminho } else {
            let pasta = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("Tarefas", isDirectory: true)
            try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
            url = pasta.appendingPathComponent("tarefas.sqlite")
        }
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw erro }
        try executar("""
        CREATE TABLE IF NOT EXISTS tarefas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titulo TEXT NOT NULL,
            notas TEXT NOT NULL DEFAULT '',
            concluida INTEGER NOT NULL DEFAULT 0,
            ordem INTEGER NOT NULL DEFAULT 0,
            x REAL NOT NULL DEFAULT 0,
            y REAL NOT NULL DEFAULT 0,
            rotacao REAL NOT NULL DEFAULT 0
        );
        """)
    }

    deinit { sqlite3_close(db) }

    private var erro: DatabaseError { .falha(String(cString: sqlite3_errmsg(db))) }

    private func executar(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw erro }
    }

    /// Prepara, vincula os parâmetros e executa um comando que não retorna linhas.
    private func rodar(_ sql: String, _ params: [Any?]) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw erro }
        defer { sqlite3_finalize(stmt) }
        for (i, p) in params.enumerated() {
            let idx = Int32(i + 1)
            switch p {
            case let v as String: sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            case let v as Int64:  sqlite3_bind_int64(stmt, idx, v)
            case let v as Int:    sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Bool:   sqlite3_bind_int(stmt, idx, v ? 1 : 0)
            case let v as Double: sqlite3_bind_double(stmt, idx, v)
            default:              sqlite3_bind_null(stmt, idx)
            }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw erro }
    }

    func listar() throws -> [Tarefa] {
        var stmt: OpaquePointer?
        let sql = "SELECT id, titulo, notas, concluida, ordem, x, y, rotacao FROM tarefas ORDER BY ordem, id"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw erro }
        defer { sqlite3_finalize(stmt) }
        var itens: [Tarefa] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            itens.append(Tarefa(
                id: sqlite3_column_int64(stmt, 0),
                titulo: String(cString: sqlite3_column_text(stmt, 1)),
                notas: String(cString: sqlite3_column_text(stmt, 2)),
                concluida: sqlite3_column_int(stmt, 3) != 0,
                ordem: Int(sqlite3_column_int(stmt, 4)),
                x: sqlite3_column_double(stmt, 5),
                y: sqlite3_column_double(stmt, 6),
                rotacao: sqlite3_column_double(stmt, 7)
            ))
        }
        return itens
    }

    func salvar(_ t: Tarefa) throws {
        let campos: [Any?] = [t.titulo, t.notas, t.concluida, t.ordem, t.x, t.y, t.rotacao]
        if let id = t.id {
            try rodar("UPDATE tarefas SET titulo=?, notas=?, concluida=?, ordem=?, x=?, y=?, rotacao=? WHERE id=?",
                      campos + [id])
        } else {
            try rodar("INSERT INTO tarefas (titulo, notas, concluida, ordem, x, y, rotacao) VALUES (?,?,?,?,?,?,?)",
                      campos)
        }
    }

    func excluir(id: Int64) throws {
        try rodar("DELETE FROM tarefas WHERE id=?", [id])
    }

    /// Grava a nova ordem de prioridade de uma vez, numa transação.
    func reordenar(ids: [Int64]) throws {
        try executar("BEGIN")
        do {
            for (ordem, id) in ids.enumerated() {
                try rodar("UPDATE tarefas SET ordem=? WHERE id=?", [ordem, id])
            }
            try executar("COMMIT")
        } catch {
            try? executar("ROLLBACK")
            throw error
        }
    }
}
