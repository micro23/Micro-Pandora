#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

"$root/scripts/validate.sh"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s "$root/tests" -v

scratch=$(mktemp -d)
trap 'rm -rf -- "$scratch"' EXIT
mkdir -m 700 "$scratch/runtime"
for module in Commons Ui Services; do
  ln -s "${OMARCHY_PATH:-$HOME/.local/share/omarchy}/shell/$module" "$scratch/$module"
done
cp "$root/tests/runtime.qml" "$scratch/shell.qml"
ui="$(dirname "$(jq -er '.entryPoints.panel' "$root/manifest.json")")"
if ! env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE \
  XDG_RUNTIME_DIR="$scratch/runtime" QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  XDG_DATA_HOME="$scratch/data" XDG_STATE_HOME="$scratch/state" XDG_CONFIG_HOME="$scratch/config" \
  MICRO_PANDORA_TEST_UI="$root/$ui" \
  timeout 15 dbus-run-session -- quickshell -p "$scratch" --no-color >"$scratch/runtime.log" 2>&1 ||
  ! rg -q MICRO_PANDORA_RUNTIME_OK "$scratch/runtime.log"; then
  cat "$scratch/runtime.log" >&2
  exit 1
fi
echo "QML settings, visualizers, station search and stable poll bindings passed."
