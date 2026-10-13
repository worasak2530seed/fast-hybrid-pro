# Fast Hybrid Pro — Standalone Stock Scanner

This repository's `main` branch is dedicated to the live early-signal stock scanner.

## Run in Google Colab

Open [Early_Signal_Scanner.ipynb](https://colab.research.google.com/github/worasak2530seed/fast-hybrid-pro/blob/main/notebooks/Early_Signal_Scanner.ipynb) and run the cells from top to bottom.

## Scanner scope

- SET and mai ordinary shares.
- Market capitalization strictly greater than THB 5,000 million.
- Latest completed close between THB 1 and THB 80, inclusive.
- Estimated total trading value over the latest 20 sessions greater than THB 20 million.
- Excludes BANK, FIN, INSUR, PF&REIT, PROP, and TOURISM.
- Early-entry and early-warning labels are informational only; no automatic orders or sells.

## Important limitations

The 20-session value is estimated using `Close × Volume` from Yahoo Finance OHLCV, not the exchange's exact traded-value field. Market cap and sector classifications are current lookups and are not point-in-time historical data. Review borderline candidates against a reliable current source before making decisions.

This branch does not run research/backtests or parameter sweeps and does not use GitHub Actions. After a scan, the final notebook cell publishes the latest CSV, summary JSON, and success status to the dedicated [scan-reports branch](https://github.com/worasak2530seed/fast-hybrid-pro/tree/scan-reports). Configure a Colab secret named `GITHUB_TOKEN` with repository Contents read/write access; never paste the token into a cell or chat.

## Telegram notifications from Termux

The existing Telegram bot is retained for Termux use. After pulling the latest `main` branch into your existing local repository, start the watcher with:

```bash
bash termux/watch_scanner_reports.sh
```

It uses the existing `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` environment variables and GitHub CLI authentication. It only watches published scan reports; it never runs the scanner.

The previous repository tree is preserved on [archive/pre-scanner-main-2026-10-13](https://github.com/worasak2530seed/fast-hybrid-pro/tree/archive/pre-scanner-main-2026-10-13).
