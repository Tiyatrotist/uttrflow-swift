<!-- release-policy:v4 -->
# Workflow: branches, pull requests, sessions

There is no `beta` branch, and agents do not merge their own pull requests. One long-lived
branch, `main`, is always releasable; a release is a tag, not a branch.

## Branching and pull requests

0. **Check for overlapping work first.** `gh pr list --state open --search "<file or keyword>"`
   and `gh issue list --search "<keyword>"` return 0 pull requests or issues covering the same
   change, or you link them in the description.
1. **Cut every branch from `origin/main`**, freshly fetched.
2. **Every PR targets `main`**: `gh pr create --base main`.
3. **Open the PR with 0 commits behind `origin/main`:** `git rev-list --count HEAD..origin/main`
   prints 0 after you rebase.
4. **CI runs on every pull request and must be green.** It runs `make verify` and builds the
   app bundle.
5. **Nobody pushes to `main` directly.** A ruleset blocks force-pushes and deletions. Never
   force-push `main`, and never tag: tagging is the release, and the release is a maintainer's.
6. **An agent stops at a green pull request.** The live `main` ruleset requires one approving review.
   It also requires code-owner review, resolution of review threads, dismissal of stale
   reviews after a push, and approval by someone other than the last pusher. The branch
   must be up to date with `main`, enforced by `strict_required_status_checks_policy`, so
   what merges is what was tested.
7. **Green means 0 failing and 0 pending checks.** A running check is not a passed one. Merging
   past a failing or unfinished check happens only on a maintainer's instruction, is reported
   plainly, and never uses `--admin` silently.
8. **Done is an open, green, documented pull request and a clean session.** Do not tag and do
   not release.

There is no staging branch and none should be proposed; the reasoning is in `CONTRIBUTING.md`.
Releases are batched; see `RELEASING.md` and `Docs/releasing.md`.

## Change types and the evidence each needs

| Type | Required evidence in the PR |
|---|---|
| Bug fix | the new test fails on the original code and passes on the fix; both runs shown |
| Feature | tests for the behaviour, the `Docs/` page, and the measurement its area records |
| Refactor | 0 behaviour change: no existing assertion edited or removed, all existing tests unchanged and green |
| Docs only | `make docs-audit` and `make disclosure-audit` pass |
| App shell, resources or entitlements (`Sources/Uttrflow/`, `Resources/`) | `make app-hardened` builds the bundle; `swift build` does not build the app |
| Dependency or workflow | maintainer approval linked, and `make verify` green on the PR |

Every commit in the branch builds, and `git log origin/main..HEAD --format=%s \| grep -c -E '^(fixup\|squash)!'`
prints 0.

## Pull request size

One logical change per pull request, at most 400 changed lines excluding generated files,
baselines and `Docs/`: `git diff --shortstat origin/main`. A larger change is split into a series
that each pass `make verify`.

## Issues

1. **Issue first, then fix.** A bug fix has an issue: 0 fixes land without one, even for a one-line
   change. Open it with the code trace and evidence before branching.
2. **One issue, one branch, one pull request.** The description closes the issue it fixes, and a
   bug found along the way gets its own issue instead of a drive-by change.
3. **Security.** An issue that exposes user text, secrets, keystrokes, tokens, stored data or
   supply-chain trust carries the `security` and `P0` labels. An exploitable vulnerability is
   reported privately as `SECURITY.md` says, never in a public issue.
4. **Platform floor.** A change to the minimum macOS or Xcode version is its own pull request.

## Commit messages

Subject: imperative mood, at most 72 characters (1 of the last 200 subjects exceeds it). Body: why,
in 2 to 4 lines. A fix states the root cause and how the fix works. No `Co-Authored-By` trailer, and
nothing from `AGENTS.local.md` or the session (`make disclosure-audit` rejects it).

## Pull request title

The title becomes the squash commit subject: imperative mood, at most 72 characters, no trailing
period, no `fix:` or `feat:` prefix.

## Pull request description

Five labelled fields, each filled and each at most 5 lines, with no filler and no praise:

| Field | Content |
|---|---|
| Root cause | why the defect exists and why it was not caught |
| Cannot recur because | the test or audit that now fails |
| Measured | commands run and numbers, before and after |
| Assumed | what was not verified |
| Least sure of | the weakest part, for the reviewer to read first |

Open the PR with the five fields written out; `gh pr create --fill` is 0 uses, because it skips them.

Merging is not reviewing: nobody else read the change, so the description is what the reviewer
has.

## Every session ends clean

A session that starts work leaves 0 worktrees, 0 local branches, 0 build outputs and 0 running
processes behind.

1. **Worktrees live in `.claude/worktrees/<name>` and nowhere else.**
2. **Never end with work only on this disk.** Push to `origin/<name>`; a draft PR is fine.
   Abandoned work is discarded and said so.
3. **Once the branch is pushed, remove the worktree and the local branch** — when the pull
   request opens, not when it merges.
4. **Stop what you started:** dev servers, background `make` runs, simulators, monitors,
   scheduled loops. Delete scratch output outside the worktree.
5. **Close the thread:** archive the session in the desktop app, or end the conversation.
6. **Check before saying done:** `git worktree list` shows nothing of yours, and
   `git branch --list <name>` prints nothing.

**Every feature is built in a worktree cut from `origin/main`, then merged into `main` by PR.**

```bash
git fetch origin
git worktree add .claude/worktrees/<name> -b <name> origin/main   # from main, not from HEAD
cd .claude/worktrees/<name>                                       # and stay there
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
… work, commit by name, `make verify` before every push …
git push -u origin <name>
gh pr create --base main --head <name>
cd "$(git rev-parse --git-common-dir)/.."                        # back to the main checkout
git worktree remove .claude/worktrees/<name>                      # refuses if anything is unsaved
git branch -d <name> 2>/dev/null || git branch -D <name>          # safe: the commits are on origin
# no `git push origin --delete` — the remote branch stays, always
```

**Remote branches are never deleted, merged or not.** `origin/<name>` is the pull request's
source ref; when CI or review asks for a change after cleanup, re-fetch it instead of opening a
new pull request:

```bash
git fetch origin
git worktree add .claude/worktrees/<name> origin/<name>
```

**Never run `swift build` or `swift test` in the main checkout while subagents are
working.** They share `.build` and corrupt each other. Give parallel agents
`isolation: "worktree"`, or cut worktrees by hand and point each agent at one by absolute path.

**`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`** before any swift command,
in every shell and every agent prompt; a hook or subagent does not inherit it.

A worktree you did not create is somebody's work. Remove it only if all three hold: it is
clean, every commit on it is on `origin`, and `lsof -a -d cwd | grep <path>` prints nothing.
Each worktree carries its own `.build` of 0.5–5 GB.

## Git

| Rule | Check |
|---|---|
| Stage paths by name; 0 uses of `git add -A`, `git add .`, `git commit -a` | `git status --short` shows only your paths |
| 0 rewrites of pushed history; 0 rebases while another session commits | `ps aux \| grep -c '[c]laude.*--add-dir'` before any rebase |
| A failing test after your change is yours until it fails on a clean `origin/main` worktree | run it in a second worktree; never stash or revert your change to check |
| 0 uses of `--no-verify` or any flag that skips a hook or a check | `git log` shows the hooks ran; a blocked push is fixed, not bypassed |
| 0 rebases, amends or force-pushes after the first push; bring in `main` with a merge | `git merge origin/main` |
| 0 commits on `main` by an agent; changes arrive by pull request only | `git log origin/main..main` is empty |
| 0 `Co-Authored-By` trailers | `git log origin/main..HEAD --format=%B \| grep -c Co-Authored-By` prints 0 |

## Stop and ask

Stop, report what you saw, and wait. Never force-fix and never delete state to make a command
succeed. Triggers:

- a commit on `main`, or a branch, worktree or pull request you did not create;
- a merge, rebase or cleanup you cannot complete cleanly;
- a secret, personal data or session-only material already committed or published;
- a gate that fails for a reason you cannot explain;
- a change that needs a new workflow, a new dependency, or a change to a promise in
  `Docs/definition-of-done.md`.
