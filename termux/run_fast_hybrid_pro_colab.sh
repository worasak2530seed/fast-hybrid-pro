#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

# Fast Hybrid Pro: Termux controller -> Google Colab runtime -> GitHub results.
# No GitHub Actions minutes are used by this script.
export TZ="Asia/Bangkok"

REPO_URL="https://github.com/worasak2530seed/fast-hybrid-pro.git"
BASE_DIR="${FAST_HYBRID_HOME:-$HOME/colab-automation}"
REPO_DIR="${FAST_HYBRID_REPO_DIR:-$BASE_DIR/fast-hybrid-pro}"
SESSION="fast-hybrid-$(date +%Y%m%d-%H%M%S)"
SESSION_CREATED=0
RUN_TMP_DIR=""

log() { printf '\n[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  rc=$?
  if [ "$SESSION_CREATED" -eq 1 ]; then
    log "Stopping Colab session $SESSION"
    colab --auth=oauth2 stop -s "$SESSION" || true
  fi
  if [ -n "$RUN_TMP_DIR" ] && [ -d "$RUN_TMP_DIR" ]; then
    rm -rf "$RUN_TMP_DIR"
  fi
  exit "$rc"
}
trap cleanup EXIT

# This is designed for Termux. Do not silently switch to GitHub Actions.
if [ -z "${PREFIX:-}" ] && [ -d /data/data/com.termux/files/usr ]; then
  export PREFIX="/data/data/com.termux/files/usr"
fi
export PATH="$HOME/.local/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"

for cmd in git python gh; do
  command -v "$cmd" >/dev/null 2>&1 || die "Missing command '$cmd'. Install it in Termux first; this script will not modify your Termux package setup unexpectedly."
done

gh auth status --hostname github.com >/dev/null 2>&1 || die "GitHub CLI is not authenticated. The existing Termux gh login is required to save validated results."
gh auth setup-git

mkdir -p "$BASE_DIR"
if [ "$REPO_DIR" = "$BASE_DIR" ] && [ -d "$BASE_DIR/.git" ]; then
  :
elif [ ! -d "$REPO_DIR/.git" ]; then
  if [ -e "$REPO_DIR" ] && [ -n "$(find "$REPO_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
    die "The target directory exists but is not a Git repository: $REPO_DIR. No files were deleted."
  fi
  log "Cloning the canonical repository"
  git clone --branch main "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"
origin="$(git remote get-url origin)"
case "$origin" in
  *worasak2530seed/fast-hybrid-pro*) ;;
  *) die "Unexpected origin '$origin'; refusing to run or push to another repository." ;;
esac

# This exact file is a disposable CLI-generated artifact, never canonical source.
# Remove only this known temporary output so a previously interrupted run can recover.
rm -f Fast_Hybrid_Pro_output.ipynb

if [ -n "$(git status --porcelain)" ]; then
  die "The local repository has uncommitted changes. Nothing was overwritten; review them before running."
fi

git checkout main
git fetch origin main
git pull --ff-only origin main
git status --short

if ! command -v colab >/dev/null 2>&1; then
  log "Installing the official Google Colab CLI in Termux"
  python -m pip install --upgrade "git+https://github.com/googlecolab/google-colab-cli.git"
  export PATH="$HOME/.local/bin:${PREFIX:-/data/data/com.termux/files/usr}/bin:$PATH"
fi
command -v colab >/dev/null 2>&1 || die "The Google Colab CLI installation did not produce a 'colab' command."

# OAuth2 uses the local Colab CLI token cache; it does not need the old
# COLAB_ADC_JSON GitHub secret or a downloaded service-account JSON file.
log "Checking direct Colab authentication (OAuth2)"
colab --auth=oauth2 whoami

[ -s Fast_Hybrid_Pro.ipynb ] || die "Canonical notebook is missing."
grep -q 'CELL 13.7' Fast_Hybrid_Pro.ipynb || die "Canonical notebook does not contain Cell 13.7; refusing to run an outdated source."
mkdir -p results
rm -f Fast_Hybrid_Pro_output.ipynb

log "Creating a fresh CPU Colab session: $SESSION"
colab --auth=oauth2 new -s "$SESSION"
SESSION_CREATED=1

if [ -s results/production_signal_journal.csv ]; then
  log "Uploading the existing production signal journal"
  colab --auth=oauth2 upload -s "$SESSION" results/production_signal_journal.csv /content/production_signal_journal.csv
fi

log "Executing the complete canonical notebook on Google Colab"
colab --auth=oauth2 exec --timeout 3600 -s "$SESSION" -f Fast_Hybrid_Pro.ipynb

[ -s Fast_Hybrid_Pro_output.ipynb ] || die "Colab did not produce Fast_Hybrid_Pro_output.ipynb."

RUN_TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fast-hybrid-pro.XXXXXX")"
log "Exporting the Colab execution log and updated signal journal to a temporary directory"
colab --auth=oauth2 log -s "$SESSION" -o "$RUN_TMP_DIR/Fast_Hybrid_Pro_execution_log.ipynb"
colab --auth=oauth2 download -s "$SESSION" /content/production_signal_journal.csv "$RUN_TMP_DIR/production_signal_journal.csv"

log "Validating notebook JSON, cell count, error outputs, and required research results"
python - <<'PY'
import json
import sys
from pathlib import Path

source_path = Path("Fast_Hybrid_Pro.ipynb")
output_path = Path("Fast_Hybrid_Pro_output.ipynb")
source = json.loads(source_path.read_text(encoding="utf-8"))
output = json.loads(output_path.read_text(encoding="utf-8"))

source_cells = source.get("cells", [])
output_cells = output.get("cells", [])
if len(source_cells) != len(output_cells):
    raise SystemExit(
        f"CELL_COUNT_MISMATCH source={len(source_cells)} output={len(output_cells)}; refusing to publish stale/partial results"
    )

errors = []
markers = {
    "12.34": ["TRUE GLOBAL PORTFOLIO STRESS RESULTS", "REALISTIC-FRICTION VERDICT", "CELL 12.34 PASSED"],
    "13.5": ["CELL 13.5 PASSED"],
    "13.6": ["CELL 13.6 PASSED"],
    "13.7": ["CELL 13.7 PASSED"],
}
found = {key: False for key in markers}
research_text = []

for index, cell in enumerate(output_cells):
    cell_source = "".join(cell.get("source", []))
    cell_output = []
    for item in cell.get("outputs", []):
        if item.get("output_type") == "error":
            errors.append(
                f"cell {index}: {item.get('ename', 'Error')}: {item.get('evalue', '')}"
            )
        if "text" in item:
            value = item["text"]
            cell_output.append("".join(value) if isinstance(value, list) else str(value))
        data = item.get("data", {})
        for key in ("text/plain", "text/html"):
            if key in data:
                value = data[key]
                cell_output.append("".join(value) if isinstance(value, list) else str(value))
    combined = "\n".join(cell_output)

    if "CELL 12.34" in cell_source:
        found["12.34"] = all(m in combined for m in markers["12.34"])
        research_text.extend(line for line in combined.splitlines() if any(
            phrase in line for phrase in (
                "GROSS P&L", "Realistic P&L", "Realistic PF",
                "Realistic MaxDD", "REALISTIC_FRICTION_"
            )
        ))
    if "CELL 13.5" in cell_source:
        found["13.5"] = all(m in combined for m in markers["13.5"])
    if "CELL 13.6" in cell_source:
        found["13.6"] = all(m in combined for m in markers["13.6"])
    if "CELL 13.7" in cell_source:
        found["13.7"] = all(m in combined for m in markers["13.7"])
        research_text.extend(line for line in combined.splitlines() if any(
            phrase in line for phrase in (
                "Promotion gate:", "JOINT_STRATEGY_GATE_", "PRODUCTION_UNCHANGED"
            )
        ))

if errors:
    print("Notebook errors:")
    print("\n".join(errors))
    raise SystemExit("NOTEBOOK_VALIDATION_FAILED")
missing = [key for key, ok in found.items() if not ok]
if missing:
    raise SystemExit(
        "Required fresh research output missing for cells " + ", ".join(missing)
        + "; results will not be committed."
    )

run_tmp = Path(__import__("os").environ["RUN_TMP_DIR"])
journal = run_tmp / "production_signal_journal.csv"
log_path = run_tmp / "Fast_Hybrid_Pro_execution_log.ipynb"
if not journal.is_file() or journal.stat().st_size == 0:
    raise SystemExit("Production signal journal is missing or empty.")
if not log_path.is_file() or log_path.stat().st_size == 0:
    raise SystemExit("Colab execution log is missing or empty.")

Path("results/Fast_Hybrid_Pro_latest.ipynb").write_text(
    output_path.read_text(encoding="utf-8"), encoding="utf-8"
)
print(f"Notebook cells: {len(output_cells)} (matches canonical source)")
print("Notebook error outputs: 0")
print("Fresh stress/OOS result markers: Cell 12.34, 13.5, 13.6, 13.7 verified")
print("Production signal journal: present")
for line in research_text:
    print(line)
print("COLAB_RUN_VALIDATED")
PY

# Publish result artifacts only after every notebook and journal check passed.
cp "$RUN_TMP_DIR/Fast_Hybrid_Pro_execution_log.ipynb" results/Fast_Hybrid_Pro_execution_log.ipynb
cp "$RUN_TMP_DIR/production_signal_journal.csv" results/production_signal_journal.csv

git add results/Fast_Hybrid_Pro_latest.ipynb results/Fast_Hybrid_Pro_execution_log.ipynb results/production_signal_journal.csv
if git diff --cached --quiet; then
  log "Validated run completed, but the result files are unchanged; no empty commit created."
else
  git config user.name "Fast Hybrid Pro Termux Runner"
  git config user.email "worasak2530seed@users.noreply.github.com"
  git commit -m "research: save validated Colab run $(date +%Y-%m-%d)"
  git push origin main
  log "Validated Colab results pushed to GitHub main."
fi

log "RUN COMPLETE — Colab was the execution engine; GitHub Actions was not used."
