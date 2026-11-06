import AppKit
import CryptoKit
import Foundation
import LocalAuthentication
import Observation
import Security

/// Bloqueio por Touch ID (ou senha do Mac) dos mini apps sensíveis.
/// Tranca sozinho após 1 minuto sem uso e quando o Mac dorme.
@MainActor
@Observable
final class Cofre {
    private(set) var desbloqueado = false
    private(set) var mensagem: String?

    /// Tempo sem uso até trancar.
    static let tempoParaTrancar: TimeInterval = 60

    @ObservationIgnored private var ultimaAtividade = Date()
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var relogio: Timer?
    @ObservationIgnored private var observadorSono: NSObjectProtocol?
    /// Chamado logo após trancar (para apagar os dados da memória).
    @ObservationIgnored var aoTrancar: [() -> Void] = []

    init() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] evento in
            self?.ultimaAtividade = Date()
            return evento
        }
        relogio = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.desbloqueado else { return }
                if Date().timeIntervalSince(self.ultimaAtividade) > Self.tempoParaTrancar { self.trancar() }
            }
        }
        observadorSono = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.trancar() }
        }
    }

    func desbloquear(motivo: String) async {
        let contexto = LAContext()
        contexto.localizedCancelTitle = "Cancelar"
        var erro: NSError?
        guard contexto.canEvaluatePolicy(.deviceOwnerAuthentication, error: &erro) else {
            mensagem = "Este Mac não permite autenticação: \(erro?.localizedDescription ?? "motivo desconhecido")."
            return
        }
        do {
            try await contexto.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: motivo)
            mensagem = nil
            ultimaAtividade = Date()
            desbloqueado = true
        } catch {
            mensagem = nil
        }
    }

    func trancar() {
        guard desbloqueado else { return }
        desbloqueado = false
        aoTrancar.forEach { $0() }
    }
}

/// Criptografia AES-GCM com uma chave de 256 bits guardada no Keychain do Mac.
enum Cripto {
    private static let servico = "br.andres.agendalls"
    private static let conta = "chave-do-cofre"

    static func cifrar(_ dados: Data) throws -> Data {
        guard let combinado = try AES.GCM.seal(dados, using: chave()).combined else {
            throw ErroBanco.falha("Falha ao criptografar")
        }
        return combinado
    }

    static func decifrar(_ dados: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: dados), using: chave())
    }

    private static func chave() throws -> SymmetricKey {
        if let existente = try lerDoKeychain() { return SymmetricKey(data: existente) }
        let nova = SymmetricKey(size: .bits256)
        try salvarNoKeychain(nova.withUnsafeBytes { Data($0) })
        return nova
    }

    private static func lerDoKeychain() throws -> Data? {
        let consulta: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var resultado: AnyObject?
        let status = SecItemCopyMatching(consulta as CFDictionary, &resultado)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let dados = resultado as? Data else {
            throw ErroBanco.falha("Não foi possível ler a chave do Keychain (código \(status)).")
        }
        return dados
    }

    private static func salvarNoKeychain(_ dados: Data) throws {
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servico,
            kSecAttrAccount as String: conta,
            kSecAttrLabel as String: "AgendALLS – chave do cofre",
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: dados
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ErroBanco.falha("Não foi possível guardar a chave no Keychain (código \(status)).")
        }
    }
}

extension BancoDeDados {
    /// Lê um item do cofre, já decifrado.
    func lerCofre(_ chave: String) throws -> Data? {
        guard let texto = try consultar("SELECT dados FROM cofre WHERE chave = ?", [.texto(chave)]).first?.first?.texto,
              let cifrado = Data(base64Encoded: texto)
        else { return nil }
        return try Cripto.decifrar(cifrado)
    }

    /// Grava um item no cofre, criptografado.
    func gravarCofre(_ chave: String, _ dados: Data) throws {
        let cifrado = try Cripto.cifrar(dados).base64EncodedString()
        try executar(
            "INSERT INTO cofre (chave, dados) VALUES (?, ?) ON CONFLICT(chave) DO UPDATE SET dados = excluded.dados",
            [.texto(chave), .texto(cifrado)]
        )
    }
}
