import XCTest
@testable import Skwad

final class TranscriptAccumulatorTests: XCTestCase {

    // MARK: - Basic operation

    func testInitialStateIsEmpty() {
        let acc = TranscriptAccumulator()
        XCTAssertEqual(acc.fullTranscript, "")
    }

    func testNormalPartialResults() {
        var acc = TranscriptAccumulator()
        acc.update(with: "hello")
        XCTAssertEqual(acc.fullTranscript, "hello")

        acc.update(with: "hello world")
        XCTAssertEqual(acc.fullTranscript, "hello world")

        acc.update(with: "hello world how are you")
        XCTAssertEqual(acc.fullTranscript, "hello world how are you")
    }

    // MARK: - Reset detection heuristic

    func testLooksLikeResetWithEmptyNewText() {
        XCTAssertTrue(TranscriptAccumulator.looksLikeReset(
            currentSegment: "this is a long enough segment",
            newText: ""
        ))
    }

    func testLooksLikeResetWithMuchShorterText() {
        XCTAssertTrue(TranscriptAccumulator.looksLikeReset(
            currentSegment: "this is a long enough segment of speech",
            newText: "hello"
        ))
    }

    func testDoesNotTriggerOnNormalGrowth() {
        // Partial results normally grow, never shrink significantly
        XCTAssertFalse(TranscriptAccumulator.looksLikeReset(
            currentSegment: "hello world how are you",
            newText: "hello world how are you doing"
        ))
    }

    func testDoesNotTriggerOnShortSegments() {
        // Short segments could just be partial result corrections
        XCTAssertFalse(TranscriptAccumulator.looksLikeReset(
            currentSegment: "short text",
            newText: "hi"
        ))
    }

    func testDoesNotTriggerOnMinorCorrections() {
        // Speech recognizer sometimes corrects slightly shorter
        let segment = "this is a sentence here"
        XCTAssertFalse(TranscriptAccumulator.looksLikeReset(
            currentSegment: segment,
            newText: "this is a sentence"
        ))
    }

    func testDoesNotTriggerOnEmptyCurrentSegment() {
        XCTAssertFalse(TranscriptAccumulator.looksLikeReset(
            currentSegment: "",
            newText: "hello"
        ))
    }

    // MARK: - Accumulation across resets

    func testSingleResetPreservesText() {
        var acc = TranscriptAccumulator()
        acc.update(with: "this is the first segment of speech")

        // Apple reset: sends much shorter text
        acc.update(with: "so")
        XCTAssertEqual(acc.fullTranscript, "this is the first segment of speech so")

        // New segment grows
        acc.update(with: "so now I am saying")
        XCTAssertEqual(acc.fullTranscript, "this is the first segment of speech so now I am saying")
    }

    func testResetWithEmptyResult() {
        var acc = TranscriptAccumulator()
        acc.update(with: "this is a fairly long segment")

        // Apple sends empty
        acc.update(with: "")
        XCTAssertEqual(acc.fullTranscript, "this is a fairly long segment")

        // New segment starts
        acc.update(with: "new stuff")
        XCTAssertEqual(acc.fullTranscript, "this is a fairly long segment new stuff")
    }

    func testMultipleResetsAccumulate() {
        var acc = TranscriptAccumulator()

        // First segment (long enough to trigger detection)
        acc.update(with: "this is the first segment of text")
        acc.update(with: "")  // reset

        // Second segment
        acc.update(with: "and this is the second segment")
        acc.update(with: "ok")  // reset (much shorter)

        // Third segment
        acc.update(with: "and finally the third one")

        XCTAssertEqual(
            acc.fullTranscript,
            "this is the first segment of text and this is the second segment and finally the third one"
        )
    }

    func testResetWithNoTextIsIgnored() {
        var acc = TranscriptAccumulator()
        acc.update(with: "")
        XCTAssertEqual(acc.fullTranscript, "")
    }

    func testConsecutiveResetsDoNotDuplicate() {
        var acc = TranscriptAccumulator()
        acc.update(with: "this is a long enough segment of speech")
        acc.update(with: "")  // first reset: saves segment
        acc.update(with: "")  // second reset: current is empty, no-op
        XCTAssertEqual(acc.fullTranscript, "this is a long enough segment of speech")
    }

    // MARK: - Reset

    func testResetClearsEverything() {
        var acc = TranscriptAccumulator()
        acc.update(with: "this is a fairly long sentence here")
        acc.update(with: "")  // apple reset
        acc.update(with: "more text")

        acc.reset()
        XCTAssertEqual(acc.fullTranscript, "")
        XCTAssertEqual(acc.accumulatedText, "")
        XCTAssertEqual(acc.currentSegmentText, "")
    }

    // MARK: - State visibility

    func testAccumulatedTextAndCurrentSegmentAreCorrect() {
        var acc = TranscriptAccumulator()
        acc.update(with: "this is the first long segment")
        XCTAssertEqual(acc.accumulatedText, "")
        XCTAssertEqual(acc.currentSegmentText, "this is the first long segment")

        acc.update(with: "")  // reset
        XCTAssertEqual(acc.accumulatedText, "this is the first long segment")
        XCTAssertEqual(acc.currentSegmentText, "")

        acc.update(with: "seg2")
        XCTAssertEqual(acc.accumulatedText, "this is the first long segment")
        XCTAssertEqual(acc.currentSegmentText, "seg2")
    }
}
