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
    fields = [
        d.get("run_id") or "-", d.get("status") or "-", d.get("scan_date") or "-",
        d.get("updated_at_utc") or "-", d.get("summary_url") or "-",
        d.get("report_url") or "-", d.get("error_type") or "-",
        d.get("error_message") or "-", d.get("traceback_url") or "-"
    ]
    print("\t".join(str(x).replace("\t", " ").replace("\r", " ").replace("\n", " ") for x in fields))
except Exception:
    raise SystemExit(1)
' 2>/dev/null || true)"

    if [ -n "$parsed" ]; then
      IFS=$'\t' read -r run_id status scan_date updated_at summary_url report_url error_type error_message traceback_url <<< "$parsed"
      for var in run_id status scan_date updated_at summary_url report_url error_type error_message traceback_url; do
        [ "${!var}" != "-" ] || printf -v "$var" '%s' ""
      done

      key="${run_id}:${status}"
      last_key="$(cat "$STATE_FILE" 2>/dev/null || true)"
      if [ -n "$run_id" ] && { [ "$status" = "SUCCESS" ] || [ "$status" = "FAILED" ] || [ "$status" = "PARTIAL" ]; } && [ "$key" != "$last_key" ]; then
        summary_json="$(gh api "repos/$REPO/contents/reports/latest_scan_summary.json?ref=$REPORT_BRANCH" --jq .content 2>/dev/null | base64 -d 2>/dev/null || true)"
        counts="$(printf '%s' "$summary_json" | python -c '
import json, sys
try:
    d = json.load(sys.stdin)
    freshness = d.get("intraday_freshness_check", {}) or {}
    print("{}\t{}\t{}\t{}\t{}".format(
        d.get("early_entry_count", 0), d.get("watch_warning_count", 0),
        d.get("scan_error_count", 0), d.get("signal_count", 0),
        freshness.get("excluded_stale_ticker_count", 0)))
except Exception:
    print("0\t0\t0\t0")
' 2>/dev/null || printf '0\t0\t0\t0')"
        IFS=

        if [ "$status" = "FAILED" ]; then
          message="Fast Hybrid Pro — SCAN FAILED
Run: $run_id
Error type: $error_type
Error: $error_message
Summary: $summary_url
Traceback: $traceback_url
Status: https://github.com/$REPO/blob/$REPORT_BRANCH/reports/latest_scan_status.json"
        else
          message="Fast Hybrid Pro — SCAN $status
Date: $scan_date
EARLY ENTRY: $entries
WATCH/WARNING: $warnings
Stocks with signals: $signal_count
Scan errors: $errors
Stale intraday excluded: $excluded_stale
Summary: $summary_url
CSV: $report_url"
        fi

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
\t' read -r entries warnings errors signal_count excluded_stale <<< "$counts"

        if [ "$status" = "FAILED" ]; then
          message="Fast Hybrid Pro — SCAN FAILED
Run: $run_id
Error type: $error_type
Error: $error_message
Summary: $summary_url
Traceback: $traceback_url
Status: https://github.com/$REPO/blob/$REPORT_BRANCH/reports/latest_scan_status.json"
        else
          message="Fast Hybrid Pro — SCAN $status
Date: $scan_date
EARLY ENTRY: $entries
WATCH/WARNING: $warnings
Stocks with signals: $signal_count
Scan errors: $errors
Summary: $summary_url
CSV: $report_url"
        fi

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
