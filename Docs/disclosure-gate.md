# The disclosure gate

This repository is public, and the working session that produces a change is not. The gate
keeps the second out of the first. `Scripts/disclosure_audit.py` is the single implementation;
every layer below runs it.

| Where | What it sees |
|---|---|
| `make verify` | the working tree, before the build, beside the PII audit |
| `.githooks/pre-push` | every commit being pushed, to any branch |
| `.githooks/commit-msg` | the message, before it is recorded |
| `.github/workflows/quality.yml` | the pull request's whole range, plus its title and body |
| `.claude/settings.json` | the text of a command an agent is about to run |

There are five layers because no single one holds: the hooks are skipped by `--no-verify`, the
workflow by an admin merge, and the settings hook binds only agents on one machine. The ways
around each do not overlap.

## Two kinds of pattern

- **Names and phrases** fail outright.
- **Vocabulary that is usually innocent and occasionally the tell** is counted against
  `Scripts/disclosure_baseline.json`. A count may fall and never rise.

In text being written now — a message, a pull-request body, an added line — both kinds fail,
because new writing has no legacy to grandfather. The terms are stored base64 so the gate does
not publish what it exists to keep out and does not match itself on every run.

```bash
python3 Scripts/disclosure_audit.py --show-terms          # the lists, decoded
python3 Scripts/disclosure_audit.py --history             # every commit on every ref
python3 Scripts/disclosure_audit.py --update-baseline     # record a fall
make hooks                                                # install both git hooks
```

A document that states the rule can legitimately need a counted word. `--update-baseline
--absorb` records that rise and prints it, so it appears in the baseline's diff for a reviewer.
Use it when the word is the subject, never to make a paragraph fit.

## What does not change

- The gate is never weakened to make a commit pass, and no path is exempted. The one exemption
  is the evaluation corpus, from the phrase patterns only; it does not cover names.
- A failing gate is the gate working: fix the text.
- `--history` is what a repository is judged on before it is made public. A tree can be cleaned
  in one commit; history cannot.
- Removing a line from the tree leaves it in every commit that carried it. When something that
  should not be published is found already committed, a maintainer decides whether to rotate,
  rewrite or squash. An agent reports it and changes nothing.
