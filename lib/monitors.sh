optimize() {
  INPUT="$1"
  BASE="${INPUT%.*}"
  OUTPUT="${BASE}-optimized.mp4"

  [ -f "$OUTPUT" ] && return

  echo "⚙️ Optimizing $(basename "$INPUT")"

  ffmpeg -y -i "$INPUT" \
    -vf "scale=1920:-2,fps=30" \
    -c:v libx264 -preset fast -crf 23 \
    -pix_fmt yuv420p -an \
    "$OUTPUT"
}