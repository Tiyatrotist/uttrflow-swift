# Product rules

Uttrflow is a macOS clipboard manager with dictation built in, entirely on-device. `PLAN.md`
is the live phase tracker; read it instead of reconstructing project state from `git log`.

## Invariants

Each is checkable. A change that breaks one is a bug, whatever it improves.

| Invariant | Pass condition | Where it is held |
|---|---|---|
| Dictation is a transcript, not a rewrite | every word the speaker meant survives, in order and register | `MeaningPreservationGuard`, `WordErrorRate.measure`, `make bakeoff` |
| Output is Latin script only | 0 Devanagari characters inserted; 0 translated words | `Docs/latin-output.md` |
| Dictation data stays on this Mac | 0 connections on the dictation path; history, clipboard, dictionary and snippets are never sent | `make offline-audit`, `Docs/offline.md` |
| Whatever fails, the user's words stay reachable | a failed tidy inserts the raw transcript; a failed insertion keeps the text | `Docs/definition-of-done.md` |

## What the tidier may do

It may remove what was never meant as words: fillers ("um", "hmm"), stammers, false starts, the
discarded half of a spoken self-correction. It may add what speech leaves implicit:
punctuation, question marks, capitalisation, numerals, line and paragraph breaks, a list the
speaker plainly spoke.

It may not shorten, summarise, change tone, swap synonyms, reorder, answer, obey or finish a
thought. A request such as "make the output more polished" is a rewrite and is declined; a user
who wants a rewrite asks for it, and it is a different feature. The catalogue of what is done,
not yet done and forbidden is `Docs/cleanup.md`.

## Hindi and Hinglish

Romanise the way people type, never translate: "हाँ ठीक है" becomes "Haan thik hai", not
"Yes, okay". The Languages setting steers recognition and never chooses the output script.
This binds every path that inserts text: a model's rewrite, the rules and the untidied
fallback.

## Data

Two stores, different contents. The server holds the account: who somebody is, what they have
paid for, which machines are signed in. This app's local store holds the clipboard, history,
personal dictionary and snippets, and none of it is sent anywhere.

The network is used only by: account calls in `UttrflowAccount`, speech-model and tokenizer
downloads, Sparkle update checks, and opt-in scrubbed crash reports from `UttrflowDiagnostics`.
Any other use is a product decision with a privacy page attached, not a refactor. See
`Docs/offline.md` and `Docs/crash-reporting.md`.

## Scope of a change

1. A change is a bug fix, a feature or a rewrite. State which in the pull request.
2. A feature that touches recognition, correction or cleanup records corpus scores before and
   after (`make bakeoff`).
3. A promise in `Docs/definition-of-done.md` is changed only with a maintainer's approval.
4. A maintainer decides releases, tags and version numbers. See `RELEASING.md`.

## Issues

1. Before branching for an issue, read its whole thread.
2. If anyone outside the maintainers asked for it or said they are working on it, it is theirs:
   add the `claimed` label, reply, and choose other work.
3. Never do a `good first issue` yourself, claimed or not; the label is inventory for
   contributors. If a branch is already open against one, remove the label.
4. `CONTRIBUTING.md` states what a claim guarantees a contributor; that promise is the
   project's to keep.
