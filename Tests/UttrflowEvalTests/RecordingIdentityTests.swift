// Tests the recording identity a baseline compares takes by.
import Foundation
import Testing

@testable import UttrflowEval

@Suite("Recording identity")
struct RecordingIdentityTests {
    @Test("digests identical bytes to the same identity")
    func sameBytesSameIdentity() {
        let audio = Data([1, 2, 3, 4, 5])
        #expect(RecordingIdentity.digest(of: audio) == RecordingIdentity.digest(of: audio))
    }

    @Test("digests different bytes to different identities")
    func differentBytesDifferentIdentity() {
        let a = RecordingIdentity.digest(of: Data([1, 2, 3]))
        let b = RecordingIdentity.digest(of: Data([1, 2, 4]))
        #expect(a != b)
    }

    @Test("prefixes a digest so it cannot be confused with a catalogue key")
    func digestIsPrefixed() {
        #expect(RecordingIdentity.digest(of: Data([9])).hasPrefix("sha256:"))
    }

    @Test("a catalogue sample's identity is its own key, prefixed the other way")
    func catalogueIdentity() {
        let identity = RecordingIdentity.forCatalogueSample(s3Key: "corpus/en/a.wav")
        #expect(identity == "s3:corpus/en/a.wav")
        #expect(identity != RecordingIdentity.digest(of: Data("corpus/en/a.wav".utf8)))
    }
}
