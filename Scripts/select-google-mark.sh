#!/usr/bin/env bash
#
# Picks the standalone square Google mark out of an extracted signin-assets archive.
#
# The pack's internal layout is Google's to change, and it has changed before, so this
# searches for the mark rather than assumes a path. What is wanted is a standalone square
# G with no wording baked in, which is the only shape that can be scaled to a 16pt button.
#
# Usage:  ./Scripts/select-google-mark.sh <extracted-archive-dir>
# Prints the chosen file's path, or nothing (exit 0) if none is recognisable.
set -euo pipefail

DIR="$1"

CANDIDATES="$(find "$DIR" -type f -iname '*.png' \
    ! -iname '*disabled*' ! -iname '*pressed*' ! -iname '*focus*')"

# The legacy layout named the file after the mark itself.
MARK="$(printf '%s\n' "$CANDIDATES" | grep -iE 'g[-_]?logo|logo[-_]?g|google[-_]?g\b|/g\.png$' | sort | head -1 || true)"

if [[ -z "$MARK" ]]; then
    # The current layout names each variant by its attributes instead, e.g. a path
    # component such as "Theme=Neutral, Show text=No, Shape=Square, Platform=iOS.png".
    # A square shape with no text is a standalone mark regardless of theme or platform;
    # sorting the survivors keeps the pick deterministic across all of them.
    MARK="$(printf '%s\n' "$CANDIDATES" \
        | grep -i 'shape=square' \
        | grep -i 'show text=no' \
        | sort \
        | head -1 || true)"
fi

printf '%s' "$MARK"
