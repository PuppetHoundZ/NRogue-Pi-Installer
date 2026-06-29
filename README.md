Self-contained — generates all required files on Install.
No companion files required. Distribute and run this single script.

nrogue — ncurses roguelike challenge
Source:  [https://github.com/xterminal86/nrogue](https://github.com/xterminal86/nrogue)
License: MIT

Features:
• Clones nrogue from GitHub and builds the ncurses version (lighter weight
than SDL2, no window manager needed, works perfectly in any terminal)
• Installs binary to ~/.local/bin (fully userland, no root beyond apt)
• Copies config-template.txt → ~/.config/nrogue/config.txt for the user
• Installs desktop shortcut (opens in x-terminal-emulator)
• Installs SVG icon to hicolor theme hierarchy
• Uninstall cleanly removes all installed files; system deps retained

Build variant chosen: ncurses (USE_SDL=OFF)
Reason: ncurses is terminal-native, zero GPU/compositor concerns under
labwc Wayland. Lighter compile, smaller binary, no SDL2 window sizing
issues on 800×480 touchscreen. SDL2 build would work but is unnecessary
for a text roguelike on a small display.

Requirements:

* Raspberry Pi OS Trixie (Debian 13) arm64
* Internet connection for initial clone + dep install
* ~100 MB free disk space (build artifacts cleaned up after install)

Usage:
chmod +x nrogue-manager.sh
./nrogue-manager.sh

Do NOT run as root.

Disclaimer:
Provided as-is, free of charge, for Raspberry Pi users. Not affiliated
with the nrogue project or Raspberry Pi Ltd. Use at your own risk.
