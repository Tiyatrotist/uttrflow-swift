# Code quality

Readability, maintainability and design quality outrank speed of delivery. The principles below
are non-negotiable on every change, without exception: **single source of truth (DRY), SOLID,
KISS, YAGNI, design patterns where they remove duplication or branching, and modular low-level
design.** Every rule has a measure, a limit and the way it is checked. "Pass" means the command
exits 0; a rule with no command is checked in review with the measure shown.

## Gated limits

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
| Pasteboard access outside the clipboard adapters | count | 0 | `make pasteboard-audit` |
| Local-store writes outside `PrivateFile` | count | 0 | `make store-permissions` |
| Typed text in log messages | count | 0 | `make log-audit` |
| `swiftlint:disable` and `swift-format-ignore` markers | count | 0 | `grep -rE 'swiftlint:disable\|swift-format-ignore' Sources Tests` prints nothing |
| Remote scripts piped into a shell | count | 0 | `grep -rE 'curl[^\|]*\|[[:space:]]*(ba)?sh' Scripts .github Makefile` prints nothing |
| Files named `*_v2`, `*_new`, `*_old` or `* copy` | count | 0 | `git ls-files \| grep -c -E '_v2\|_new\.\|_old\.\| copy'` prints 0 |
| Cleanup change, corpus score after versus before | each metric | no drop without the metric named and justified in the PR | `make bakeoff` |

## Design limits for code you add or touch

Checked in review with the measure shown. A function or file that is already over a limit does not
grow when you touch it: extract first, then add. Today 134 of 4,861 functions exceed 40 lines and
48 of 713 files exceed 400 lines, so the limits describe the code being written, not a rewrite.

| Rule | Limit | Measure |
|---|---|---|
| Function length | at most 40 lines | read the diff; `git diff -U0 origin/main` hunks inside one `func` |
| File length | at most 400 lines; a file over 1,000 lines gets 0 new members | `git diff --name-only origin/main -- '*.swift' \| xargs wc -l \| sort -n \| tail` |
| Nesting depth | at most 3 levels; use early returns | read the diff |
| Parameters per function | at most 5; more means a value type | read the signature |
| Primary types per file | 1, plus its extensions and private helpers | read the file |
| Requirements per protocol | at most 5 | read the protocol |
| Access level | `internal` by default; `public` only for a cross-module API | `grep -n '^public\|^    public' <file>` |
| Duplicated code | 0 blocks of 3 or more identical lines; 0 literal collections with the same members in 2 places | search before adding (below) |
| Commented-out code, new | 0 | `git diff origin/main \| grep -E '^\+\s*//\s*(let\|var\|func\|if\|for\|return\|guard)\b'` prints nothing |
| UI frameworks in logic modules | 0 imports of `AppKit`, `ApplicationServices`, `SwiftUI` or `Cocoa` outside the platform modules | see "Modules" |
| Modules a behaviour change edits | at most 3; more means the seam is wrong, so say why in the PR | `git diff --stat origin/main` |
| Unused declarations added | 0; delete code in the commit that stops using it | search for the name |

## Single source of truth (DRY) — non-negotiable

Every fact, rule, threshold, table, string, path and key has exactly one home. Everything else
reads it from there; nothing copies it.

1. **Search before you write.** Run `git grep` and, for work in progress, `git grep --untracked`
   for the concept name and for the literal values. A match means reuse it. A near-match means
   extract the shared seam in the same pull request, then use it.
2. **The decision question.** If one of two things changes, must the other? Yes means one owner
   and one reader. No means two different facts that happen to look alike; leave them apart.
3. **A caller asks the owner; it never re-derives.** Derived values, caches and projections come
   from the owner with an explicit invalidation point.
4. **Numbers and thresholds live in one named constant or configuration type**, never inline in
   two places, and their reasons live on the `Docs/` page that measured them.
5. **Settings.** A setting is one stored value. A second flag for the same question is a bug.

The owners that exist today. Use them; do not reimplement them.

| Question | Single owner | Held by |
|---|---|---|
| Are two spellings one word? | `MeaningPreservationGuard.sameForm` | `make match-audit` |
| Is a word written out at its own boundaries? | `spelledInto`, `isWritten` | `make match-audit` |
| Is a word still there, in the order spoken? | `WordErrorRate.measure` | `make match-audit` |
| Does text use a non-Latin script? | `LatinScript.writes` | tests, `Docs/latin-output.md` |
| What is the current line? | `FocusedFieldSnapshot.currentLine` | tests, `Docs/predict.md` |
| Which application is a terminal? | `TerminalApplications` | tests, `Docs/predict.md` |
| How much memory may the clipboard use? | `ClipboardBudget.standard` | `Docs/clipboard-budget.md` |
| Who touches the pasteboard? | the clipboard adapters | `make pasteboard-audit` |
| Who writes a local store's files? | `PrivateFile` | `make store-permissions` |
| Who may use the network? | `UttrflowAccount`, plus the listed exceptions | `make offline-audit` |
| Is suggestions mode on? | `suggestions.isEnabled` in the settings blob | `Docs/predict.md` |

## SOLID, each with a test you can run

1. **Single responsibility.** A type has one reason to change. Its doc comment is one sentence
   with no "and". A file with 2 or more unrelated primary types is split.
2. **Open for extension, closed for modification.** The next case of the same kind is a data
   entry, a configuration row or a new conformance, plus one test. If adding it edits an existing
   `switch` or `if` chain in 2 or more files, replace the chain with one exhaustive `switch` in
   one place, or with a protocol.
3. **Liskov substitution.** Every conformer passes the same protocol-level test suite. A new
   `as?` downcast on a protocol value in production code is 0; add the missing requirement
   instead.
4. **Interface segregation.** A protocol has at most 5 requirements and names one capability
   (`WordCorrecting`, `SnippetExpanding`). A client depends on the requirements it calls and no
   more; split a protocol when two clients use disjoint halves.
5. **Dependency inversion.** Logic depends on a protocol declared in its own pure module; the
   system API (Accessibility, the pasteboard, the Keychain, the network, the clock, the file
   system) sits behind an adapter and is injected. The engine is tested against values in an
   array, not a database.

## KISS and YAGNI

1. Build the smallest design that passes the check you wrote first. A simpler design that
   passes is the one you ship.
2. A protocol, generic, option, parameter or configuration key has at least 2 uses, or 1 use plus
   a test double that needs the seam. Otherwise delete it.
3. Do not build for a case no caller has. Make the next case cheap (an extension point) only
   when 2 cases of the same kind already exist.
4. Prefer a value type and a pure function to a class with state. Shared mutable state lives in
   an actor, or behind one owner.

## Design patterns

Choose a pattern only when it removes a measured duplication or a branch chain of 3 or more
cases on the same discriminator in 2 or more places. Do not name a pattern in the code; the type
and its doc comment say what it does.

| Need | Pattern | Where it already exists |
|---|---|---|
| Keep logic independent of a system API | port and adapter | `PredictionStore`, `ClipboardSource`, `KeyValueStore` |
| Swap an engine without touching callers | strategy | `TransformerKind`, `CandidateScoring`, `CandidateGenerating` |
| Several ordered, independently testable steps | pipeline of passes | the cleanup passes in `Docs/cleanup-design.md` |
| Never lose the user's words when a step fails | fallback chain | `FallbackRunner` |
| Sequence several collaborators once per event | coordinator and session | `SuggestionCoordinator`, `SuggestionSession` |
| A closed set of situations with different behaviour | enum with one exhaustive `switch` | `DictationState` |
| Local persistence behind one seam | store actor | `ClipboardStore`, `SnippetStore` |
| Keep presentation out of the view | presentation model in a value type | the modules under `UttrflowUX` |

Do not add: global mutable state or a new singleton (inject the dependency), a god object (a type
that other types need to know the internals of), inheritance to share code (compose), or a
wrapper that only renames.

## Modules (low-level design)

The module graph has one direction: pure logic, then platform adapters, then the app shell.
Dependencies are declared in `Package.swift`; a cycle fails the build.

| Layer | Modules | UI-framework imports |
|---|---|---|
| App shell and platform adapters | `Uttrflow`, `UttrflowClipboard`, `UttrflowContext`, `UttrflowInput`, `UttrflowPermissions`, `uttrflow-dev` | allowed |
| Everything else | logic, stores, models, presentation, evaluation | 0 |

```bash
grep -rlE '^import (AppKit|ApplicationServices|SwiftUI|Cocoa)' Sources/UttrflowCore Sources/UttrflowAI Sources/UttrflowPredict
```

prints nothing, and the same holds for every module in the second row.

A change that adds a module states, in the pull request: the module's one-sentence
responsibility, the modules it depends on and why none points the wrong way, its public surface in
at most 10 declarations, its test target, and its page in `Docs/README.md`. The module meets the
95% coverage floor from its first commit.

A non-trivial change writes its design in the pull request before the diff: the responsibilities
of each type in one sentence each, the direction of every new dependency, the test seams.

## Readability and maintainability

1. **Names state intent.** Full words; no abbreviations except established ones (`URL`, `ID`).
   Types are nouns, functions are verbs, booleans read as assertions (`isEmpty`, `hasFocus`).
   A name that needs a comment to explain it is renamed.
2. **A literal that carries meaning is a named constant at its single owner.**
3. **Errors are explicit.** A failure is typed and handled or propagated. A new `try?` carries a
   one-line reason for discarding the error, and ends in an unchanged user-visible state.
4. **Concurrency is declared.** Shared mutable state is an actor or has one owner; strict
   concurrency stays on.
5. **The next case of the same kind** edits 1 data or configuration location and adds 1 test. If
   it edits more, the design has a branch where it needs a table.
6. **Docs move with behaviour.** A measurement, platform trap or rejected approach goes on a
   `Docs/` page in the same pull request.

## Fixing a defect

Answer in the pull request, in this order, before the diff is read:

1. **Why does the defect exist?** Name the code that is wrong, not the symptom.
2. **Why was it not caught?** Name the missing test, audit or measurement, and add it. The new
   test fails on the original code and passes on the fix; show both runs.
3. **What class of input does the fix cover?** If the answer is one phrase, one app, one fixture
   or one reported sentence, the fix is a special case and is rejected.
4. **Why can it not recur?** Name the test or audit that now fails if it does.

A rule that cannot be stated for the whole class of input means the design is wrong: reshape the
code into a clean seam first, then fix.

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
   `- Parameter` on a function with several, and a plural block is multi-line, so a function with
   several parameters documents all of them or none; say what is surprising in the summary line.
5. A measurement, platform trap or rejected approach goes on a `Docs/` page under a heading, and
   the comment links to it.

```bash
python3 Scripts/comment_audit.py --report                 # what is left, worst first
python3 Scripts/comment_audit.py --update                 # record a fall after improving a file
python3 Scripts/comment_audit.py --update --after-merge   # only when main moved under you
```

`--update` refuses a rise. `--after-merge` records the rises that rebasing onto `main` brings in
from files the rule has not reached; it prints each one into the baseline diff for review. Never
use it for your own comments.

## Spelling and meaning

Never decide that two spellings are one word by shape: not a prefix of *n* characters, not "one
contains the other". Ask the owners in the table above. A shape match fails in one direction: it
says "same" too easily, on paths whose failure is acceptance, so no test goes red. A
three-character stem equates "confirm" with "confuse" and "Aarav" with "Aaron".

```bash
make match-report                                            # what is left, with the line
python3 Scripts/loose_match_audit.py --update                # record a fall
python3 Scripts/loose_match_audit.py --update --after-merge  # only when main moved under you
```

A baselined match is legitimate when the shape is the question rather than a stand-in for one;
`CaretEchoPass` asks which completion targets begin with what the user typed. The author says why
a given match is right.

## Tests and coverage

1. A test asserts behaviour a user or caller depends on, never code structure, and its name is a
   sentence. It fails only when our code changes.
2. A test asserts exact values and counts, never a bound ("more than 0") or the mere absence of
   an error. It never asserts a value the test itself just set and stored.
3. A test that executes lines without asserting behaviour is worse than the exclusion it hides.
4. An exclusion lives in `Scripts/coverage_report.py` with a stated reason, printed on every
   run. Adding tests until the exclusion can go is the way out.
5. A change to recognition, correction or cleanup runs `make bakeoff` and records the score
   before and after.
6. A change to insertion, input or context reading is run once in a real target app, and the PR
   names the app and the result.
7. Probe the real API before coding. A command-line tool is not a representative test bed for the
   Accessibility API; `Docs/` and `Sources/UttrflowInput/` carry the traps.

## Protected files

Change one only when the task is about it, and say so in the PR.

| File | Rule |
|---|---|
| `Package.swift`, `Package.resolved` | a dependency change needs maintainer approval |
| `.github/workflows/`, `.githooks/` | a change needs maintainer approval |
| `Scripts/*_baseline.json` | written only by the script's `--update`; never by hand |
| `Scripts/disclosure_audit.py` | never loosened |
| `Resources/Uttrflow-Info.plist` version fields | released by a maintainer |
| `Design/*.dc.html` artboards | regenerated from `Design/_gen_*.py`; edit the generator |

## Dependencies and workflows

Adding a package dependency or a file in `.github/workflows/` needs explicit approval from a
maintainer. Workflows today: CI, CodeQL (weekly), dependency review, Oracle sweep, Quality,
Release, Scorecard and Security. The project builds against macOS frameworks, so it runs on
macOS runners only.
