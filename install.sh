#!/usr/bin/env bash

set -e

echo "🔧 Installing law..."

# -----------------------
# Detect package manager
# -----------------------
if command -v pacman >/dev/null; then
  PM="pacman"
elif command -v apt >/dev/null; then
  PM="apt"
elif command -v dnf >/dev/null; then
  PM="dnf"
elif command -v zypper >/dev/null; then
  PM="zypper"
else
  PM="unknown"
fi

echo "Detected package manager: $PM"

# -----------------------
# Install dependencies
# -----------------------
install_pacman() {
  sudo pacman -S --needed mpv ffmpeg yt-dlp xorg-xrandr

  # mpvpaper (AUR)
  if ! command -v mpvpaper >/dev/null; then
    if command -v yay >/dev/null; then
      yay -S --needed mpvpaper
    else
      echo "⚠️ mpvpaper not found. Install from AUR:"
      echo "   yay -S mpvpaper"
    fi
  fi
}

install_apt() {
  sudo apt update
  sudo apt install -y mpv ffmpeg yt-dlp x11-xserver-utils

  echo "⚠️ mpvpaper not available on apt by default"
  echo "Install manually: https://github.com/GhostNaN/mpvpaper"
}

install_dnf() {
  sudo dnf install -y mpv ffmpeg yt-dlp xrandr

  echo "⚠️ mpvpaper may require manual install"
}

install_zypper() {
  sudo zypper install -y mpv ffmpeg yt-dlp xrandr

  echo "⚠️ mpvpaper may require manual install"
}

# -----------------------
# Run installer
# -----------------------
case "$PM" in
  pacman) install_pacman ;;
  apt) install_apt ;;
  dnf) install_dnf ;;
  zypper) install_zypper ;;
  *)
    echo "❌ Unsupported distro"
    echo "Install manually:"
    echo "  mpv, ffmpeg, yt-dlp, xrandr, mpvpaper"
    ;;
esac

# -----------------------
# Install CLI 
# -----------------------

INSTALL_DIR="/usr/local/lib/law"
BIN_DIR="/usr/local/bin"

echo "📁 Installing files to $INSTALL_DIR..."

# Create install directory
sudo mkdir -p "$INSTALL_DIR"

# Copy project files
sudo cp -r bin "$INSTALL_DIR/"
sudo cp -r lib "$INSTALL_DIR/"

# Create launcher script
echo "⚙️ Creating launcher..."

sudo tee "$BIN_DIR/law" > /dev/null <<EOF
#!/usr/bin/env bash
$INSTALL_DIR/bin/law "\$@"
EOF

sudo chmod +x "$BIN_DIR/law"