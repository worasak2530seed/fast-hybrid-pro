#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
export TZ="Asia/Bangkok"

# Wrapper for the existing Colab runner. It logs locally first, then (optionally)
# uploads a bounded, redacted diagnostic tail to a PRIVATE telemetry repository.
BASE_DIR="${FAST_HYBRID_HOME:-$HOME/colab-automation}"
REPO_DIR="${FAST_HYBRID_REPO_DIR:-$BASE_DIR/fast-hybrid-pro}"
RUNNER="$REPO_DIR/termux/run_fast_hybrid_pro_colab.sh"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"
LOG_FILE="$LOG_DIR/fast-hybrid-$STAMP.log"
LATEST_LOG="$LOG_DIR/fast-hybrid-latest.log"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

[ -x "$RUNNER" ] || [ -f "$RUNNER" ] || die "Runner not found: $RUNNER"
command -v gh >/dev/null 2>&1 || die "GitHub CLI (gh) is required."
gh auth status --hostname github.com >/dev/null 2>&1 || die "Run 'gh auth login' first."

printf '[%s] Fast Hybrid Pro wrapper started\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" | tee -a "$LOG_FILE"
set +e
bash "$RUNNER" 2>&1 | tee -a "$LOG_FILE"
RUN_RC=${PIPESTATUS[0]}
set -e
printf '[%s] Runner exit code: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$RUN_RC" | tee -a "$LOG_FILE"
cp "$LOG_FILE" "$LATEST_LOG"

# Build a conservative diagnostic report. The full local log stays on-device.
# Only a bounded tail is considered, with common credential patterns redacted.
SAFE_LOG="$LOG_DIR/fast-hybrid-$STAMP.redacted.log"
python - "$LOG_FILE" "$SAFE_LOG" "$RUN_RC" "$REPO_DIR" <<'PY'
import re, sys
from pathlib import Path
from datetime import datetime
src, dst, rc, repo = sys.argv[1:]
lines = Path(src).read_text(encoding="utf-8", errors="replace").splitlines()[-100:]
patterns = [
    (re.compile(r'(?i)(authorization\s*[:=]\s*bearer\s+)\S+'), r'\1[REDACTED]'),
    (re.compile(r'(?i)((?:token|secret|password|passwd|api[_-]?key|client[_-]?secret)\s*[=:]\s*)[^\s,;]+'), r'\1[REDACTED]'),
    (re.compile(r'gh[pousr]_[A-Za-z0-9_]{20,}'), '[REDACTED_GITHUB_TOKEN]'),
    (re.compile(r'ya29\.[A-Za-z0-9._-]{20,}'), '[REDACTED_GOOGLE_TOKEN]'),
    (re.compile(r'AIza[0-9A-Za-z_-]{30,}'), '[REDACTED_API_KEY]'),
    (re.compile(r'(?i)[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'), '[REDACTED_EMAIL]'),
    (re.compile(r'/data/data/com\.termux/files/home/[^\s:]+'), '[TERMUX_HOME_PATH]'),
]
clean = []
for line in lines:
    for pat, repl in patterns:
        line = pat.sub(repl, line)
    clean.append(line[:1000])
header = [
    "Fast Hybrid Pro — redacted diagnostic tail",
    f"Timestamp (Asia/Bangkok): {datetime.now().astimezone().isoformat(timespec='seconds')}",
    f"Runner exit code: {rc}",
    "Note: local full log is retained on device; this report is a bounded tail, not a full notebook output.",
    "---",
]
Path(dst).write_text("\n".join(header + clean) + "\n", encoding="utf-8")
PY

# Upload is fail-closed: no telemetry target means no network upload.
# The target must be a private GitHub repository. Never publish logs to the
# public Fast Hybrid Pro source repository.
if [ -n "${FAST_HYBRID_TELEMETRY_REPO:-}" ]; then
  PRIVATE_FLAG="$(gh api "repos/$FAST_HYBRID_TELEMETRY_REPO" --jq '.private' 2>/dev/null || true)"
  [ "$PRIVATE_FLAG" = "true" ] || die "Telemetry target must be an accessible PRIVATE repository. Nothing was uploaded."
  SAFE_B64="$(base64 < "$SAFE_LOG" | tr -d '\n')"
  DEST="termux-reports/fast-hybrid-$STAMP.redacted.log"
  gh api --method PUT "repos/$FAST_HYBRID_TELEMETRY_REPO/contents/$DEST" \
    -f message="termux: redacted run report $STAMP" \
    -f content="$SAFE_B64" \
    -f branch=main >/dev/null
  printf 'Redacted diagnostic report uploaded to private repo: %s/%s\n' "$FAST_HYBRID_TELEMETRY_REPO" "$DEST"
else
  printf 'No private telemetry target configured; log remains on device: %s\n' "$LOG_FILE"
  printf 'Set FAST_HYBRID_TELEMETRY_REPO=OWNER/PRIVATE_REPO to enable private upload.\n'
fi

exit "$RUN_RC"
