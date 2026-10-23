#!/bin/sh
# Record the download count of every gtfm release asset, one dated row each.
#   snapshot.sh         add today's rows to the CSV
#   snapshot.sh show    print the change since the previous snapshot
# CSV: date,tag,asset,downloads. Default path: ~/.local/share/gtfm/downloads.csv
set -eu
out=${GTFM_STATS:-$HOME/.local/share/gtfm/downloads.csv}
repo=${GTFM_REPO:-devinscodex/gtfm}
mkdir -p "$(dirname "$out")"
[ -f "$out" ] || echo "date,tag,asset,downloads" > "$out"

if [ "${1:-}" = show ]; then
    printf '%-28s %9s %9s %9s\n' 'release,asset' now before change
    awk -F, 'NR > 1 {
        k = $2 "," $3
        if (d[k] != "" && $1 != cur[k]) { prev[k] = d[k]; pd[k] = cur[k] }
        d[k] = $4; cur[k] = $1
    } END {
        for (k in d) printf "%-28s %9d %9s %+9d\n", k, d[k], (k in prev ? prev[k] : "-"), d[k] - (k in prev ? prev[k] : 0)
    }' "$out" | sort
    exit 0
fi

today=$(date +%F)
gh api "repos/$repo/releases" --paginate \
    -q '.[] | .tag_name as $t | .assets[] | "\($t),\(.name),\(.download_count)"' |
    while IFS= read -r row; do echo "$today,$row"; done >> "$out"
echo "wrote $today rows to $out"
