import Foundation
import SQLite3

/// Valor trocado com o SQLite.
enum ValorSQL {
    case texto(String)
    case inteiro(Int)
    case real(Double)
    case nulo

    var texto: String? {
        if case .texto(let v) = self { return v }
        return nil
    }

    var inteiro: Int? {
        switch self {
        case .inteiro(let v): return v
        case .real(let v): return Int(v)
        case .texto(let v): return Int(v)
        case .nulo: return nil
        }
    }
}

enum ErroBanco: Error, CustomStringConvertible {
    case falha(String)
    var description: String {
        if case .falha(let mensagem) = self { return mensagem }
        return "Erro desconhecido"
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// Acesso ao banco SQLite do AgendALLS, usando a biblioteca nativa do macOS.
/// O arquivo fica em ~/Library/Application Support/AgendALLS/agendalls.sqlite.
final class BancoDeDados {
    static let compartilhado: BancoDeDados = {
        do {
            return try BancoDeDados()
        } catch {
            fatalError("Não foi possível abrir o banco de dados: \(error)")
        }
    }()

    private var db: OpaquePointer?

    init(url: URL? = nil) throws {
        let destino: URL
        if let url {
            destino = url
        } else {
            let pasta = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("AgendALLS", isDirectory: true)
            try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
            destino = pasta.appendingPathComponent("agendalls.sqlite")
        }
        guard sqlite3_open(destino.path, &db) == SQLITE_OK else { throw erroAtual }
        try executarScript("PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;")
        try migrar()
    }

    deinit { sqlite3_close(db) }

    private var erroAtual: ErroBanco { .falha(String(cString: sqlite3_errmsg(db))) }

    // MARK: - Migrações

    /// Cada item é uma versão do esquema. Nunca altere um item já publicado: acrescente outro no fim.
    private let migracoes: [String] = [
        """
        CREATE TABLE config (
            chave TEXT PRIMARY KEY,
            valor TEXT NOT NULL
        );
        CREATE TABLE ponto_dia (
            data TEXT PRIMARY KEY,
            entrada_min INTEGER NOT NULL
        );
        CREATE TABLE ponto_ajuste (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data TEXT NOT NULL,
            minutos INTEGER NOT NULL,
            descricao TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX idx_ponto_ajuste_data ON ponto_ajuste(data);
        """
    ]

    private func migrar() throws {
        let atual = try consultar("PRAGMA user_version").first?.first?.inteiro ?? 0
        guard atual < migracoes.count else { return }
        for versao in atual..<migracoes.count {
            try executarScript("BEGIN")
            do {
                try executarScript(migracoes[versao])
                try executarScript("PRAGMA user_version = \(versao + 1)")
                try executarScript("COMMIT")
            } catch {
                try? executarScript("ROLLBACK")
                throw error
            }
        }
    }

    // MARK: - Execução

    /// Executa um ou mais comandos sem parâmetros.
    func executarScript(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw erroAtual }
    }

    /// Executa um comando com parâmetros e retorna o id da última linha inserida.
    @discardableResult
    func executar(_ sql: String, _ parametros: [ValorSQL] = []) throws -> Int64 {
        let stmt = try preparar(sql, parametros)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw erroAtual }
        return sqlite3_last_insert_rowid(db)
    }

    /// Executa uma consulta e devolve as linhas, cada uma como lista de colunas.
    func consultar(_ sql: String, _ parametros: [ValorSQL] = []) throws -> [[ValorSQL]] {
        let stmt = try preparar(sql, parametros)
        defer { sqlite3_finalize(stmt) }
        var linhas: [[ValorSQL]] = []
        while true {
            let passo = sqlite3_step(stmt)
            if passo == SQLITE_DONE { break }
            guard passo == SQLITE_ROW else { throw erroAtual }
            var linha: [ValorSQL] = []
            for i in 0..<sqlite3_column_count(stmt) {
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: linha.append(.inteiro(Int(sqlite3_column_int64(stmt, i))))
                case SQLITE_FLOAT: linha.append(.real(sqlite3_column_double(stmt, i)))
                case SQLITE_TEXT: linha.append(.texto(String(cString: sqlite3_column_text(stmt, i))))
                default: linha.append(.nulo)
                }
            }
            linhas.append(linha)
        }
        return linhas
    }

    private func preparar(_ sql: String, _ parametros: [ValorSQL]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw erroAtual }
        for (i, valor) in parametros.enumerated() {
            let indice = Int32(i + 1)
            switch valor {
            case .texto(let v): sqlite3_bind_text(stmt, indice, v, -1, SQLITE_TRANSIENT)
            case .inteiro(let v): sqlite3_bind_int64(stmt, indice, Int64(v))
            case .real(let v): sqlite3_bind_double(stmt, indice, v)
            case .nulo: sqlite3_bind_null(stmt, indice)
            }
        }
        return stmt
    }

    // MARK: - Configurações (chave/valor)

    func config(_ chave: String) -> String? {
        (try? consultar("SELECT valor FROM config WHERE chave = ?", [.texto(chave)]))?.first?.first?.texto
    }

    func definirConfig(_ chave: String, _ valor: String) {
        _ = try? executar(
            "INSERT INTO config (chave, valor) VALUES (?, ?) ON CONFLICT(chave) DO UPDATE SET valor = excluded.valor",
            [.texto(chave), .texto(valor)]
        )
    }
}
