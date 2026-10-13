#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
export TZ="Asia/Bangkok"

REPO="worasak2530seed/fast-hybrid-pro"
REPORT_BRANCH="scan-reports"
POLL_SECONDS="${FAST_HYBRID_POLL_SECONDS:-60}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BASE_DIR="${FAST_HYBRID_HOME:-$(dirname "$REPO_DIR")}"
STATE_DIR="$BASE_DIR/state"
STATE_FILE="$STATE_DIR/last_scanner_report"
STATUS_API="repos/$REPO/contents/reports/latest_scan_status.json?ref=$REPORT_BRANCH"

mkdir -p "$STATE_DIR"
for cmd in gh python base64; do
  command -v "$cmd" >/dev/null 2>&1 || { printf 'ERROR: required command not found: %s\n' "$cmd" >&2; exit 2; }
done
gh auth status --hostname github.com >/dev/null 2>&1 || {
  echo "ERROR: GitHub CLI is not authenticated. Run gh auth login first." >&2
  exit 2
}
if [ ! -f "$SCRIPT_DIR/telegram_notifier.py" ]; then
  echo "ERROR: telegram_notifier.py is missing beside this watcher." >&2
  exit 2
fi

echo "Fast Hybrid Pro scanner report watcher started."
echo "Colab scans; GitHub branch '$REPORT_BRANCH' stores reports; Termux sends Telegram notifications."
echo "Poll interval: ${POLL_SECONDS}s. Press Ctrl+C to stop."

while true; do
  content_b64="$(gh api "$STATUS_API" --jq .content 2>/dev/null || true)"
  if [ -n "$content_b64" ]; then
    status_json="$(printf '%s' "$content_b64" | base64 -d 2>/dev/null || true)"
    parsed="$(printf '%s' "$status_json" | python -c '
import json, sys
try:
    d = json.load(sys.stdin)
    fields = [d.get("run_id", ""), d.get("status", ""), d.get("scan_date", ""),
              d.get("updated_at_utc", ""), d.get("summary_url", ""),
              d.get("report_url", "")]
    print("\t".join(str(x).replace("\t", " ").replace("\n", " ") for x in fields))
except Exception:
    raise SystemExit(1)
' 2>/dev/null || true)"
    if [ -n "$parsed" ]; then
      IFS=$'\t' read -r run_id status scan_date updated_at summary_url report_url <<< "$parsed"
      key="${run_id}:${status}"
      last_key="$(cat "$STATE_FILE" 2>/dev/null || true)"
      if [ -n "$run_id" ] && [ "$status" = "SUCCESS" ] && [ "$key" != "$last_key" ]; then
        summary_json="$(gh api "repos/$REPO/contents/reports/latest_scan_summary.json?ref=$REPORT_BRANCH" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)"
        counts="$(printf '%s' "$summary_json" | python -c '
import json, sys
try:
 d=json.load(sys.stdin)
 print("{}\t{}\t{}\t{}".format(d.get("early_entry_count", 0), d.get("watch_warning_count", 0), d.get("scan_error_count", 0), d.get("signal_count", 0)))
except Exception:
 print("0\t0\t0\t0")
' 2>/dev/null || printf '0\t0\t0\t0')"
        IFS=$'\t' read -r entries warnings errors signal_count <<< "$counts"
        message="Fast Hybrid Pro — SCAN COMPLETE
Date: $scan_date
EARLY ENTRY: $entries
WATCH/WARNING: $warnings
Stocks with signals: $signal_count
Scan errors: $errors
Summary: $summary_url
CSV: $report_url"
        if python "$SCRIPT_DIR/telegram_notifier.py" "$message"; then
          printf '%s' "$key" > "$STATE_FILE"
          echo "TELEGRAM_SCAN_REPORT_SENT: $key ($updated_at)"
        else
          echo "Telegram notification failed; will retry on next poll."
        fi
      fi
    fi
  fi
  sleep "$POLL_SECONDS"
done
