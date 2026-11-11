#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
PROTON="${PROTON:-$STEAM_ROOT/steamapps/common/Proton - Experimental/proton}"
PREFIX="${AC_GOLD_PREFIX:-${XDG_DATA_HOME:-$HOME/.local/share}/american-conquest-gold/prefix}"
DESKTOP_SIZE="${AC_GOLD_DESKTOP_SIZE:-1920x1080}"
LOG_DIR="${AC_GOLD_LOG_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/american-conquest-gold}"
DPLAYX="$DIR/dplayx.dll"
DPLAYX_DISABLED="$DIR/dplayx.dll.cossacksgl-disabled"

archive_previous_crashes() {
  local file base stamp target

  mkdir -p "$LOG_DIR"
  for file in "$DIR/!!crash!!.log" "$DIR/!!crash!!.dmp"; do
    [[ -e "$file" ]] || continue

    base="$(basename "$file")"
    stamp="$(date -r "$file" +%Y%m%d-%H%M%S)"
    target="$LOG_DIR/$stamp-$base"
    if [[ -e "$target" ]]; then
      target="$LOG_DIR/$stamp-$$-$base"
    fi
    mv "$file" "$target"
  done
}

prepare_runtime() {
  local width height disabled_path

  if [[ "$DESKTOP_SIZE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    width="${BASH_REMATCH[1]}"
    height="${BASH_REMATCH[2]}"
  else
    echo "Invalid AC_GOLD_DESKTOP_SIZE '$DESKTOP_SIZE'; expected WIDTHxHEIGHT" >&2
    exit 1
  fi

  # Keep the game from reusing a rewritten/corrupt display state.
  archive_previous_crashes
  printf '%s %s 100 0 0 100 0 8 0 1' "$width" "$height" > "$DIR/mode.dat"
  rm -f "$DIR/DDraw.log" "$DIR/lock.report"

  # dplayx.dll is the bundled CossacksGL wrapper; cnc-ddraw should run alone.
  if [[ -f "$DPLAYX" ]]; then
    disabled_path="$DPLAYX_DISABLED"
    if [[ -e "$disabled_path" ]]; then
      disabled_path="$DPLAYX_DISABLED.$(date +%Y%m%d-%H%M%S)"
    fi
    mv "$DPLAYX" "$disabled_path"
  fi
}

if [[ ! -x "$PROTON" ]]; then
  PROTON="$STEAM_ROOT/steamapps/common/Proton 9.0 (Beta)/proton"
fi

if [[ ! -x "$PROTON" ]]; then
  echo "Could not find Proton Experimental or Proton 9 under $STEAM_ROOT/steamapps/common" >&2
  exit 1
fi

mkdir -p "$PREFIX"
cd "$DIR"
prepare_runtime

proton_status=0
env \
  WINEDEBUG="${WINEDEBUG:--all}" \
  __GL_THREADED_OPTIMIZATIONS="${__GL_THREADED_OPTIMIZATIONS:-1}" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  STEAM_COMPAT_DATA_PATH="$PREFIX" \
  STEAM_COMPAT_APP_ID=115220 \
  PROTON_FORCE_LARGE_ADDRESS_AWARE=0 \
  WINEDLLOVERRIDES="ddraw=n,b;dplayx=b" \
  "$PROTON" run explorer "/desktop=ACGold,$DESKTOP_SIZE" "$DIR/dmcr.exe" || proton_status=$?

# Keep callers waiting for this prefix after explorer spawns the desktop.
WINESERVER="$(dirname "$PROTON")/files/bin/wineserver"
if [[ -x "$WINESERVER" ]]; then
  WINEPREFIX="$PREFIX/pfx" LD_PRELOAD= "$WINESERVER" -w || true
else
  echo "Warning: could not find Proton wineserver at $WINESERVER" >&2
fi

exit "$proton_status"
