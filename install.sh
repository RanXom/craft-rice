#!/usr/bin/env bash
# craft-rice — one-line entry point.
#
#   ./install.sh              install
#   ./install.sh --dry-run    preview
#   ./install.sh uninstall    undo and restore backups
#   ./install.sh doctor       check the session
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT/bin/craft-rice" "$@"
