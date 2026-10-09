# Termux telemetry and safe remote-control groundwork

## Current scope

- `termux/run_fast_hybrid_pro_colab.sh` remains the research runner: Termux controls it and Google Colab executes the notebook.
- `termux/run_and_report_fast_hybrid_pro.sh` captures a local log for each run and keeps a `fast-hybrid-latest.log` copy.
- Optional upload is **fail-closed** and accepts only a GitHub repository that GitHub reports as private.
- The public source repository is never used as a log destination.
- This does not expose SSH, a shell port, or any public listener.
- This is telemetry only; it does not yet accept commands from ChatGPT.

## Install and run in Termux

From the existing checkout:

```bash
cd ~/colab-automation/fast-hybrid-pro
git fetch origin
git checkout feat/termux-safe-telemetry
git pull --ff-only origin feat/termux-safe-telemetry
chmod 700 termux/run_and_report_fast_hybrid_pro.sh
bash termux/run_and_report_fast_hybrid_pro.sh
```

The wrapper calls the existing canonical Colab runner. It does not use GitHub Actions. Full logs remain on the phone under `~/colab-automation/logs/`.

## Enable automatic remote log upload

Do not upload diagnostics into this repository because it is public. Create a separate **private** repository in GitHub (for example, `fast-hybrid-pro-private-telemetry`) and initialize it with a README so its `main` branch exists. Then in Termux:

```bash
export FAST_HYBRID_TELEMETRY_REPO="YOUR_GITHUB_LOGIN/fast-hybrid-pro-private-telemetry"
bash termux/run_and_report_fast_hybrid_pro.sh
```

To keep this setting across Termux sessions, place the export in a local shell startup file; do not commit it into this repository. The uploader checks the repository's private flag before sending anything and uploads only a bounded diagnostic tail with common credential patterns redacted. The full raw log stays on the device. Redaction is a safeguard, not a guarantee; review logs before sharing them.

## Security boundaries

- Never put OAuth tokens, service-account JSON, passwords, or API keys in issue bodies, notebooks, logs, or repository files.
- Do not implement arbitrary shell commands from a GitHub issue or file.
- The next remote-control phase must use a fixed command enum (for example, `status`, `last-run-summary`, and eventually `run-colab`), validate the requester and request expiry, record an audit trail, and reject every unknown operation.
- A ChatGPT GitHub connection does not itself execute commands on the phone. A Termux poller must be installed and explicitly running before any request/response relay can work.
- Since this source repository is public, never send private logs, account details, credentials, or unredacted runtime output here.
