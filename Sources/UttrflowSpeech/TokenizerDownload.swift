// Fetches a model's tokenizer at install time, the module's only network call.
internal import Foundation
internal import UttrflowCore
private import CryptoKit

// The one file in UttrflowSpeech allowed to open a connection; Scripts/offline_audit.sh names it.

/// Fetches a model's tokenizer at install time, so WhisperKit never reaches for one while decoding.
func downloadTokenizer(for model: SpeechModel, into destination: URL) async throws {
    for name in TokenizerAssets.fileNames {
        guard
            let url = URL(
                string:
                    "https://huggingface.co/\(model.tokenizerRepository)/resolve/\(model.tokenizerRevision)/\(name)"
            )
        else {
            throw TokenizerFetchFailure(reason: "\(model.tokenizerRepository) is not an address")
        }

        // No token and no endpoint of anybody's choosing: this fetches a public file and says who nobody is.
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw TokenizerFetchFailure(
                reason: "\(model.tokenizerRepository) answered \(status) for \(name)")
        }

        // A pinned commit says which file to fetch; only the digest says it is the file that was pinned.
        guard let expected = model.tokenizerDigests[name] else {
            throw TokenizerFetchFailure(reason: "\(name) has no recorded digest to check against")
        }
        let found = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard found == expected else {
            throw TokenizerFetchFailure(
                reason: "\(name) from \(model.tokenizerRepository) hashed \(found), not \(expected)")
        }

        // Atomic, so a dropped connection cannot leave a truncated file that passes as a tokenizer.
        try PrivateFile.write(data, to: destination.appending(path: name))
    }
}

/// Why a tokenizer could not be fetched; a sentence for the log, since nothing branches on it.
struct TokenizerFetchFailure: LocalizedError {
    let reason: String
    var errorDescription: String? { reason }
}
