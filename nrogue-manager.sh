#!/usr/bin/env bash
# =============================================================================
# nrogue-manager.sh
# nrogue — ncurses Roguelike — Manager Script
# Version: 1.0.0
# Status: 🟢 GOLD (Production-Ready)
# Last updated: 2026-06-17
#
# Self-contained — generates all required files on Install.
# No companion files required. Distribute and run this single script.
#
# nrogue — ncurses roguelike challenge
#   Source:  https://github.com/xterminal86/nrogue
#   License: MIT
#
# Features:
#   • Clones nrogue from GitHub and builds the ncurses version (lighter weight
#     than SDL2, no window manager needed, works perfectly in any terminal)
#   • Installs binary to ~/.local/bin (fully userland, no root beyond apt)
#   • Copies config-template.txt → ~/.config/nrogue/config.txt for the user
#   • Installs desktop shortcut (opens in x-terminal-emulator)
#   • Installs SVG icon to hicolor theme hierarchy
#   • Uninstall cleanly removes all installed files; system deps retained
#
# Build variant chosen: ncurses (USE_SDL=OFF)
#   Reason: ncurses is terminal-native, zero GPU/compositor concerns under
#   labwc Wayland. Lighter compile, smaller binary, no SDL2 window sizing
#   issues on 800×480 touchscreen. SDL2 build would work but is unnecessary
#   for a text roguelike on a small display.
#
# Requirements:
#   - Raspberry Pi OS Trixie (Debian 13) arm64
#   - Internet connection for initial clone + dep install
#   - ~100 MB free disk space (build artifacts cleaned up after install)
#
# Usage:
#   chmod +x nrogue-manager.sh
#   ./nrogue-manager.sh
#
# Do NOT run as root.
#
# Disclaimer:
#   Provided as-is, free of charge, for Raspberry Pi users. Not affiliated
#   with the nrogue project or Raspberry Pi Ltd. Use at your own risk.
# =============================================================================
#
# AI REFERENCE NOTES — nrogue-manager.sh
# Single source of truth. Read this block in full before making any changes.
# Cross-reference CLAUDEROOT.md for project-wide rules.
#
# ── WHAT THIS SCRIPT DOES ─────────────────────────────────────────────────────
#   Clones nrogue from GitHub, builds it with cmake + Ninja using the ncurses
#   backend (USE_SDL=OFF, the cmake default), installs the binary to
#   ~/.local/bin/nrogue, sets up config, desktop shortcut, and SVG icon.
#   A clean uninstall removes every file the script created — system packages
#   (cmake, ninja-build, g++, libncurses-dev) are RETAINED to avoid breaking
#   other Pi OS tools. git is also retained.
#
# ── BUILD PIPELINE ────────────────────────────────────────────────────────────
#   1. sudo apt install: git cmake ninja-build g++ libncurses-dev
#   2. git clone https://github.com/xterminal86/nrogue.git $BUILD_DIR
#   3. cmake -B $BUILD_DIR/build -G Ninja -DCMAKE_BUILD_TYPE=Release
#            -DUSE_SDL=OFF -DBUILD_TESTS=OFF
#   4. cmake --build $BUILD_DIR/build --config Release
#   5. cp $BUILD_DIR/build/nrogue ~/.local/bin/nrogue
#   6. cp $BUILD_DIR/config-template.txt ~/.config/nrogue/config.txt
#      (only if no config.txt already present — never overwrite user config)
#   7. rm -rf $BUILD_DIR   (build dir cleaned up; only binary + config kept)
#
# ── KEY PATHS ─────────────────────────────────────────────────────────────────
#   ~/.local/bin/nrogue                              — game binary
#   ~/.config/nrogue/config.txt                      — game config (user-editable)
#   ~/.local/share/applications/nrogue.desktop       — desktop shortcut
#   ~/.local/share/icons/hicolor/scalable/apps/nrogue.svg — SVG icon
#   /tmp/nrogue-build-$$                             — temp build dir (auto-cleaned)
#
# ── CONFIG NOTES ──────────────────────────────────────────────────────────────
#   nrogue looks for config.txt in the WORKING DIRECTORY when launched, not a
#   fixed $HOME path. The desktop launcher sets --working-directory to
#   ~/.config/nrogue so the binary finds config.txt there automatically.
#   Save data is also written to the working directory. This is the cleanest
#   approach for per-user config isolation without patching the source.
#
# ── PIPEWIRE / AUDIO SAFETY ───────────────────────────────────────────────────
#   nrogue has NO audio. Zero risk to PipeWire. No audio packages installed.
#   No systemd services created. Completely safe.
#
# ── ENVIRONMENT ───────────────────────────────────────────────────────────────
#   Raspberry Pi 4, Pi OS Trixie (Debian 13 arm64), labwc Wayland compositor.
#   800×480 touchscreen (primary) + 1080p HDMI (secondary, not always connected).
#   Terminal: x-terminal-emulator (Debian alternatives system).
#   ncurses games work in any VTE terminal — lxterminal is default on Pi OS Trixie.
#
# ── UNINSTALL COMPLETENESS ────────────────────────────────────────────────────
#   Removes:
#     ~/.local/bin/nrogue
#     ~/.local/share/applications/nrogue.desktop
#     ~/.local/share/icons/hicolor/scalable/apps/nrogue.svg
#   Prompts before removing (user data):
#     ~/.config/nrogue/   (config.txt + save data live here)
#   Retained (never removed):
#     cmake, ninja-build, g++, libncurses-dev, git — system tools
#
# ── VERSION HISTORY ───────────────────────────────────────────────────────────
#   v1.0.0 (2026-06-17) — Initial release. ncurses build, userland install,
#     desktop shortcut with working-dir trick for config discovery,
#     clean uninstall with optional save-data removal.
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONSTANTS
# =============================================================================
SCRIPT_NAME="nrogue-manager.sh"
APP_NAME="nrogue"
APP_VERSION="1.0.0"
REPO_URL="https://github.com/xterminal86/nrogue.git"
BUILD_DIR="/tmp/nrogue-build-$$"

BIN_DIR="$HOME/.local/bin"
BINARY="$BIN_DIR/nrogue"
CONFIG_DIR="$HOME/.config/nrogue"
CONFIG_FILE="$CONFIG_DIR/config.txt"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/nrogue.desktop"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
ICON_FILE="$ICON_DIR/nrogue.svg"

# =============================================================================
# COLOURS
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# =============================================================================
# HELPERS
# =============================================================================
info()     { echo -e "${CYAN}[INFO]${RESET} $*"; }
ok()       { echo -e "${GREEN}[OK]${RESET}   $*"; }
warn()     { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; exit 1; }
step()     { echo -e "\n${BOLD}${CYAN}==> $*${RESET}"; }

require_no_root() {
    if [[ "$EUID" -eq 0 ]]; then
        error "Do not run this script as root. Run as your normal Pi user."
    fi
}

is_installed() {
    [[ -f "$BINARY" ]]
}

# =============================================================================
# WRITE SVG ICON
# =============================================================================
write_icon() {
    mkdir -p "$ICON_DIR"
    cat > "$ICON_FILE" << 'SVGEOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64">
  <!-- Dark dungeon background -->
  <rect width="64" height="64" rx="8" fill="#0d0d0d"/>
  <!-- Dungeon grid lines (subtle) -->
  <line x1="0" y1="21" x2="64" y2="21" stroke="#1a1a2e" stroke-width="1"/>
  <line x1="0" y1="42" x2="64" y2="42" stroke="#1a1a2e" stroke-width="1"/>
  <line x1="21" y1="0" x2="21" y2="64" stroke="#1a1a2e" stroke-width="1"/>
  <line x1="42" y1="0" x2="42" y2="64" stroke="#1a1a2e" stroke-width="1"/>
  <!-- @ symbol — the classic roguelike player character -->
  <text x="32" y="44"
        font-family="monospace, 'Courier New', Courier"
        font-size="36"
        font-weight="bold"
        text-anchor="middle"
        fill="#c8a840"
        opacity="0.95">@</text>
  <!-- Glow effect under @ -->
  <text x="32" y="44"
        font-family="monospace, 'Courier New', Courier"
        font-size="36"
        font-weight="bold"
        text-anchor="middle"
        fill="#ffd700"
        opacity="0.2"
        filter="url(#glow)">@</text>
  <!-- Corner dots — dungeon walls -->
  <rect x="4"  y="4"  width="4" height="4" fill="#3a3a5c"/>
  <rect x="56" y="4"  width="4" height="4" fill="#3a3a5c"/>
  <rect x="4"  y="56" width="4" height="4" fill="#3a3a5c"/>
  <rect x="56" y="56" width="4" height="4" fill="#3a3a5c"/>
  <defs>
    <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
      <feGaussianBlur stdDeviation="3" result="blur"/>
    </filter>
  </defs>
</svg>
SVGEOF
    ok "SVG icon written → $ICON_FILE"
}

# =============================================================================
# WRITE DESKTOP FILE
# =============================================================================
write_desktop() {
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_FILE" << DESKEOF
[Desktop Entry]
Type=Application
Name=nrogue
GenericName=Roguelike Game
Comment=ncurses roguelike challenge — explore dungeons, survive, conquer
Exec=x-terminal-emulator --working-directory=$CONFIG_DIR -e nrogue
Icon=nrogue
Terminal=false
Categories=Game;RolePlaying;
Keywords=roguelike;ncurses;dungeon;rpg;terminal;
StartupWMClass=nrogue
DESKEOF
    ok "Desktop file written → $DESKTOP_FILE"
}

# =============================================================================
# WRITE CONFIG
# =============================================================================
write_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ -f "$CONFIG_FILE" ]]; then
        info "Config already exists — not overwriting: $CONFIG_FILE"
        return 0
    fi
    cat > "$CONFIG_FILE" << 'CFGEOF'
# nrogue config.txt
# Generated by nrogue-manager.sh
# See: https://github.com/xterminal86/nrogue
# ------------------------------------------------------------------------------
# ncurses build — SDL-only options (tileset, tile_size, preserve_aspect)
# are ignored in this build. They are listed here for reference only.
# ------------------------------------------------------------------------------

# SDL build only — ignored in ncurses build.
# tileset : "graphic-tiles.bmp",

# SDL build only — ignored in ncurses build.
# tile_size : 32,

# SDL build only — ignored in ncurses build.
# preserve_aspect : Y,

# Toggles visual attack display.
# Set to Y to skip frame-by-frame attack animations (faster combat).
fast_combat : N,

# Doesn't force redraw after each visible monster's turn.
# Set to Y to reduce perceived lag when many enemies act.
fast_monster_movement : N,
CFGEOF
    ok "Config written → $CONFIG_FILE"
}

# =============================================================================
# INSTALL
# =============================================================================
do_install() {
    step "Installing nrogue"
    info "Upstream: $REPO_URL"
    info "Build variant: ncurses (terminal-native, lightweight)"
    echo ""

    # -- Check deps -----------------------------------------------------------
    step "Checking / installing build dependencies"
    local deps=(git cmake ninja-build g++ libncurses-dev)
    local to_install=()
    for pkg in "${deps[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            ok "$pkg already installed"
        fi
    done
    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing: ${to_install[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y "${to_install[@]}"
    fi
    ok "All build dependencies satisfied"

    # -- Clone ----------------------------------------------------------------
    step "Cloning nrogue source"
    info "Destination: $BUILD_DIR"
    git clone --depth=1 "$REPO_URL" "$BUILD_DIR" \
        || error "git clone failed. Check your internet connection."
    ok "Clone complete"

    # -- Configure ------------------------------------------------------------
    step "Configuring build (cmake + Ninja, Release, ncurses)"
    cmake \
        -B "$BUILD_DIR/build" \
        -S "$BUILD_DIR" \
        -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DUSE_SDL=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_VERSION_TEXT="pi-manager-1.0.0" \
        || error "cmake configure failed."
    ok "Configuration complete"

    # -- Build ----------------------------------------------------------------
    step "Building nrogue (this takes a few minutes on Pi 4)"
    cmake --build "$BUILD_DIR/build" --config Release \
        || error "cmake build failed."
    ok "Build complete"

    # -- Verify binary --------------------------------------------------------
    [[ -f "$BUILD_DIR/build/nrogue" ]] \
        || error "Build succeeded but binary not found at expected path."

    # -- Install binary -------------------------------------------------------
    step "Installing binary"
    mkdir -p "$BIN_DIR"
    cp "$BUILD_DIR/build/nrogue" "$BINARY"
    chmod +x "$BINARY"
    ok "Binary installed → $BINARY"

    # -- Write config ---------------------------------------------------------
    step "Writing config"
    write_config

    # -- Write icon + desktop -------------------------------------------------
    step "Installing desktop shortcut and icon"
    write_icon
    write_desktop
    gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    ok "Desktop shortcut ready"

    # -- Clean up build dir ---------------------------------------------------
    step "Cleaning up build directory"
    rm -rf "$BUILD_DIR"
    ok "Build artifacts removed (saves ~80 MB)"

    # -- PATH check -----------------------------------------------------------
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        warn "~/.local/bin is not in your PATH."
        warn "Add this to your ~/.bashrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
        warn "Then run: source ~/.bashrc"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}${BOLD}║          nrogue installed successfully!              ║${RESET}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  Launch from:   ${CYAN}Application Menu → Games → nrogue${RESET}"
    echo -e "  Or terminal:   ${CYAN}nrogue${RESET}"
    echo -e "  Config file:   ${CYAN}$CONFIG_FILE${RESET}"
    echo -e "  Save data:     ${CYAN}$CONFIG_DIR/${RESET}"
    echo ""
    echo -e "  ${YELLOW}Tip:${RESET} The game saves to $CONFIG_DIR — edit config.txt"
    echo -e "       to tweak fast_combat and fast_monster_movement."
    echo ""
}

# =============================================================================
# UNINSTALL
# =============================================================================
do_uninstall() {
    step "Uninstalling nrogue"

    if ! is_installed; then
        warn "nrogue binary not found at $BINARY — may already be uninstalled."
    fi

    # -- Remove binary --------------------------------------------------------
    if [[ -f "$BINARY" ]]; then
        rm -f "$BINARY"
        ok "Removed: $BINARY"
    fi

    # -- Remove desktop + icon ------------------------------------------------
    if [[ -f "$DESKTOP_FILE" ]]; then
        rm -f "$DESKTOP_FILE"
        ok "Removed: $DESKTOP_FILE"
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi

    if [[ -f "$ICON_FILE" ]]; then
        rm -f "$ICON_FILE"
        ok "Removed: $ICON_FILE"
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi

    # -- Offer to remove save data / config -----------------------------------
    if [[ -d "$CONFIG_DIR" ]]; then
        echo ""
        echo -e "${YELLOW}Your config and save data are at:${RESET} $CONFIG_DIR"
        echo -e "${YELLOW}This includes config.txt and any game save files.${RESET}"
        echo ""
        read -rp "Delete config and save data? [y/N]: " yn
        case "$yn" in
            [Yy]*)
                rm -rf "$CONFIG_DIR"
                ok "Removed: $CONFIG_DIR"
                ;;
            *)
                info "Config and saves retained at: $CONFIG_DIR"
                ;;
        esac
    fi

    # -- Clean up any leftover build dir (shouldn't exist, safety net) --------
    for d in /tmp/nrogue-build-*; do
        if [[ -d "$d" ]]; then
            rm -rf "$d"
            info "Cleaned up leftover build dir: $d"
        fi
    done

    echo ""
    echo -e "${GREEN}${BOLD}nrogue uninstalled.${RESET}"
    echo ""
    echo -e "  ${CYAN}Note:${RESET} Build tools (cmake, g++, libncurses-dev, etc.) were"
    echo -e "         retained — removing them could break other Pi OS packages."
    echo ""
}

# =============================================================================
# MAIN MENU
# =============================================================================
main_menu() {
    clear
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}${CYAN}║           NROGUE — Manager Script v${APP_VERSION}           ║${RESET}"
    echo -e "${BOLD}${CYAN}║           ncurses roguelike challenge                ║${RESET}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "  Upstream: ${CYAN}https://github.com/xterminal86/nrogue${RESET}"
    echo ""

    if is_installed; then
        echo -e "  Status: ${GREEN}${BOLD}Installed${RESET} (${CYAN}$BINARY${RESET})"
    else
        echo -e "  Status: ${YELLOW}Not installed${RESET}"
    fi

    echo ""
    echo -e "  ${BOLD}1)${RESET} Install nrogue"
    echo -e "  ${BOLD}2)${RESET} Uninstall nrogue"
    echo -e "  ${BOLD}3)${RESET} Launch nrogue (opens in terminal)"
    echo -e "  ${BOLD}Q)${RESET} Quit"
    echo ""
    read -rp "  Select an option: " choice

    case "$choice" in
        1)
            if is_installed; then
                warn "nrogue is already installed."
                echo ""
                read -rp "  Re-install anyway? (pulls latest source) [y/N]: " yn
                [[ "$yn" =~ ^[Yy]$ ]] || return
                do_uninstall
                do_install
            else
                do_install
            fi
            ;;
        2)
            do_uninstall
            ;;
        3)
            if ! is_installed; then
                warn "nrogue is not installed. Please choose option 1 first."
            else
                info "Launching nrogue in a new terminal..."
                x-terminal-emulator --working-directory="$CONFIG_DIR" -e nrogue &
                disown
            fi
            ;;
        [Qq])
            echo ""
            info "Goodbye!"
            echo ""
            exit 0
            ;;
        *)
            warn "Invalid option: $choice"
            ;;
    esac
}

# =============================================================================
# ENTRY POINT
# =============================================================================
require_no_root

while true; do
    main_menu
    echo ""
    read -rp "Press Enter to return to the menu..." _
done
