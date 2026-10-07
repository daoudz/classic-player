================================================================================
CLASSIC PLAYER (Portable Edition for Modern Windows)
Version 1.0.0
================================================================================

Classic Player is a lightweight, self-contained media player featuring authentic
retro interfaces inspired by Windows 3.1, Windows 95/98, and classic Mac OS.

Like VLC, it plays virtually any audio and video format right out of the box
with zero codecs needed to install.

--------------------------------------------------------------------------------
QUICK START
--------------------------------------------------------------------------------
1. Double-click "ClassicPlayer.exe" (or "Classic Player.bat").
2. Drop any video or audio file onto the player, or click "File > Open File...".
3. To test immediately, open "sample.mp4" or "sample.wav" in this folder.

--------------------------------------------------------------------------------
FEATURES
--------------------------------------------------------------------------------
* 4 Retro Themes:
  - Windows 95/98 (classic 3D beveled silver buttons, title gradient, status bar)
  - Windows 3.1 (flat 2-pixel black/white borders, system box, caption arrows)
  - Mac OS 8/9 Platinum (pinstripe title bar, Platinum trackbars and buttons)
  - Mac System 7 (authentic black/white/gray monochrome aesthetics)
  Switch themes anytime via "View" menu or press Ctrl+T.

* No Codecs Required:
  Uses the high-performance mpv + FFmpeg engine built right in. Plays MP4, MKV,
  AVI, MOV, WebM, FLV, WMV, MP3, FLAC, WAV, AAC, OGG, OPUS, and many more.

* Minimal Resource Consumption:
  Runs in a single process. Consumes very little RAM (< 45 MB typical idle)
  and uses hardware-accelerated decoding with low-overhead shaders.

* Video Controls & Progress:
  Smooth trackbar seeking with keyframe preview and exact drop-seeking.
  Skip 10 seconds back/forward, control speed (0.5x to 2x), and loop playback.

* Subtitles:
  Auto-detects matching subtitle files (SRT, ASS, VTT, SUB, etc.).
  Load external subtitles via "Subtitle > Load Subtitle..." (Ctrl+L).
  Adjust subtitle sync delay with Z / Shift+Z, or text size with Shift+G / Shift+F.

* Screenshots:
  Take instant clean PNG screenshots using "Play > Take Screenshot" (S)
  or with subtitles included (Shift+S). Screenshots are saved directly into
  the "portable_config\screenshots\" folder.

* Picture Adjustments (Brightness, Contrast, Saturation, Gamma):
  Open "Video > Picture Adjustments..." (Ctrl+B) to fine-tune picture settings
  in real-time, or use quick keys 1/2 (contrast) and 3/4 (brightness).

* 100% Portable:
  Everything is self-contained in this directory. No registry keys, no installer,
  no admin rights needed. Copy the folder to a USB stick and run anywhere.

--------------------------------------------------------------------------------
KEYBOARD SHORTCUTS
--------------------------------------------------------------------------------
Space / P          Play / Pause
Left / Right       Seek backward / forward 10s
Shift+Left/Right   Seek backward / forward 30s
Up / Down          Volume up / down
M                  Mute / Unmute
F / Double-Click   Full Screen (auto-hiding controls)
Ctrl+O             Open File
Ctrl+U             Open URL stream
Ctrl+L             Load Subtitle
S                  Take Screenshot (video only)
Shift+S            Take Screenshot (with subtitles)
Ctrl+B             Picture Adjustments Dialog
1 / 2              Contrast down / up
3 / 4              Brightness down / up
7 / 8              Saturation down / up
[ / ]              Playback speed slower / faster
Ctrl+T             Cycle Themes
F1                 Shortcuts list
Esc                Close menus / dialogs or exit full screen
Q / Alt+F4         Quit
