#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# Compatibility entry point: research is no longer executed from Termux.
# Open Fast_Hybrid_Pro.ipynb in Google Colab and use Run all.
# This legacy command now starts only the GitHub -> Telegram notification watcher.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$SCRIPT_DIR/watch_colab_status.sh"
