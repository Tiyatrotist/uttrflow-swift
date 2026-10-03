# Code quality

Every rule has a measure, a limit and the command that checks it. "Pass" means the command
exits 0. A rule with no command says how to check it by hand.

## Limits

| Rule | Measure | Limit | Check |
|---|---|---|---|
| Comment length | lines in one `//` or `///` block | 1 | `make comment-audit` |
| Multi-line comment blocks per file | count | never above `Scripts/comment_baseline.json` | `make comment-audit` |
| Line coverage per module | percent | at least 95 | `make coverage` |
| Coverage exclusion size | lines per excluded file | at most 400, unless listed in `OVERSIZED_EXCLUSIONS` | `make exclusion-audit` |
| Spelling matches decided by shape, per file | count | never above `Scripts/loose_match_baseline.json` | `make match-audit` |
| Force unwraps, `try!`, implicitly unwrapped optionals | count | 0 | `make lint` |
| Compiler warnings | count | 0 | `make build` |
| Swift language mode | version | 6, strict concurrency | `make build` |
| Real email or postal addresses in fixtures | count | 0 | `make pii-audit` |
| Connections opened on the dictation path | count | 0 | `make offline-audit` |
| Implementations of one capability | count | 1 | review; a second is deleted in the same pull request |
| Devanagari characters or translated text inserted | count | 0 | tests per `Docs/latin-output.md` |
| Cleanup change, corpus score after versus before | each corpus metric | no drop without the metric named and justified in the PR | `make bakeoff` |

## Fixing a defect

Answer these in the pull request, in this order, before the diff is read:

1. **Why does the defect exist?** Name the code that is wrong, not the symptom.
2. **Why was it not caught?** Name the missing test, audit or measurement, and add it.
3. **What class of input does the fix cover?** If the answer is one phrase, one app, one
   fixture or one reported sentence, the fix is a special case and is rejected.
4. **Why can it not recur?** Name the test or audit that now fails if it does.

A rule that cannot be stated for the whole class of input means the design is wrong: reshape
the code into a clean seam first (SOLID, DRY, nothing built that no caller needs), then fix.
Make the next case of the same kind a data or configuration change, not another branch.

## Comments

A comment is one line and says what the code does now.

```swift
/// Judges the audio before it is decoded. See `Docs/silence.md`.
```

1. One line per block. A trailing comment on a line of code is exempt from the length limit.
2. Present tense, about the present code: what it does, what the value means.
3. A reason is allowed only if it changes what a reader would do. "Kept under the lock because
   `deinit` can run on any thread" qualifies; a story about what was tried does not.
4. Document a parameter only where one line covers it. `swift-format` rejects a singular
   `- Parameter` on a function with several, and a plural block is multi-line, so a function
   with several parameters documents all of them or none; say what is surprising in the
   summary line.
5. A measurement, platform trap or rejected approach goes on a `Docs/` page under a heading,
   and the comment links to it.

### Baseline commands

```bash
python3 Scripts/comment_audit.py --report                 # what is left, worst first
python3 Scripts/comment_audit.py --update                 # record a fall after improving a file
python3 Scripts/comment_audit.py --update --after-merge   # only when main moved under you
```

`--update` refuses a rise. `--after-merge` records the rises that rebasing onto `main` brings
in from files the rule has not reached; it prints each one into the baseline diff for review.
Never use it for your own comments.

## Spelling and meaning

Never decide that two spellings are one word by shape: not a prefix of *n* characters, not
"one contains the other".

| Question | Single owner |
|---|---|
| Are two spellings one word? | `MeaningPreservationGuard.sameForm` |
| Is a word written out at its own boundaries? | `spelledInto`, `isWritten` |
| Is a word still there, in the order it was said? | `WordErrorRate.measure` |

A shape match fails in one direction: it says "same" too easily, on paths whose failure is
acceptance, so no test goes red. A three-character stem equates "confirm" with "confuse" and
"Aarav" with "Aaron".

```bash
make match-report                                            # what is left, with the line
python3 Scripts/loose_match_audit.py --update                # record a fall
python3 Scripts/loose_match_audit.py --update --after-merge  # only when main moved under you
```

A baselined match is legitimate when the shape is the question rather than a stand-in for one;
`CaretEchoPass` asks which completion targets begin with what the user typed. The author says
why a given match is right.

## Tests and coverage

1. A test asserts behaviour a user or caller depends on, and its name is a sentence.
2. A test that executes lines without asserting behaviour is worse than the exclusion it hides.
3. An exclusion lives in `Scripts/coverage_report.py` with a stated reason, printed on every
   run. Adding tests until the exclusion can go is the way out.
4. A change to recognition, correction or cleanup runs `make bakeoff` and records the score
   before and after.
5. Probe the real API before coding. A command-line tool is not a representative test bed for
   the Accessibility API; `Docs/` and `Sources/UttrflowInput/` carry the traps.

## Dependencies and workflows

Adding a package dependency or a file in `.github/workflows/` needs explicit approval from a
maintainer. Workflows today: CI, CodeQL (weekly), dependency review, Oracle sweep, Quality,
Release, Scorecard and Security. The project builds against macOS frameworks, so it runs on
macOS runners only.
