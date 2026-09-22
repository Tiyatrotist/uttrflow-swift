// The speech models the app can install.
public import UttrflowCore

/// One pinned file that makes up a speech model.
public struct SpeechModelFile: Sendable, Hashable, Codable {
    /// Expected size of the file at the pinned revision.
    public let bytes: Int64
    /// Expected SHA-256 of the file at the pinned revision.
    public let sha256: String

    public init(bytes: Int64, sha256: String) {
        self.bytes = bytes
        self.sha256 = sha256
    }
}

/// A speech-recognition model the app can install; sizes are the real download, shown before the wait.
public struct SpeechModel: Sendable, Hashable, Codable {
    /// Identifier used by the model repository.
    public let variant: String
    /// Total bytes fetched when installing.
    public let downloadBytes: Int64
    /// Whether it recognises languages other than English.
    public let isMultilingual: Bool
    /// The repository publishing the compiled CoreML weights.
    public let weightsRepository: String
    /// The commit the weights are fetched at, so a repository push cannot change a new install.
    public let weightsRevision: String
    /// What each CoreML file must weigh and hash to at that commit.
    public let weightFiles: [String: SpeechModelFile]
    /// The repository publishing the tokenizer, which is OpenAI's while the weights are a CoreML build.
    public let tokenizerRepository: String
    /// The commit the tokenizer is fetched at, so an install a year from now is the install measured here.
    public let tokenizerRevision: String
    /// What each tokenizer file must hash to at that commit, since a pinned name is not a pinned file.
    public let tokenizerDigests: [String: String]

    public init(
        variant: String, downloadBytes: Int64, isMultilingual: Bool,
        weightsRepository: String, weightsRevision: String, weightFiles: [String: SpeechModelFile],
        tokenizerRepository: String,
        tokenizerRevision: String, tokenizerDigests: [String: String]
    ) {
        self.variant = variant
        self.downloadBytes = downloadBytes
        self.isMultilingual = isMultilingual
        self.weightsRepository = weightsRepository
        self.weightsRevision = weightsRevision
        self.weightFiles = weightFiles
        self.tokenizerRepository = tokenizerRepository
        self.tokenizerRevision = tokenizerRevision
        self.tokenizerDigests = tokenizerDigests
    }
}

extension SpeechModel {
    /// What the app installs unless told otherwise: multilingual, and half the decode time of large-v3.
    public static let `default` = largeV3Turbo

    /// A distilled decoder over large-v3's encoder, sharing its vocabulary and therefore its tokenizer.
    public static let largeV3Turbo = SpeechModel(
        variant: "openai_whisper-large-v3-v20240930_turbo_632MB",
        downloadBytes: 645_668_913,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 348,
                sha256: "ffa9eb76e8e9d9be75a4d527e5249e61d67fd43081c5aa110fd24efa6c8c5ea3"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 421_968_768,
                sha256: "e4740fa28ed65907af754af893dfce98473fafb84dd8d718ad346985fe7678c1"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 329,
                sha256: "98efa1e351b759e078c4044668926d32bee886caf7596ae897e08e21da45565a"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 373_376,
                sha256: "009d9fb8f6b589accfa08cebf1c712ef07c3405229ce3cfb3a57ee033c9d8a49"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "605dad4099a82cf2c7afe93e6d8e322f1c16d4160ab27bd017ec2517b81c1bdd"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 203_199_860,
                sha256: "d69700903d518ada33170ab77faaaf464496fb9ff65752c6d5a6109aa2fb02db"),
        ],
        tokenizerRepository: "openai/whisper-large-v3",
        tokenizerRevision: "06f233fe06e710322aca913c1bc4249a0d71fce1",
        tokenizerDigests: [
            "tokenizer.json": "6d8cbd7cd0d8d5815e478dac67b85a26bbe77c1f5e0c6d76d1ce2abc0e5f21ca",
            "tokenizer_config.json": "844b642c73a91359722f47b35705f7174686df33d252695d8572cf9ac03a6389",
        ]
    )

    public static let small = SpeechModel(
        variant: "openai_whisper-small",
        downloadBytes: 486_487_465,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 347,
                sha256: "d68f152b6573ac55203a3dc8383730e6ecde685c7d2a88815b89820c88e35371"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 176_323_456,
                sha256: "fe35cef2c9406993a635639b16f373f6debb0215ac115b7bf93fa03c8e10310b"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 328,
                sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 354_080,
                sha256: "267017e533b5f542d195fd9a775f2ba649075128283ce8e86c63a2ec20de5b07"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "b2ccd0b8920701386ab9554f7db47b43e55ee07863280ee5d829d5272839adc2"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 307_287_346,
                sha256: "bfea8044a8f38e8d33f56585b1e75ce023d3845e2a945e20480bd7e16558016e"),
        ],
        tokenizerRepository: "openai/whisper-small",
        tokenizerRevision: "973afd24965f72e36ca33b3055d56a652f456b4d",
        tokenizerDigests: [
            "tokenizer.json": "27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566",
            "tokenizer_config.json": "2a4c4281cf9f51ac6ccc406fdc711a087afe6530f671fa7b80953edc498275ce",
        ]
    )

    /// Fastest and least accurate, present as a floor for the benchmark rather than a choice.
    public static let base = SpeechModel(
        variant: "openai_whisper-base",
        downloadBytes: 146_719_453,
        isMultilingual: true,
        weightsRepository: "argmaxinc/whisperkit-coreml",
        weightsRevision: "0f63a7800b00dd0226abd051b906c246e1907482",
        weightFiles: [
            "AudioEncoder.mlmodelc/coremldata.bin": .init(
                bytes: 347,
                sha256: "e316980638e2099e83cb1a93b903717dc12b3c2168d0ab69113764c3767696ba"),
            "AudioEncoder.mlmodelc/weights/weight.bin": .init(
                bytes: 41_189_632,
                sha256: "061ff4d74e5de3937b31288465d6c6f2697f92d121c80b23f51dd26bbdfe642b"),
            "MelSpectrogram.mlmodelc/coremldata.bin": .init(
                bytes: 328,
                sha256: "dabdc5aa69f6ef4d97dc9499f5c30514e00e96b53b750b33a5a6471363c71662"),
            "MelSpectrogram.mlmodelc/weights/weight.bin": .init(
                bytes: 354_080,
                sha256: "35d74417ef9c765e70f4ef85fe7405015a7086e9af05e3b63a5c2c7c748b2efc"),
            "TextDecoder.mlmodelc/coremldata.bin": .init(
                bytes: 633,
                sha256: "9f1f6fe409486e2797d3f0c65d9a6d5af596771760548cd86f41939c54cdbe7c"),
            "TextDecoder.mlmodelc/weights/weight.bin": .init(
                bytes: 104_122_162,
                sha256: "72325d42a4a4ccc8a6fa974ede6cdf2e0770685a5c4f9da94f41495b94d8d174"),
        ],
        tokenizerRepository: "openai/whisper-base",
        tokenizerRevision: "e37978b90ca9030d5170a5c07aadb050351a65bb",
        tokenizerDigests: [
            "tokenizer.json": "27fc476bfe7f17299480be2273fc0608e4d5a99aba2ab5dec5374b4482d1a566",
            "tokenizer_config.json": "2a4c4281cf9f51ac6ccc406fdc711a087afe6530f671fa7b80953edc498275ce",
        ]
    )

    /// Every model the app knows how to install, smallest first.
    public static let catalogue: [SpeechModel] = [base, small, largeV3Turbo]

    /// Looks a model up by repository identifier.
    public static func named(_ variant: String) -> SpeechModel? {
        catalogue.first { $0.variant == variant }
    }

    /// Whether this model can be trusted with a given language.
    public func supports(_ language: LanguageCode) -> Bool {
        isMultilingual || language == .english
    }
}
