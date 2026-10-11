#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
export TZ="Asia/Bangkok"

REPO="worasak2530seed/fast-hybrid-pro"
POLL_SECONDS="${FAST_HYBRID_POLL_SECONDS:-30}"
BASE_DIR="${FAST_HYBRID_HOME:-$HOME/colab-automation}"
STATE_DIR="$BASE_DIR/state"
STATE_FILE="$STATE_DIR/last_colab_notification"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_API="repos/$REPO/contents/results/run_reports/latest_run_status.json"

mkdir -p "$STATE_DIR"

for cmd in gh python base64; do
  command -v "$cmd" >/dev/null 2>&1 || {
    printf 'ERROR: required command not found: %s\n' "$cmd" >&2
    exit 2
  }
done

gh auth status --hostname github.com >/dev/null 2>&1 || {
  echo "ERROR: GitHub CLI is not authenticated. Sign in with gh auth login first." >&2
  exit 2
}

echo "Fast Hybrid Pro notification watcher started."
echo "Execution happens in Google Colab; this script only watches GitHub status and sends Telegram alerts."
echo "Poll interval: ${POLL_SECONDS}s. Press Ctrl+C to stop."

while true; do
  content_b64="$(gh api "$STATUS_API" --jq .content 2>/dev/null || true)"
  if [ -n "$content_b64" ]; then
    status_json="$(printf '%s' "$content_b64" | base64 -d 2>/dev/null || true)"
    parsed="$(printf '%s' "$status_json" | python -c '
import json, sys
try:
    d = json.load(sys.stdin)
    fields = [d.get("run_id", ""), d.get("status", ""), d.get("detail", ""),
              d.get("report_path", ""), d.get("updated_at_utc", "")]
    print("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in fields))
except Exception:
    raise SystemExit(1)
' 2>/dev/null || true)"

    if [ -n "$parsed" ]; then
      IFS=$'\t' read -r run_id status detail report_path updated_at <<< "$parsed"
      key="${run_id}:${status}"
      last_key="$(cat "$STATE_FILE" 2>/dev/null || true)"

      if [ -n "$run_id" ] && [ "$key" != "$last_key" ]; then
        case "$status" in
          RUNNING)
            message="Fast Hybrid Pro: Google Colab run STARTED. Run ID: $run_id. Status: https://github.com/$REPO/blob/main/results/run_reports/latest_run_status.json"
            ;;
          SUCCESS)
            message="Fast Hybrid Pro: Google Colab run SUCCESS. Run ID: $run_id. Summary: https://github.com/$REPO/blob/main/results/run_reports/latest_run_summary.json"
            ;;
          FAILED)
            detail="${detail:-No error detail was published.}"
            message="Fast Hybrid Pro: Google Colab run FAILED. Run ID: $run_id. Detail: $detail. Status: https://github.com/$REPO/blob/main/results/run_reports/latest_run_status.json"
            ;;
          *)
            message=""
            ;;
        esac

        if [ -n "$message" ]; then
          if python "$SCRIPT_DIR/telegram_notifier.py" "$message"; then
            printf '%s' "$key" > "$STATE_FILE"
            echo "Notified: $key at $updated_at"
          else
            echo "Telegram notification failed; will retry on the next poll."
          fi
        else
          printf '%s' "$key" > "$STATE_FILE"
        fi
      fi
    fi
  fi
  sleep "$POLL_SECONDS"
done
