// The speech models the app can install.
public import UttrflowCore

/// A speech-recognition model the app can install; sizes are the real download, shown before the wait.
public struct SpeechModel: Sendable, Hashable, Codable {
    /// Identifier used by the model repository.
    public let variant: String
    /// Total bytes fetched when installing.
    public let downloadBytes: Int64
    /// Whether it recognises languages other than English.
    public let isMultilingual: Bool
    /// The repository publishing the tokenizer, which is OpenAI's while the weights are a CoreML build.
    public let tokenizerRepository: String
    /// The commit the tokenizer is fetched at, so an install a year from now is the install measured here.
    public let tokenizerRevision: String
    /// What each tokenizer file must hash to at that commit, since a pinned name is not a pinned file.
    public let tokenizerDigests: [String: String]

    public init(
        variant: String, downloadBytes: Int64, isMultilingual: Bool, tokenizerRepository: String,
        tokenizerRevision: String, tokenizerDigests: [String: String]
    ) {
        self.variant = variant
        self.downloadBytes = downloadBytes
        self.isMultilingual = isMultilingual
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
