#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
case "${1:-}" in
  "") exec "$root/helpers/install-copy" "$root" ;;
  --recover-synced-install) exec "$root/helpers/install-copy" "$root" "" "$1" ;;
  --clean) exec "$root/helpers/install-copy" "$root" "" "$1" ;;
  *) printf 'Usage: %s [--recover-synced-install|--clean]\n' "$0" >&2; exit 2 ;;
esac
