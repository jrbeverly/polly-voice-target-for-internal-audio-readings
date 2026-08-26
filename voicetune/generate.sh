#!/usr/bin/env bash
# Render every source against every target using bounded target-guided EQ.

set -euo pipefail
export LC_ALL=C

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profiles="$root/generated/profiles.tsv"
output_root="$root/generated/eq"

attempts=${1:-4}
random_seed=${2:-20260826}
pull_min=${PULL_MIN:-0.15}
pull_max=${PULL_MAX:-0.50}
max_gain=${MAX_GAIN_DB:-5}

sources=()
targets=()
while IFS= read -r row; do
  case $row in
    source$'\t'*) sources+=("$row") ;;
    target$'\t'*) targets+=("$row") ;;
  esac
done < "$profiles"

mkdir -p -- "$output_root"
settings="$output_root/settings.tsv"
printf 'source\ttarget\tattempt\tpull\tlow_db\tbody_db\tmid_db\tpresence_db\tair_db\toutput\tfilter\n' > "$settings"

total=$(( ${#sources[@]} * ${#targets[@]} * attempts ))
current=0
echo "Rendering $total attempts (${#sources[@]} sources × ${#targets[@]} targets × $attempts)" >&2

for source_row in "${sources[@]}"; do
  IFS=$'\t' read -r _ source_path _ _ source_low source_body source_mid \
    source_presence source_air <<< "$source_row"
  source_name=$(basename -- "$source_path")
  source_stem=${source_name%.*}

  for target_row in "${targets[@]}"; do
    IFS=$'\t' read -r _ target_path _ _ target_low target_body target_mid \
      target_presence target_air <<< "$target_row"
    target_name=$(basename -- "$target_path")
    target_stem=${target_name%.*}

    pair_dir="$output_root/$source_stem/$target_stem"
    mkdir -p -- "$pair_dir"

    for (( attempt = 1; attempt <= attempts; attempt++ )); do
      seed=$(printf '%s\0%s\0%s\0%s' \
        "$source_path" "$target_path" "$attempt" "$random_seed" | cksum | awk '{ print $1 % 2147483647 }')

      read -r pull low_gain body_gain mid_gain presence_gain air_gain < <(
        awk \
          -v seed="$seed" -v attempt="$attempt" -v attempts="$attempts" \
          -v pull_min="$pull_min" -v pull_max="$pull_max" -v max_gain="$max_gain" \
          -v sl="$source_low" -v sb="$source_body" -v sm="$source_mid" \
          -v sp="$source_presence" -v sa="$source_air" \
          -v tl="$target_low" -v tb="$target_body" -v tm="$target_mid" \
          -v tp="$target_presence" -v ta="$target_air" \
          'function clamp(value) {
             return value < -max_gain ? -max_gain : (value > max_gain ? max_gain : value)
           }
           BEGIN {
             srand(seed)
             # Stratification covers the full pull range while rand() avoids a rigid grid.
             pull = pull_min + (pull_max - pull_min) * ((attempt - 1 + rand()) / attempts)
             low = clamp((tl - sl) * pull * (0.8 + 0.4 * rand()))
             body = clamp((tb - sb) * pull * (0.8 + 0.4 * rand()))
             mid = clamp((tm - sm) * pull * (0.8 + 0.4 * rand()))
             presence = clamp((tp - sp) * pull * (0.8 + 0.4 * rand()))
             air = clamp((ta - sa) * pull * (0.8 + 0.4 * rand()))
             printf "%.4f %.2f %.2f %.2f %.2f %.2f\n", \
               pull, low, body, mid, presence, air
           }'
      )

      filter="equalizer=f=125:t=q:w=1:g=$low_gain"
      filter+=",equalizer=f=400:t=q:w=1:g=$body_gain"
      filter+=",equalizer=f=1400:t=q:w=1:g=$mid_gain"
      filter+=",equalizer=f=3500:t=q:w=1:g=$presence_gain"
      filter+=",equalizer=f=8000:t=q:w=1:g=$air_gain"
      filter+=",alimiter=limit=0.95:level=false"

      printf -v filename 'attempt-%02d.mp3' "$attempt"
      output="$pair_dir/$filename"
      ffmpeg -nostdin -hide_banner -loglevel error -y -i "$root/$source_path" \
        -map 0:a:0 -map_metadata -1 -map_chapters -1 -af "$filter" \
        -c:a libmp3lame -b:a 192k "$output"

      current=$(( current + 1 ))
      printf '%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$source_path" "$target_path" "$attempt" "$pull" \
        "$low_gain" "$body_gain" "$mid_gain" "$presence_gain" "$air_gain" \
        "${output#"$root/"}" "$filter" >> "$settings"
      echo "[$current/$total] $source_stem → $target_stem / attempt $attempt" >&2
    done
  done
done

echo "Wrote $total MP3s and ${settings#"$root/"}" >&2
