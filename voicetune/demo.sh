#!/usr/bin/env bash
# Copy one source and its renders against every target into docs/demo/ for index.html.

set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source=${1:-speech_20260822142118651}
attempt=${2:-4}
demo="$root/docs/demo"

rm -rf -- "$demo"
mkdir -p -- "$demo"
cp -- "$root/audio/source/$source.mp3" "$demo/source.mp3"

awk -F'\t' -v s="audio/source/$source.mp3" -v a="$attempt" \
  'NR == 1 || ($1 == s && $3 == a)' "$root/generated/eq/settings.tsv" \
  | cut -f2,4-9 > "$demo/settings.tsv"

printf -v filename 'attempt-%02d.mp3' "$attempt"
for dir in "$root/generated/eq/$source"/*/; do
  cp -- "$dir$filename" "$demo/$(basename -- "$dir").mp3"
done

echo "Wrote ${demo#"$root/"}" >&2
