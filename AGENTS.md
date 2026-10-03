# AGENTS.md

Uttrflow is dictation software for macOS with a clipboard and AI suggestions built in, entirely
on-device. This file is for everyone who works on it, by hand or with an agent. `CLAUDE.md`,
`.cursor/rules/` and `.github/copilot-instructions.md` only point here.

Every rule here applies to anyone who clones this repository. Each states a measure, a limit and
the command that checks it; "pass" means the command exits 0. A rule that only fits one person's
setup belongs in that person's untracked `AGENTS.local.md`, not here.

## Read first

1. This file.
2. Your `AGENTS.local.md`, if you keep one (see "Local rules").
3. The rule file for your work:

| You are... | Read |
|---|---|
| writing or changing code, tests or comments | [Docs/agents/code-quality.md](Docs/agents/code-quality.md) |
| changing what dictation, AI suggestions, the clipboard or the data stores do | [Docs/agents/product.md](Docs/agents/product.md) |
| branching, committing or opening a pull request | [Docs/agents/workflow.md](Docs/agents/workflow.md) |
| writing any text that will be committed or posted | [Docs/agents/public-boundary.md](Docs/agents/public-boundary.md) |
| hitting a tooling failure | [Docs/tooling-traps.md](Docs/tooling-traps.md) |

4. [`Docs/README.md`](Docs/README.md), then the page for the module you change.

## Commands

```bash
make verify                      # the whole gate: audits, lint, build, tests, coverage, offline audit
make lint                        # style and documentation violations
make format                      # rewrite sources in canonical style
make build                       # compile every module
make test                        # run the test suite
swift test --filter <TestCase>   # one test case or method, the fast loop
make coverage                    # tests plus the per-module coverage floor
make bakeoff                     # score every clean-up engine against the corpus
make app-hardened                # build the app bundle; `swift build` does not build the app
make hooks                       # install the commit-msg and pre-push gates, once per clone
```

Run `make verify` before every push; CI runs the same command. Each target's one-line description
is in the `Makefile`. Commands in these files write the base branch as `origin/main`; in a fork,
use the remote that points at this repository.

## Layout

- `Sources/`: one SwiftPM target per module (`Uttrflow*`) plus the `uttrflow-dev`, `uttrflow-eval`
  and `uttrflow-bakeoff` tools. `Tests/` mirrors it.
- `Docs/`: a page per subsystem, holding the measurements, platform traps and rejected approaches
  the code cannot say for itself.
- `Scripts/`: audits, release and packaging. `Design/`: design canvases. `Resources/`: bundle
  resources and `Uttrflow-Info.plist`.

## Non-negotiables

1. **Dictation is a transcript, not a rewrite.** Every word the speaker meant survives, in order.
2. **Latin letters only.** Hindi and Hinglish are romanised, never written in Devanagari and never
   translated.
3. **The user's data stays on this Mac.** Dictation, history, clipboard, dictionary, snippets and
   suggestion data are never sent anywhere.
4. **Fix the root cause.** No special case keyed to one phrase, app or fixture; one implementation
   per capability.

The detail, limits and checks are in [product.md](Docs/agents/product.md) and
[code-quality.md](Docs/agents/code-quality.md).

## Gates

| Gate | Limit | Command |
|---|---|---|
| Comment block length | 1 line | `make comment-audit` |
| Coverage per module | at least 95% | `make coverage` |
| Force unwraps, `try!`, implicitly unwrapped optionals | 0 | `make lint` |
| Compiler warnings | 0 | `make build` |
| Spelling matches decided by shape | never rises | `make match-audit` |
| Real personal data in fixtures | 0 | `make pii-audit` |
| Connections on the dictation path | 0 | `make offline-audit` |
| Conversation or reference material in tracked text | 0 | `make disclosure-audit` |
| Docs that contradict the tree; dates or issue numbers in rule files | 0 | `make docs-audit` |
| Failing or pending checks on a pull request called ready | 0 | `gh pr checks` |

## Working agreement

1. **Surgical.** `git diff --stat origin/main` lists only files the task needs. 0 behaviour-neutral
   reformatting, renames or reflows outside the lines the task changes; anything else you notice
   becomes a separate issue.
2. **Check first.** Before coding, write the success check: one command and its expected result.
3. **No invention.** 0 invented APIs, defaults or behaviours: read the code or run it before
   stating a fact about it.
4. **Honest reports.** Every "passes" or "works" names the command and its result. Every check
   you did not run is listed, with the reason.

## Boundaries

**Always**
- branch from freshly fetched `origin/main`, and read `git status -sb` before the first edit;
- commit only the files the change needs;
- run `make verify` before every push;
- fill every section of the pull-request template;
- run a change to input, insertion, context reading or suggestions once in a real application.

**Ask first**, in an issue or in the pull request, before you:
- add a dependency or a workflow;
- change a protected file ([code-quality.md](Docs/agents/code-quality.md#protected-files));
- change a promise in `Docs/definition-of-done.md`;
- change the minimum macOS or Xcode version;
- delete, skip or weaken an existing test assertion.

**Never**
- skip a hook or a check (`--no-verify`), raise a baseline, or loosen a gate;
- commit a secret, personal data, or text from a private conversation;
- hand-edit a generated file;
- rewrite a branch after review: bring in `main` with a merge;
- describe a security vulnerability in public: report it as `SECURITY.md` says.

## Local rules

Anyone may keep rules for their own setup in **`AGENTS.local.md`** at the root of their checkout.
It is gitignored. A worktree has no untracked files, so read it from a worktree with
`cat "$(git rev-parse --git-common-dir)/../AGENTS.local.md"`. A missing file is normal.

- It adds and tightens; it never loosens a rule here. Where the two disagree, this file wins.
- Nothing from it is quoted, summarised or paraphrased into a tracked file, a commit message, a
  pull request, an issue or a comment.

## Changing these files

A rule belongs in a tracked rule file only if all three hold:

1. **It applies to anyone who clones the repository**, with nothing but this repository and
   their own fork. A rule about one person's machine, sessions, tools, labels, release duties or
   other repositories goes in their `AGENTS.local.md`.
2. **It prevents a mistake that is not obvious** to someone who knows Swift and macOS.
3. **It is checkable**: a measure, a limit and a command, or a review rule with the count the
   reviewer takes.

It is written in the present tense with 0 incidents, 0 dates, 0 issue or pull-request numbers and
0 anecdotes; `make docs-audit` fails on dates and issue numbers. Evidence goes on a `Docs/` page,
linked in one line. A rule lives in the one file that owns its subject, and a rule that no longer
prevents a mistake is deleted.
