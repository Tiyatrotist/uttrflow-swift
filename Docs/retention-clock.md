# Retention, against a clock that may be wrong

Three stores promise that something is deleted after a window: the dictation history
(`Retention`, the user's setting), the clipboard (`ClipRetention`, a window per pool) and the
recordings kept for a retry (a fixed 24 hours). All three used to decide it with the same
arithmetic on `Date()`:

```swift
stamp.addingTimeInterval(window) > now
```

That takes the wall clock's word for two separate things, and it is wrong about both. A Mac's
clock is not a monotonic count of elapsed time: it is set by hand, restored from a dead
battery reading 1970, stepped by the network after a late boot, and moved by whoever is
testing something else. `RetentionWindow` is the one place both answers now live, and the two
stores that hold records and the one that reads file dates all ask it.

## A stamp ahead of the clock is due, not young

The arithmetic above has no floor on the age it computes. A record stamped a year ahead —
dictated while the clock was wrong, and read after the clock was put right — has a negative
age, passes the test for a year, and outlives a window the user was told was seven days. A
clip can hold a password; that is the promise not kept, quietly, for as long as the clock was
out by.

`RetentionWindow.keeps(_:)` answers `false` for a stamp more than
`clockSkewAllowance` (five minutes) ahead of `now`. A record whose stamp is in the future has
no knowable age: the only thing it establishes is that the clock was wrong when it was
written. "Deleted after N days" is a **maximum**, so the unknowable case has to resolve to the
shorter life, not to however long the clock happened to be out by.

Two alternatives were rejected. Reading the stamp as `now` instead — the obvious clamp — does
not bound anything: the record is then kept for a fresh window at *every* read, so it still
survives until real time catches up with the stamp. Rewriting the stored stamp bounds it, but
a retention pass has no business editing the user's record of when they spoke.

The five-minute allowance is there because a clock nudged backwards by a second is not a wrong
clock, and a dictation must not expire the instant it is made. It is far beyond any network
step and far below any window, so nothing measurable turns on the exact figure.

## A clock that jumped forward is not believed to delete

The other direction is worse, because it is not recoverable. One read while the clock is wrong
deletes everything older than the window from the disk, and when the clock comes back the
history is gone. The read did not intend to be destructive — it is a window being drawn — and
the cause was outside the app entirely.

There is no way to tell a clock that jumped forward from time that really passed. Nothing in
the stamps distinguishes them, and neither does the file's own modification date: both are
written by the same clock. Across a reboot with a flat battery there is not even a monotonic
count to appeal to. So the guard is not detection but a refusal:
`RetentionWindow.mayDelete(_:)` answers `false` once `now` claims to be more than
`longestBelievableIdle` — a year — ahead of the record.

A year is a judgement, and it is the asymmetry of the two mistakes that picks it. Refusing to
delete something the window really has passed costs the next sweep, and the record is hidden
from the user meanwhile, because `keeps(_:)` and `mayDelete(_:)` are separate questions and
only the second one is refused. Deleting something the window has *not* passed cannot be
taken back. A year of not dictating is not a state this app is in; a clock a year out is one
it meets.

`sweepable` says the same thing as a range, for a stamp that lives in a file name rather than
in a record — `LocalStore.removeSetAside(_:stamped:)` and the copy set aside from an
unreadable store.

## What this does not fix

A clock that is wrong by *less* than a year, at the moment of a read or a write, still prunes.
So does a clock that jumped forward and then had a record written under it, because the newest
stamp then agrees with the clock and there is nothing left to disagree with. Closing that
needs a time source the app can trust — a persisted high-water mark checked against a
monotonic clock, or the network — which is a larger design than the window, and none of the
three stores has one today.

## Where the two answers are asked

The stores keep two lists rather than one: what the caller may be **shown**, and what may stay
on the **disk**. They differ only for a record the window has passed on a clock too far ahead
of it to be believed — hidden, and still there. `DictationHistoryStore.retained(_:keeping:)`
and `keptOnDisk(_:keeping:)` are that pair, `ClipboardStore` has the same two over its pool
caps and quotas, and `RecordingStore.waiting(now:)` makes the same split between the list it
returns and the files it deletes. Every write goes through the disk answer too: appending a
dictation is no better informed about the time than reading one.
