detect_monitors() {
  mapfile -t MONITORS < <(
    xrandr --query | awk '/ connected/ {
      name=$1
      match($0, /[0-9]+x[0-9]+\+[0-9]+\+[0-9]+/)
      if (RSTART) {
        split(substr($0, RSTART, RLENGTH), a, "+")
        print a[2], name
      }
    }' | sort -n | awk '{print $2}'
  )

  if [ ${#MONITORS[@]} -eq 0 ]; then
    echo "❌ No monitors detected"
    exit 1
  fi

  LEFT_MON="${MONITORS[0]}"
  RIGHT_MON="${MONITORS[1]:-${MONITORS[0]}}"
}

collect_files() {
  FILES=()

  for dir in $DIRS; do
    mkdir -p "$dir"

    for f in "$dir"/*.{mp4,webm}; do
      [ -e "$f" ] || continue
      [[ "$f" == *"-optimized.mp4" ]] && continue
      optimize "$f"
    done

    for f in "$dir"/*-optimized.mp4; do
      [ -e "$f" ] && FILES+=("$f")
    done
  done
}

cmd_set() {
  detect_monitors
  collect_files

  echo "Left → $LEFT_MON"
  echo "Right → $RIGHT_MON"
  echo ""

  for i in "${!FILES[@]}"; do
    echo "[$i] $(basename "${FILES[$i]}")"
  done

  echo ""
  read -p "Preview index (Enter to skip): " P
  [ -n "$P" ] && mpv --loop --no-audio "${FILES[$P]}"

  read -p "Left index: " L
  read -p "Right index: " R

  LEFT_FILE="${FILES[$L]}"
  RIGHT_FILE="${FILES[$R]}"

  if [ ! -f "$LEFT_FILE" ] || [ ! -f "$RIGHT_FILE" ]; then
    echo "❌ Invalid selection"
    exit 1
  fi

  pkill mpvpaper 2>/dev/null

  mpvpaper -o "no-audio loop hwdec=auto" "$LEFT_MON" "$LEFT_FILE" &
  mpvpaper -o "no-audio loop hwdec=auto" "$RIGHT_MON" "$RIGHT_FILE" &

  echo "$LEFT_FILE|$RIGHT_FILE" > "$HOME/.config/law/state"

  echo "✅ Applied"
}

cmd_add() {
  INPUT="$1"
  TARGET=$(echo $DIRS | awk '{print $1}')

  mkdir -p "$TARGET"

  if [[ "$INPUT" =~ ^https?:// ]]; then
    echo "⬇️ Downloading..."

    yt-dlp -o "$TARGET/%(title)s.%(ext)s" "$INPUT"

    FILE=$(ls -t "$TARGET" | head -n1)
    FULL="$TARGET/$FILE"
  else
    FULL="$TARGET/$(basename "$INPUT")"
    cp "$INPUT" "$FULL"
  fi

  optimize "$FULL"

  echo "✅ Added"
}

cmd_list() {
  collect_files
  for f in "${FILES[@]}"; do
    echo "$(basename "$f")"
  done
}

cmd_dirs() {
  echo "Current dirs: $DIRS"

  read -p "Add new directory: " NEW
  if [ -n "$NEW" ]; then
    mkdir -p "$NEW"
    echo "DIRS=\"$DIRS $NEW\"" > "$HOME/.config/law/config"
    echo "✅ Added"
  fi
}

cmd_restore() {
  detect_monitors

  STATE_FILE="$HOME/.config/law/state"
  [ ! -f "$STATE_FILE" ] && exit

  IFS="|" read -r LEFT_FILE RIGHT_FILE < "$STATE_FILE"

  pkill mpvpaper 2>/dev/null

  mpvpaper -o "no-audio loop hwdec=auto" "$LEFT_MON" "$LEFT_FILE" &
  mpvpaper -o "no-audio loop hwdec=auto" "$RIGHT_MON" "$RIGHT_FILE" &
}