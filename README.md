# Classic Player 📼

A minimal, high-efficiency media player with pixel-faithful classic GUI themes (Windows 3.1, Windows 95/98, Mac OS 8/9 Platinum, and Mac System 7).

Like VLC, it plays virtually any audio and video format right out of the box with **zero codec packs required**. Engineered for minimal resource consumption and 100% portability on modern Windows (10/11) and macOS.

---

### 📥 Ready-to-Run Releases

| Platform | Download Package | Description |
| :--- | :--- | :--- |
| **Windows 10 / 11** | [**`ClassicPlayer-v1.0.0-Windows-x64.zip`**](https://github.com/daoudz/classic-player/releases/download/v1.0.0-windows/ClassicPlayer-v1.0.0-Windows-x64.zip) | Standalone portable folder with embedded engine & `ClassicPlayer.exe`. |
| **macOS** | [**`ClassicPlayer-v1.0.0-macOS.zip`**](https://github.com/daoudz/classic-player/releases/download/v1.0.0-macos/ClassicPlayer-v1.0.0-macOS.zip) | Portable runner (`.command`) and automated `.app` bundle builder. |

👉 View all releases on GitHub: **[Releases Page](https://github.com/daoudz/classic-player/releases)**

---

## ✨ Features

- **4 Authentic Classic Themes**:
  - **Windows 95/98**: 3D beveled silver buttons, title bar gradient (`#000080` to `#1084D0`), inset sliders, and dual-pane status bar with resize grip.
  - **Windows 3.1**: Characteristic bold 2px black/white frames, double-line active title bar, maximize/minimize caption arrows, and system menu bar.
  - **Mac OS 8/9 (Platinum)**: Apple Platinum pinstriped title bar, collapse/zoom title buttons, rounded bevels, and lavender accent trackbars.
  - **Mac System 7**: Iconic monochrome Mac interface, bordered title bar with pinstripes, and clean retro contrast.
  - *Switch themes on the fly via `View > [Theme]` or press `Ctrl+T`.*

- **Built-in Codecs (No external filters needed)**:
  - Powered by mpv + FFmpeg libavcodec/libavformat.
  - Supports **MP4, MKV, AVI, MOV, WMV, WebM, FLV, TS, M2TS, VOB, MP3, FLAC, AAC, WAV, OGG, OPUS, APE**, and more.

- **Ultra-Low Resource Consumption**:
  - Direct hardware-accelerated video decoding (`hwdec=auto-safe`).
  - Native ASS vector rendering engine — no heavy web views (Electron/CEF) or bloated frameworks.
  - Typical memory footprint: **~40–50 MB RAM**; near-instant startup.

- **Full Playback & Progress Control**:
  - Drag-and-drop seek slider with keyframe preview and exact seek on release.
  - Quick 10s and 30s skip keys.
  - Speed adjustment from 0.5x to 2.0x.
  - Volume slider and one-click mute.

- **Subtitle Support**:
  - Automatic detection of sidecar subtitles (`.srt`, `.ass`, `.vtt`, `.sub`, etc.).
  - Interactive "Load Subtitle..." dialog (`Ctrl+L`).
  - Subtitle delay adjustments (`Z` / `Shift+Z`) and on-the-fly font size scaling.

- **Screenshots**:
  - One-click lossless PNG screenshots (`S`).
  - Screenshot with or without rendered subtitles (`Shift+S`).
  - Saved to self-contained portable folder (`portable_config/screenshots/`).

- **Picture Adjustments**:
  - Dedicated retro modal window (`Ctrl+B`) for real-time **Brightness**, **Contrast**, **Saturation**, **Gamma**, and **Hue**.
  - Direct keyboard shortcuts (`1`/`2` for contrast, `3`/`4` for brightness).

- **True Portability**:
  - Windows: 100% standalone folder with embedded engine and a 10 KB native `ClassicPlayer.exe` launcher. No registry modification, no installation required.
  - macOS: `ClassicPlayer.command` portable runner and an automated script to build a standard `ClassicPlayer.app`.

---

## 🚀 Quick Start

### Windows (10 / 11)

1. Open `dist/ClassicPlayer-Windows-Portable/`.
2. Double-click **`ClassicPlayer.exe`** (or `Classic Player.bat`).
3. Drag any media file onto the player, or click **File > Open File...** (`Ctrl+O`).
4. To test immediately, open `sample.mp4` or `sample.wav` included in the folder.

### macOS

1. Install mpv (e.g. via Homebrew: `brew install mpv`).
2. Open `dist/ClassicPlayer-macOS-Portable/`.
3. Double-click **`ClassicPlayer.command`** or run:
   ```bash
   ./ClassicPlayer.command
   ```
4. To create a native macOS application bundle, run:
   ```bash
   ./build-app.sh
   ```
   This generates `ClassicPlayer.app` in `dist/ClassicPlayer-macOS/`.

---

## ⌨️ Keyboard & Mouse Controls

| Action | Shortcut / Interaction |
| :--- | :--- |
| **Play / Pause** | `Space` or `P` |
| **Seek -10s / +10s** | `Left` / `Right` arrows |
| **Seek -30s / +30s** | `Shift+Left` / `Shift+Right` |
| **Volume Up / Down** | `Up` / `Down` arrows or Mouse Wheel |
| **Mute / Unmute** | `M` |
| **Full Screen** | `F` or **Double-Click** video area |
| **Open Media** | `Ctrl+O` |
| **Open URL Stream** | `Ctrl+U` |
| **Load Subtitle** | `Ctrl+L` |
| **Toggle Subtitles** | `V` |
| **Subtitle Delay** | `Z` (-100ms) / `Shift+Z` (+100ms) |
| **Take Screenshot** | `S` (clean video) / `Shift+S` (with subtitles) |
| **Picture Adjustments** | `Ctrl+B` |
| **Contrast - / +** | `1` / `2` |
| **Brightness - / +** | `3` / `4` |
| **Saturation - / +** | `7` / `8` |
| **Cycle Themes** | `Ctrl+T` |
| **Help & Shortcuts** | `F1` |
| **Context Menu** | **Right-Click** anywhere |
| **Quit** | `Q` or `Alt+F4` |

---

## 📁 Project Structure

```
classic-player/
├── dist/
│   ├── ClassicPlayer-Windows-Portable/   # Fully assembled Windows distribution
│   │   ├── ClassicPlayer.exe             # Native C# launcher (with retro icon)
│   │   ├── Classic Player.bat            # Batch launcher (drag-and-drop ready)
│   │   ├── mpv.exe / mpv.com             # Portable engine binaries
│   │   ├── *.dll                         # FFmpeg, libass, placebo, etc.
│   │   ├── sample.mp4 / sample.srt       # Test sample media files
│   │   └── portable_config/              # Self-contained configuration & UI
│   └── ClassicPlayer-macOS-Portable/     # Portable package for macOS
│       ├── ClassicPlayer.command         # Finder double-clickable launcher
│       ├── build-app.sh                  # macOS .app builder
│       └── portable_config/
├── src/
│   ├── launcher/                         # Windows launcher source & app.ico
│   ├── macos/                            # macOS runner scripts
│   └── portable_config/                  # UI source files
│       ├── mpv.conf                      # Engine configuration
│       ├── input.conf                    # Keybindings
│       ├── script-opts/                  # User configuration options
│       └── scripts/classicplayer/
│           ├── main.lua                  # Application logic, input, state
│           ├── themes.lua                # Theme definitions & palettes
│           └── draw.lua                  # Vector ASS rendering engine
└── sample.mp4 / sample.srt / sample.wav  # Bundled verification samples
```

---

## 🎨 Theme Customization & Retro Fonts

You can configure default theme and fonts in `portable_config/script-opts/classicplayer.conf`:

```ini
theme=win98          # win98 | win31 | platinum | system7
classic_frame=yes    # retro window frame and title bar
ui_scale=0           # 0 = auto-DPI, 1 = 100%, 2 = 200%
```

To use authentic period fonts (e.g., *W95FA*, *MS Sans Serif*, *Chicago*), drop `.ttf` or `.otf` files into `portable_config/fonts/` and set `font_<theme>=<Font Family>` in `classicplayer.conf`.
