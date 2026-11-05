import Foundation
import SQLite3

enum DatabaseError: Error {
    case abrir(String), executar(String), preparar(String)
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Acesso ao SQLite usando a API C nativa (sem dependências).
final class Database {
    private var db: OpaquePointer?

    init(caminho: URL? = nil) throws {
        let url = try caminho ?? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("agenda.sqlite")
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw DatabaseError.abrir(mensagemErro) }
        try migrar()
    }

    deinit { sqlite3_close(db) }

    private var mensagemErro: String { String(cString: sqlite3_errmsg(db)) }

    private func executar(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw DatabaseError.executar(mensagemErro) }
    }

    private func preparar(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw DatabaseError.preparar(mensagemErro) }
        return stmt
    }

    private func migrar() throws {
        try executar("""
        CREATE TABLE IF NOT EXISTS agendamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            titulo TEXT NOT NULL,
            cliente TEXT NOT NULL DEFAULT '',
            data REAL NOT NULL,
            notas TEXT NOT NULL DEFAULT '',
            lembrete_minutos INTEGER
        );
        CREATE INDEX IF NOT EXISTS idx_agendamentos_data ON agendamentos(data);
        """)
    }

    // MARK: - CRUD

    func listar() throws -> [Agendamento] {
        let stmt = try preparar("SELECT id, titulo, cliente, data, notas, lembrete_minutos FROM agendamentos ORDER BY data")
        defer { sqlite3_finalize(stmt) }
        var itens: [Agendamento] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            itens.append(Agendamento(
                id: sqlite3_column_int64(stmt, 0),
                titulo: String(cString: sqlite3_column_text(stmt, 1)),
                cliente: String(cString: sqlite3_column_text(stmt, 2)),
                data: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 3)),
                notas: String(cString: sqlite3_column_text(stmt, 4)),
                lembreteMinutos: sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 5))
            ))
        }
        return itens
    }

    @discardableResult
    func salvar(_ a: Agendamento) throws -> Int64 {
        let sql = a.id == nil
            ? "INSERT INTO agendamentos (titulo, cliente, data, notas, lembrete_minutos) VALUES (?, ?, ?, ?, ?)"
            : "UPDATE agendamentos SET titulo = ?, cliente = ?, data = ?, notas = ?, lembrete_minutos = ? WHERE id = ?"
        let stmt = try preparar(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, a.titulo, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, a.cliente, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 3, a.data.timeIntervalSince1970)
        sqlite3_bind_text(stmt, 4, a.notas, -1, SQLITE_TRANSIENT)
        if let m = a.lembreteMinutos { sqlite3_bind_int(stmt, 5, Int32(m)) } else { sqlite3_bind_null(stmt, 5) }
        if let id = a.id { sqlite3_bind_int64(stmt, 6, id) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.executar(mensagemErro) }
        return a.id ?? sqlite3_last_insert_rowid(db)
    }

    func excluir(id: Int64) throws {
        let stmt = try preparar("DELETE FROM agendamentos WHERE id = ?")
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, id)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw DatabaseError.executar(mensagemErro) }
    }
}
