#!/usr/bin/env bash
# Proves `make release` keeps app-dist, notarise, dmg and notarise-dmg in that order,
# even under `-j` or an inherited MAKEFLAGS. Dry-run only: no credential or artifact is touched.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

for jobs in 1 4; do
    plan="$(make -n -j"$jobs" release 2>&1)"

    app_dist_line="$(grep -n 'make app-dist$' <<<"$plan" | head -1 | cut -d: -f1)"
    notarise_line="$(grep -n 'make notarise$' <<<"$plan" | head -1 | cut -d: -f1)"
    dmg_line="$(grep -n 'make dmg$' <<<"$plan" | head -1 | cut -d: -f1)"
    notarise_dmg_line="$(grep -n 'make notarise-dmg$' <<<"$plan" | head -1 | cut -d: -f1)"

    for name in app_dist notarise dmg notarise_dmg; do
        eval "value=\${${name}_line:-}"
        if [[ -z "$value" ]]; then
            echo "error: -j$jobs plan is missing the $name stage:" >&2
            printf '%s\n' "$plan" >&2
            exit 1
        fi
    done

    if ! ((app_dist_line < notarise_line && notarise_line < dmg_line && dmg_line < notarise_dmg_line)); then
        echo "error: -j$jobs reordered the release stages:" >&2
        printf '%s\n' "$plan" >&2
        exit 1
    fi
done

echo "release order test passed: app-dist, notarise, dmg, notarise-dmg stay in order under -j1 and -j4"
