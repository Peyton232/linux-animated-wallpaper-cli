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

extract_first_frame() {
  local VIDEO="$1"
  local OUTPUT="$2"

  [ -f "$OUTPUT" ] && return

  echo "📸 Extracting first frame from $(basename "$VIDEO")"

  ffmpeg -y -i "$VIDEO" \
    -vf "select=eq(n\,0)" \
    -q:v 3 \
    "$OUTPUT" 2>/dev/null
}

set_background_from_video() {
  local VIDEO="$1"
  local CACHE_DIR="$HOME/.config/law/backgrounds"
  mkdir -p "$CACHE_DIR"

  local VIDEO_HASH=$(echo "$VIDEO" | md5sum | awk '{print $1}')
  local BG_IMAGE="$CACHE_DIR/${VIDEO_HASH}.jpg"

  extract_first_frame "$VIDEO" "$BG_IMAGE"

  if [ -f "$BG_IMAGE" ]; then
    # For KDE Plasma - update wallpaper configuration
    local KDE_CONFIG="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
    if [ -f "$KDE_CONFIG" ]; then
      local BG_URL="file://${BG_IMAGE}"
      
      # Update all Image= lines in the config to use the new background
      sed -i "s|^Image=.*|Image=${BG_URL}|g" "$KDE_CONFIG"
      
      echo "✅ Background image set to $(basename "$BG_IMAGE")"
      
      # Signal KDE to reload wallpaper
      dbus-send --session --print-reply \
        /org/kde/plasmashell \
        org.kde.PlasmaShell.refreshCurrentActivity 2>/dev/null || true
    fi
  fi
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

  pkill -9 mpvpaper 2>/dev/null

  echo "📸 Setting up background images..."
  set_background_from_video "$LEFT_FILE"
  set_background_from_video "$RIGHT_FILE"

  run_wallpaper "$LEFT_MON" "$RIGHT_MON" "$LEFT_FILE" "$RIGHT_FILE"

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

wait_for_monitors() {
  echo "⏳ Waiting for monitors..."

  for i in {1..10}; do
    COUNT=$(xrandr --query | grep " connected" | wc -l)

    if [ "$COUNT" -ge 1 ]; then
      echo "✅ Monitors detected"
      return
    fi

    sleep 0.5
  done

  echo "⚠️ Timeout waiting for monitors"
}

get_root_pixmap() {
  xprop -root _XROOTPMAP_ID 2>/dev/null | awk -F'=' '{gsub(/ /, "", $2); print $2}'
}

cmd_restore() {
  wait_for_monitors

  detect_monitors

  STATE_FILE="$HOME/.config/law/state"
  [ ! -f "$STATE_FILE" ] && exit

  IFS="|" read -r LEFT_FILE RIGHT_FILE < "$STATE_FILE"

  pkill -9 mpvpaper 2>/dev/null

  echo "📸 Setting up background images..."
  set_background_from_video "$LEFT_FILE"
  set_background_from_video "$RIGHT_FILE"

  run_wallpaper "$LEFT_MON" "$RIGHT_MON" "$LEFT_FILE" "$RIGHT_FILE"
}

cmd_stop() {
  if pkill -9 mpvpaper 2>/dev/null; then
    echo "🛑 Force stopped all mpvpaper instances"
  else
    echo "ℹ️ No mpvpaper processes found"
  fi
}

run_wallpaper() {
  LEFT_MON="$1"
  RIGHT_MON="$2"
  LEFT_FILE="$3"
  RIGHT_FILE="$4"

  pkill -9 mpvpaper 2>/dev/null

  echo "🟢 Starting wallpapers: $LEFT_FILE on $LEFT_MON and $RIGHT_FILE on $RIGHT_MON"
  mpvpaper -o "no-audio loop" "$LEFT_MON" "$LEFT_FILE" &
  mpvpaper -o "no-audio loop" "$RIGHT_MON" "$RIGHT_FILE" &
}