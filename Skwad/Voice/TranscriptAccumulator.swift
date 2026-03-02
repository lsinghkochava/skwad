import Foundation

/// Accumulates speech recognition transcript segments across Apple recognition resets.
///
/// Apple's SFSpeechRecognizer silently resets after ~1 minute of continuous dictation,
/// sending a result that is much shorter than what was accumulated. This struct detects
/// resets (new text significantly shorter than current segment) and preserves previous segments.
struct TranscriptAccumulator {
    /// Combined text from all previous recognition segments
    private(set) var accumulatedText = ""
    /// Text from the current active recognition segment
    private(set) var currentSegmentText = ""

    /// Minimum character count in current segment before reset detection kicks in
    static let minimumLengthForResetDetection = 20

    /// The full transcript combining all segments
    var fullTranscript: String {
        switch (accumulatedText.isEmpty, currentSegmentText.isEmpty) {
        case (true, _): return currentSegmentText
        case (_, true): return accumulatedText
        case (false, false): return accumulatedText + " " + currentSegmentText
        }
    }

    /// Detect if a new result looks like an Apple recognition reset.
    /// Returns true when we had substantial text and the new result is
    /// drastically shorter (less than half), meaning Apple restarted.
    static func looksLikeReset(currentSegment: String, newText: String) -> Bool {
        guard currentSegment.count >= minimumLengthForResetDetection else { return false }
        return newText.count < currentSegment.count / 2
    }

    /// Process a new recognition result. Detects resets and preserves text.
    mutating func update(with newText: String) {
        if Self.looksLikeReset(currentSegment: currentSegmentText, newText: newText) {
            // Apple reset: save current segment before it's lost
            if accumulatedText.isEmpty {
                accumulatedText = currentSegmentText
            } else {
                accumulatedText += " " + currentSegmentText
            }
            currentSegmentText = newText
        } else {
            currentSegmentText = newText
        }
    }

    /// Reset all state (call when starting a new listening session)
    mutating func reset() {
        accumulatedText = ""
        currentSegmentText = ""
    }
}
