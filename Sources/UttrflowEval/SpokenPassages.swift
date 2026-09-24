public import Foundation
private import UttrflowAudio
public import UttrflowCore

/// Turns the profile's passages into repeatable audio. See `Docs/bakeoff-method.md`.
public struct SpokenPassages: Sendable {
    public struct Spoken: Sendable {
        public let passage: ProfilePassage
        public let samples: AudioSamples
    }

    public enum Failure: Error, CustomStringConvertible, Sendable {
        case synthesisFailed(String)
        case audioUnreadable(String)

        public var description: String {
            switch self {
            case .synthesisFailed(let detail): "could not synthesise speech: \(detail)"
            case .audioUnreadable(let detail): "could not read synthesised audio: \(detail)"
            }
        }
    }

    public let directory: URL
    public let voice: String
    public var catalogue: any VoiceCatalogue
    public var synthesizer: any VoiceSynthesizer

    public init(
        directory: URL, voice: String,
        catalogue: any VoiceCatalogue = SayVoiceCatalogue(),
        synthesizer: any VoiceSynthesizer = SaySynthesizer()
    ) {
        self.directory = directory
        self.voice = voice
        self.catalogue = catalogue
        self.synthesizer = synthesizer
    }

    /// Re-speaks any passage whose text or resolved voice has changed, then reads it all in.
    public func prepare(
        _ passages: [ProfilePassage]
    ) throws(Failure) -> (
        spoken: [Spoken], voice: ResolvedVoice
    ) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
        } catch {
            throw .synthesisFailed(error.localizedDescription)
        }

        let resolved = resolveVoice(requested: voice, catalogue: catalogue)

        var spoken: [Spoken] = []
        for passage in passages {
            let audio = directory.appending(path: "\(passage.id).wav")
            let stamp = directory.appending(path: "\(passage.id).spoken")
            let wanted = "\(resolved.label)\n\(passage.text)"

            if (try? String(contentsOf: stamp, encoding: .utf8)) != wanted
                || !FileManager.default.fileExists(atPath: audio.path)
            {
                guard synthesizer.speak(passage.text, voice: resolved.installed, to: audio) else {
                    throw .synthesisFailed("`say` failed for \(audio.lastPathComponent)")
                }
                try? wanted.write(to: stamp, atomically: true, encoding: .utf8)
            }

            do {
                spoken.append(
                    Spoken(passage: passage, samples: try AudioFileReader.read(contentsOf: audio)))
            } catch {
                throw .audioUnreadable("\(passage.id): \(error)")
            }
        }
        return (spoken, resolved)
    }
}
