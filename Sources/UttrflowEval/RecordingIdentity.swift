// A stable identity for the exact audio a passage was scored from.
public import Foundation
private import CryptoKit

/// Identifies the exact recording a score rests on, so a baseline can tell a replacement take from the
/// one it captured. See Docs/eval-methodology.md.
public enum RecordingIdentity {
    /// A digest of `audio`'s bytes, prefixed so it is never confused with ``forCatalogueSample(s3Key:)``.
    public static func digest(of audio: Data) -> String {
        "sha256:" + SHA256.hash(data: audio).map { String(format: "%02x", $0) }.joined()
    }

    /// The catalogue's own key for a sample's object, which is as stable as a content digest without
    /// requiring the harness to hold the bytes.
    public static func forCatalogueSample(s3Key: String) -> String {
        "s3:\(s3Key)"
    }
}
