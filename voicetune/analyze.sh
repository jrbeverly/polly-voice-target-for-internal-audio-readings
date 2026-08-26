#!/usr/bin/env bash
# Measure broad, level-normalized frequency bands for all sources and targets.

set -euo pipefail
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output="$root/generated/profiles.tsv"

measure_db() {
  ffmpeg -nostdin -hide_banner -i "$1" \
    -map 0:a:0 -af "aformat=channel_layouts=mono,${2}volumedetect" \
    -f null - 2>&1 \
    | awk '/mean_volume:/ { value = $(NF - 1) } END { print value }'
}

mkdir -p -- "$(dirname -- "$output")"
printf 'kind\tpath\tduration_s\tlevel_db\tlow_rel_db\tbody_rel_db\tmid_rel_db\tpresence_rel_db\tair_rel_db\n' > "$output"

for file in "$root"/audio/source/*.mp3 "$root"/audio/target/*.mp3; do
  kind=$(basename -- "$(dirname -- "$file")")
  relative=${file#"$root/"}
  echo "Analyzing $relative" >&2

  duration=$(ffprobe -v error -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 "$file")
  level=$(measure_db "$file" '')
  low=$(measure_db "$file" 'highpass=f=20,lowpass=f=200,')
  body=$(measure_db "$file" 'highpass=f=200,lowpass=f=800,')
  mid=$(measure_db "$file" 'highpass=f=800,lowpass=f=2500,')
  presence=$(measure_db "$file" 'highpass=f=2500,lowpass=f=6000,')
  air=$(measure_db "$file" 'highpass=f=6000,lowpass=f=20000,')

  relative_bands=$(awk \
    -v low="$low" -v body="$body" -v mid="$mid" \
    -v presence="$presence" -v air="$air" \
    'BEGIN {
      mean = (low + body + mid + presence + air) / 5
      printf "%.2f\t%.2f\t%.2f\t%.2f\t%.2f", \
        low - mean, body - mean, mid - mean, presence - mean, air - mean
    }')

  printf '%s\t%s\t%.3f\t%.2f\t%s\n' \
    "$kind" "$relative" "$duration" "$level" "$relative_bands" >> "$output"
done

echo "Wrote ${output#"$root/"}" >&2
