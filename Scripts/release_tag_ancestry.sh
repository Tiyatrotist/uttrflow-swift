#!/usr/bin/env bash
set -euo pipefail

tag_ref="${1:-}"
if [[ "$tag_ref" != refs/tags/* ]]; then
    echo "::error::release ref must be a tag: ${tag_ref:-<none>}" >&2
    exit 1
fi

if ! git fetch --no-tags origin '+refs/heads/main:refs/remotes/origin/main'; then
    echo "::error::could not fetch origin/main to check release tag ancestry" >&2
    exit 1
fi

tag_commit="$(git rev-parse --verify --quiet "${tag_ref}^{commit}")" || {
    echo "::error::release tag $tag_ref does not resolve to a commit" >&2
    exit 1
}

if ! git merge-base --is-ancestor "$tag_commit" refs/remotes/origin/main; then
    echo "::error::release tag $tag_ref points to $tag_commit, which is not reachable from origin/main" >&2
    exit 1
fi

printf 'release tag %s points to %s on origin/main\n' "$tag_ref" "$tag_commit"
