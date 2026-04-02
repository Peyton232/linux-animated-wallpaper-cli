# Linux Animated Wallpaper CLI (law)

Lightweight animated wallpaper manager for Linux using mpvpaper.

## Features

- Multi-monitor support
- YouTube download support
- Auto optimization (1080p, 30fps)
- Persistent wallpapers
- Interactive CLI

## Requirements

- mpvpaper
- mpv
- ffmpeg
- yt-dlp
- xrandr

## Install

```bash
git clone https://github.com/Peyton232/linux-animated-wallpaper-cli
cd linux-animated-wallpaper-cli
./install.sh
```

## Usage
```bash
law set
law add <file|youtube_url>
law dirs
law list
law restore
```

## Default Directory
```bash
~/Videos/wallpapers
```