# Termux Telegram notifications for Fast Hybrid Pro

## Architecture
- Google Colab runs the live scanner only.
- The scanner publishes reports to the dedicated `scan-reports` branch.
- Termux watches `reports/latest_scan_status.json` and sends a Telegram summary using the existing bot environment variables.
- No GitHub Actions workflow or backtest is used.

## One-time Colab setup
1. Open [Early Signal Scanner in Colab](https://colab.research.google.com/github/worasak2530seed/fast-hybrid-pro/blob/main/notebooks/Early_Signal_Scanner.ipynb).
2. In Colab, open Secrets (key icon) and add `GITHUB_TOKEN`. It must be a fine-grained token for `worasak2530seed/fast-hybrid-pro` with **Contents: Read and write** permission. Do not paste the token into a notebook cell or chat.
3. Enable notebook access to the secret.
4. Run the scanner cells from top to bottom. The final publisher cell writes CSV, summary, and SUCCESS status to `scan-reports`; it prints `GITHUB_REPORT_PUBLISH_PASS` only after all three writes succeed.

## Termux
Run the watcher from the existing local repository folder:
```bash
bash termux/watch_scanner_reports.sh
```
It requires `gh auth login` and the existing environment variables `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`. It uses a separate state file (`state/last_scanner_report`) to avoid repeated notifications. It sends the latest published successful report once when first started, then only sends when the run ID changes.

Keep the watcher running in Termux (or use Termux:Boot if already configured). This script does not run the scanner or consume GitHub Actions minutes.
