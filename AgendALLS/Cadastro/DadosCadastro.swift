import Foundation

struct Programa: Codable, Hashable, Identifiable {
    var id = UUID()
    var nome = ""
    var nivel = 3
}

struct Experiencia: Codable, Hashable, Identifiable {
    var id = UUID()
    var cargo = ""
    var empresa = ""
    var cidade = ""
    var periodo = ""
    /// Uma realização por linha.
    var realizacoes = ""
}

struct Formacao: Codable, Hashable, Identifiable {
    var id = UUID()
    var curso = ""
    var instituicao = ""
    var cidade = ""
    var periodo = ""
}

struct CampoExtra: Codable, Hashable, Identifiable {
    var id = UUID()
    var secao: String
    var rotulo: String
    var valor = ""
}

/// Tudo o que o Cadastro guarda. É salvo inteiro, criptografado, no cofre.
struct DadosCadastro: Codable, Equatable {
    var campos: [String: String] = [:]
    var extras: [CampoExtra] = []
    var foto: Data?
    var fotoZoom: Double = 1
    var fotoX: Double = 0.5
    var fotoY: Double = 0.5
    var perfil = ""
    var idiomas = ""
    var habilidades = ""
    var interesses = ""
    var programas: [Programa] = []
    var experiencias: [Experiencia] = []
    var formacao: [Formacao] = []

    func valor(_ chave: String) -> String { campos[chave] ?? "" }

    static func linhas(_ texto: String) -> [String] {
        texto.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

enum TipoSecao {
    case campos([(chave: String, rotulo: String)])
    case texto(chave: WritableKeyPath<DadosCadastro, String>, dica: String)
    case experiencias, formacao, programas
}

enum SecaoCadastro: String, CaseIterable, Identifiable {
    case pessoal, documentos, contato, endereco, perfil, experiencia, formacao, idiomas, habilidades, programas, interesses

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .pessoal: "Dados pessoais"
        case .documentos: "Documentos"
        case .contato: "Contato"
        case .endereco: "Endereço"
        case .perfil: "Perfil profissional"
        case .experiencia: "Experiência"
        case .formacao: "Formação"
        case .idiomas: "Idiomas"
        case .habilidades: "Habilidades"
        case .programas: "Programas"
        case .interesses: "Interesses"
        }
    }

    var icone: String {
        switch self {
        case .pessoal: "person"
        case .documentos: "doc.text"
        case .contato: "phone"
        case .endereco: "house"
        case .perfil: "text.quote"
        case .experiencia: "briefcase"
        case .formacao: "graduationcap"
        case .idiomas: "globe"
        case .habilidades: "star"
        case .programas: "laptopcomputer"
        case .interesses: "heart"
        }
    }

    var tipo: TipoSecao {
        switch self {
        case .pessoal:
            .campos([("nome", "Nome completo"), ("cargo", "Profissão / cargo"), ("nascimento", "Data de nascimento"),
                     ("naturalidade", "Naturalidade"), ("estadoCivil", "Estado civil"), ("mae", "Nome da mãe"), ("pai", "Nome do pai")])
        case .documentos:
            .campos([("cpf", "CPF"), ("rg", "RG"), ("orgaoEmissor", "Órgão emissor"), ("cnh", "CNH"), ("validadeCNH", "Validade da CNH"),
                     ("tituloEleitor", "Título de eleitor"), ("pis", "PIS/NIS"), ("ctps", "CTPS"), ("passaporte", "Passaporte")])
        case .contato:
            .campos([("telefone", "Telefone"), ("email", "E-mail"), ("cidade", "Cidade/UF"), ("linkedin", "LinkedIn")])
        case .endereco:
            .campos([("cep", "CEP"), ("logradouro", "Logradouro"), ("numero", "Número"), ("complemento", "Complemento"),
                     ("bairro", "Bairro"), ("cidadeEndereco", "Cidade/UF")])
        case .perfil: .texto(chave: \.perfil, dica: "Resumo de 3 a 5 linhas: formação, experiência e especialidade.")
        case .experiencia: .experiencias
        case .formacao: .formacao
        case .idiomas: .texto(chave: \.idiomas, dica: "Um por linha. Ex.: Inglês: Intermediário (B2)")
        case .habilidades: .texto(chave: \.habilidades, dica: "Uma por linha.")
        case .programas: .programas
        case .interesses: .texto(chave: \.interesses, dica: "Um por linha.")
        }
    }

    /// Seções de campos simples, usadas nas fichas.
    static var deCampos: [SecaoCadastro] { [.pessoal, .documentos, .contato, .endereco] }
}

enum ModeloImpressao: String, CaseIterable, Identifiable {
    case curriculo, fichaCompleta, documentos, personalizado

    var id: String { rawValue }

    var nome: String {
        switch self {
        case .curriculo: "Currículo"
        case .fichaCompleta: "Ficha completa"
        case .documentos: "Só documentos"
        case .personalizado: "Personalizado"
        }
    }
}
