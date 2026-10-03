# What must never reach a tracked file

This repository is public: strangers read it, search engines index it, and history keeps it
forever. The working session that produces a change is not public, and the boundary is one way.

**A tracked file, commit message, pull-request title or body, issue or code comment states
technical requirements and technical decisions, in the product's own words, and nothing else.**
What else stays out, and why, is in `AGENTS.local.md`.

## Checks

| Rule | Check | Pass |
|---|---|---|
| Nothing session-only in the tree, messages or PR text | `python3 Scripts/disclosure_audit.py` | exits 0 |
| Counted vocabulary never rises | the same command, against `Scripts/disclosure_baseline.json` | no count above baseline |
| No personal data in fixtures | `make pii-audit` | exits 0 |
| No credentials, keys or private infrastructure identifiers | `Scripts/gitleaks_audit.sh` | exits 0 |
| Gate unweakened | `git diff origin/main -- Scripts/disclosure_audit.py Scripts/disclosure_baseline.json` | no loosened pattern, no new path exemption |

## Rules

1. Reference material is for reading, not keeping. Take the requirement out of anything shared
   in a session, state it in product terms, and let the reference go, "temporarily" included.
2. Describe behaviour, never whose it is and never who said it.
3. Unsure whether something is a technical requirement? Leave it out, or put it in the local
   file.
4. Deleting a line from the tree leaves it in every commit that carried it. If something that
   should not be public is already committed, stop and tell a maintainer before changing
   anything; whether to rewrite history is a maintainer's decision.
5. Never weaken the gate or exempt a path to make a commit pass. A failing gate is the gate
   working.

How the gate is layered and ratcheted: [`../disclosure-gate.md`](../disclosure-gate.md).

## Local rules file

`AGENTS.local.md` is gitignored, private to one person, and read after `AGENTS.md`.

- Location: the root of the main checkout. From a worktree:
  `cat "$(git rev-parse --git-common-dir)/../AGENTS.local.md"`. A missing file is normal.
- It adds and tightens; it never loosens. Where it disagrees with `AGENTS.md`, `AGENTS.md`
  wins and the disagreement is reported.
- Nothing from it is quoted, summarised or paraphrased into a tracked file, commit message,
  pull request, issue or comment.
- A new rule belongs in a tracked file only if every contributor needs it and a stranger could
  read it. Otherwise it belongs in the local file.
