================================================================================
CLASSIC PLAYER (Portable Edition for macOS)
Version 1.0.0
================================================================================

Classic Player is a lightweight media player featuring authentic retro interfaces
inspired by Mac OS Classic (Platinum & System 7) and vintage Windows (98 & 3.1).

--------------------------------------------------------------------------------
QUICK START ON macOS
--------------------------------------------------------------------------------
1. Ensure the mpv engine is installed on your Mac. If you use Homebrew:
      brew install mpv

2. To run the portable player, simply double-click:
      ClassicPlayer.command
   (or run ./ClassicPlayer.command from Terminal)

3. Alternatively, generate a native macOS .app bundle by executing:
      ./build-app.sh
   This will output "ClassicPlayer.app" ready to be moved to /Applications.

--------------------------------------------------------------------------------
FEATURES
--------------------------------------------------------------------------------
* 4 Retro Themes:
  - Mac OS 8/9 Platinum (classic pinstripe title bar, Platinum widgets)
  - Mac System 7 (authentic black/white/gray monochrome design)
  - Windows 95/98 (beveled silver 3D buttons & status bar)
  - Windows 3.1 (early GUI styling)
  Switch themes anytime via the View menu or press Ctrl+T.

* No Codecs Required:
  Plays all common audio & video formats (MP4, MKV, AVI, MOV, FLV, WebM, MP3,
  FLAC, AAC, WAV, OGG, etc.) via built-in FFmpeg decoders.

* Low Resource Footprint:
  Ultra-fast startup, hardware-accelerated rendering, and low memory usage.

* Full Control:
  - Video progress bar with drag-to-seek
  - Subtitle loading (.srt, .ass, .vtt) with sync adjustment
  - Real-time Brightness and Contrast controls (Ctrl+B)
  - Screenshots saved as PNG to portable_config/screenshots/ (S / Shift+S)
  - Full screen mode (F) with auto-hiding classic control bar
