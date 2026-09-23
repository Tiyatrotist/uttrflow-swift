#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

git init --bare -q "$test_root/origin.git"
git init -q -b main "$test_root/author"
git -C "$test_root/author" config user.name "Release Test"
git -C "$test_root/author" config user.email "release-test@example.invalid"
git -C "$test_root/author" remote add origin "$test_root/origin.git"

printf 'first\n' > "$test_root/author/entry.txt"
git -C "$test_root/author" add entry.txt
git -C "$test_root/author" commit -qm first
older_commit="$(git -C "$test_root/author" rev-parse HEAD)"
git -C "$test_root/author" tag v2026.9.14-old

printf 'second\n' > "$test_root/author/entry.txt"
git -C "$test_root/author" commit -qam second
git -C "$test_root/author" tag -a v2026.9.14 -m current
git -C "$test_root/author" push -q origin main --tags

git -C "$test_root/author" switch -q -c side "$older_commit"
printf 'side\n' > "$test_root/author/entry.txt"
git -C "$test_root/author" commit -qam side
git -C "$test_root/author" tag -a v2026.9.14-side -m side
git -C "$test_root/author" push -q origin v2026.9.14-side

git clone -q --branch main "$test_root/origin.git" "$test_root/runner"
git -C "$test_root/runner" update-ref refs/remotes/origin/main "$older_commit"

cd "$test_root/runner"
"$repo_root/Scripts/release_tag_ancestry.sh" refs/tags/v2026.9.14
"$repo_root/Scripts/release_tag_ancestry.sh" refs/tags/v2026.9.14-old
if "$repo_root/Scripts/release_tag_ancestry.sh" refs/tags/v2026.9.14-side > "$test_root/rejected.log" 2>&1; then
    echo "error: release tag on an unmerged branch passed the ancestry check" >&2
    exit 1
fi
if ! grep -Fq 'not reachable from origin/main' "$test_root/rejected.log"; then
    echo "error: side-branch tag failed without the ancestry diagnostic" >&2
    exit 1
fi

printf 'release tag ancestry test passed\n'
