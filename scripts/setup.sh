#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
id=io.github.micro23.micro-pandora
config_plugins="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins"
plugin="$config_plugins/$id"

# 1. Clean up legacy Dankestrick plugin if present
if [ -d "$config_plugins/io.github.dankestrick.omapandora" ]; then
  omarchy plugin disable io.github.dankestrick.omapandora 2>/dev/null || true
  rm -rf "$config_plugins/io.github.dankestrick.omapandora"
fi

# 2. Clear quickshell QML bytecode cache to stop loading cached versions
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/qmlcache"

"$root/scripts/validate.sh"
"$root/helpers/setup-deps" --install
if [[ $(realpath -m "$plugin") != "$root" ]]; then
  "$root/helpers/install-copy" "$root" "" "--recover-synced-install"
fi
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
for attempt in {1..40}; do
  if omarchy plugin enable "$id"; then break; fi
  if (( attempt == 40 )); then exit 1; fi
  sleep .15
done
"$root/helpers/setup-deps" --launcher
printf 'Open Micro-Pandora from the Omarchy launcher to sign in.\n'
