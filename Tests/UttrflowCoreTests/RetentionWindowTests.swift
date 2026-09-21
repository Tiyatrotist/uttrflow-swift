// Tests for RetentionWindow: the window itself, a stamp ahead of the clock, and what a clock may delete.

import Foundation
import Testing

@testable import UttrflowCore

/// The rule three stores share, and the two things it refuses to take the wall clock's word for.
@Suite("Retention, against a clock that may be wrong")
struct RetentionWindowTests {
    /// A fixed instant, so no test reads the real clock.
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// A seven-day window measured from ``now``.
    static let week = RetentionWindow(days: 7, now: now)

    private static func daysFromNow(_ days: Double) -> Date {
        now.addingTimeInterval(days * 86_400)
    }

    // MARK: The window

    @Test("a record younger than the window is kept, and one older is not")
    func theWindowItself() {
        #expect(Self.week.keeps(Self.daysFromNow(-1)))
        #expect(Self.week.keeps(Self.daysFromNow(-6.99)))
        #expect(!Self.week.keeps(Self.daysFromNow(-7.01)))
        #expect(!Self.week.keeps(Self.daysFromNow(-30)))
    }

    @Test("a window of nothing keeps nothing, including a record made this instant")
    func aWindowOfNothing() {
        let none = RetentionWindow(days: 0, now: Self.now)
        #expect(!none.keeps(Self.now))
        #expect(!RetentionWindow(days: -3, now: Self.now).keeps(Self.now))
    }

    @Test("a window shorter than a day is measured in the same arithmetic")
    func aWindowOfHours() {
        let day = RetentionWindow(span: 24 * 60 * 60, now: Self.now)
        #expect(day.keeps(Self.daysFromNow(-0.9)))
        #expect(!day.keeps(Self.daysFromNow(-1.1)))
    }

    // MARK: A stamp ahead of the clock

    /// The promise is a maximum. A stamp whose age cannot be known has to resolve to the shorter life.
    @Test("a stamp a year ahead of the clock is past its window, not kept for a year")
    func aStampAheadIsDue() {
        #expect(!Self.week.keeps(Self.daysFromNow(365)))
        #expect(!Self.week.keeps(Self.daysFromNow(1)))
    }

    @Test("a stamp inside the skew allowance is taken at face value")
    func aStampInsideTheAllowance() {
        #expect(Self.week.keeps(Self.now.addingTimeInterval(RetentionWindow.clockSkewAllowance - 1)))
        #expect(!Self.week.keeps(Self.now.addingTimeInterval(RetentionWindow.clockSkewAllowance + 1)))
    }

    // MARK: What the clock may delete

    @Test("a clock within a believable idleness of the record may delete it")
    func aBelievableClockMayDelete() {
        #expect(Self.week.mayDelete(Self.daysFromNow(-1)))
        #expect(Self.week.mayDelete(Self.daysFromNow(-30)))
        #expect(Self.week.mayDelete(Self.daysFromNow(-364)))
    }

    /// The irreversible half: one reading of a clock that jumped must not empty a store.
    @Test("a clock further ahead of the record than the app can have idled may not delete it")
    func aJumpedClockMayNotDelete() {
        #expect(!Self.week.mayDelete(Self.daysFromNow(-366)))
        #expect(!Self.week.mayDelete(Self.daysFromNow(-10_000)))
    }

    /// A stamp ahead of the clock is deletable: it is due, and refusing would keep it for ever.
    @Test("a stamp ahead of the clock may be deleted")
    func aStampAheadMayBeDeleted() {
        #expect(Self.week.mayDelete(Self.daysFromNow(365)))
    }

    // MARK: The sweepable range, for a stamp that lives in a file name

    @Test("the sweepable range runs from the oldest believable stamp up to the window")
    func theSweepableRange() {
        let range = Self.week.sweepable
        #expect(range.upperBound == Self.daysFromNow(-7))
        #expect(range.lowerBound == Self.daysFromNow(-365))
        #expect(range.contains(Self.daysFromNow(-30)))
        #expect(!range.contains(Self.daysFromNow(-1)))
        #expect(!range.contains(Self.daysFromNow(-400)))
    }

    @Test("a window of nothing makes every believable stamp sweepable, this instant's included")
    func theSweepableRangeOfNothing() {
        let range = RetentionWindow(days: 0, now: Self.now).sweepable
        #expect(range.contains(Self.now))
        #expect(range.contains(Self.daysFromNow(-30)))
        #expect(!range.contains(Self.daysFromNow(-400)))
    }

    /// `Range` traps on a reversed bound, and a window longer than a year is a real setting.
    @Test("a window longer than a believable idleness has an empty sweepable range rather than a trap")
    func aWindowLongerThanBelief() {
        let decade = RetentionWindow(days: 3_650, now: Self.now)
        #expect(decade.sweepable.isEmpty)
    }
}
