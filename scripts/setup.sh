#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
id=io.github.dankestrick.omapandora
plugin="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$id"

"$root/scripts/validate.sh"
"$root/helpers/setup-deps" --install
if [[ $(realpath -m "$plugin") != "$root" ]]; then
  "$root/scripts/install.sh"
fi
omarchy-shell shell rescanPlugins >/dev/null
for attempt in {1..40}; do
  if omarchy plugin enable "$id"; then break; fi
  if (( attempt == 40 )); then exit 1; fi
  sleep .15
done
"$root/helpers/setup-deps" --launcher
printf 'Open Micro-Pandora from the Omarchy launcher to sign in.\n'
