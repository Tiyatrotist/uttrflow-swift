<!-- release-policy:v4 -->
# Workflow: from branch to merged pull request

`main` is the only long-lived branch and is always releasable. Every change reaches it through a
pull request. Releases are tags that maintainers cut; see `RELEASING.md`. There is no staging
branch, and `CONTRIBUTING.md` says why.

## Before you start

1. **Look for existing work.** `gh issue list --search "<keyword>"` and
   `gh pr list --state open --search "<file or keyword>"` return nothing covering the same change,
   or you link what they return. `CONTRIBUTING.md` says how to claim an issue.
2. **Branch from freshly fetched `origin/main`.**
3. **One logical change per pull request**, at most 400 changed lines excluding generated files,
   baselines and `Docs/` (`git diff --shortstat origin/main`). A larger change is split into a
   series that each pass `make verify`.

## How a pull request lands

1. **It targets `main`**: `gh pr create --base main`.
2. **CI is green: 0 failing and 0 pending checks** (`gh pr checks`). A running check is not a
   passed check. CI runs `make verify` and builds the app bundle.
3. **The `main` ruleset decides the merge.** The live `main` ruleset requires one approving review.
   It also requires code-owner review, resolution of review threads, dismissal of stale
   reviews after a push, and approval by someone other than the last pusher. The branch
   must be up to date with `main`, enforced by `strict_required_status_checks_policy`, so
   what merges is what was tested.
4. **After review, the branch is not rewritten.** Bring in `main` with `git merge origin/main`;
   0 rebases, amends or force-pushes once a reviewer has looked.

## Evidence each change type needs

| Type | Required evidence in the pull request |
|---|---|
| Bug fix | the new test fails on the original code and passes on the fix; both runs shown |
| Feature | tests for the behaviour, the `Docs/` page, and the measurement its area records |
| Refactor | 0 behaviour change: no existing assertion edited or removed, all existing tests unchanged and green |
| Docs only | `make docs-audit` and `make disclosure-audit` pass |
| App shell, resources or entitlements (`Sources/Uttrflow/`, `Resources/`) | `make app-hardened` builds the bundle |
| Dependency or workflow | the issue that agreed it is linked |
| Minimum macOS or Xcode version | its own pull request, with the issue that agreed it |

## Commits

1. Every commit builds; `git log origin/main..HEAD --format=%s | grep -c -E '^(fixup|squash)!'`
   prints 0.
2. Subject: imperative mood, at most 72 characters, no trailing period.
3. Body: why, in 2 to 4 lines. A fix states the root cause and how the fix removes it.
4. Commit only the files the change needs: `git status --short` shows nothing else staged.
5. 0 uses of `--no-verify` or any flag that skips a hook. A blocked commit or push is fixed, not
   bypassed.

## Pull request title and description

1. **Title**: it becomes the squash commit subject, so the commit-subject rule applies; no
   `fix:` or `feat:` prefix.
2. **Description**: every section of `.github/PULL_REQUEST_TEMPLATE.md` is filled;
   `gh pr create --fill` skips it, so it is not used.
3. **A bug fix states its root cause and why it cannot recur** under "What this changes, and
   why", and names the test that now fails if it does.
4. **"How you know it works" names commands and numbers**, before and after where there is a
   measurement, and lists every check that was not run.

## When something fails

1. **A test that fails after your change is yours** until it also fails on a clean checkout of
   `origin/main`. Check in a second checkout or worktree; never stash or revert your change to
   find out.
2. **A gate that fails is the gate working.** Fix the code or the text. Never loosen the gate,
   exempt a path, or record a higher baseline to get past it.
3. **A security vulnerability** is reported privately as `SECURITY.md` says, never in a public
   issue or pull request.
