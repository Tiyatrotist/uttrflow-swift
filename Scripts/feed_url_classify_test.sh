#!/usr/bin/env bash
#
# Tests `Scripts/feed_url_classify.py` against the cases named in issue #1187,
# plus the agreement cases (bundle gate and runtime predicate both accept).
#
# Exits 0 if every case passes, 1 otherwise, with a per-case line on failure.
# Run from the package root, or any directory — paths are resolved to the script's
# own directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/feed_url_classify.py"

[[ -f "$HELPER" ]] || { echo "missing $HELPER" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 is not installed" >&2; exit 1; }

failed=0

# Each case: URL, expected kind or "refused".
# The "agreement" cases are what `UpdateController.isAcceptable` accepts:
#   https, http://127.0.0.1[:port], http://localhost[:port], http://[::1][:port]
# The "refused" cases are the ones from issue #1187: lookalike hosts, port-less
# IPv6, non-loopback HTTP, non-http(s) schemes, malformed URLs.
cases=(
    "https://example.com/a.xml                    https"
    "https://uttrflow.com/appcast.xml              https"
    "http://127.0.0.1:8080/a.xml                   loopback"
    "http://127.0.0.1/a.xml                        loopback"
    "http://localhost/a.xml                        loopback"
    "http://localhost:9000/a.xml                   loopback"
    "http://[::1]/a.xml                            loopback"
    "http://[::1]:8080/a.xml                       loopback"
    "http://127.0.0.1.example.com/a.xml            refused"
    "http://localhost.example.com/a.xml            refused"
    "http://example.com/a.xml                      refused"
    "http://[::1]evil.com/a.xml                    refused"
    "ftp://example.com/a.xml                       refused"
    "javascript:alert(1)                           refused"
)

for case in "${cases[@]}"; do
    url="${case%% *}"
    # Trim trailing whitespace from url to handle aligned column.
    url="${url%"${url##*[![:space:]]}"}"
    expected="${case##* }"
    if output="$(python3 "$HELPER" "$url" 2>&1)"; then
        actual="$output"
    else
        actual="refused"
    fi
    if [[ "$actual" != "$expected" ]]; then
        printf '  FAIL  %-40s expected %-9s got %s\n' "$url" "$expected" "$actual"
        failed=$((failed + 1))
    fi
done

if (( failed > 0 )); then
    echo "feed_url_classify_test: $failed case(s) failed" >&2
    exit 1
fi
echo "feed_url_classify_test: all ${#cases[@]} cases passed"
