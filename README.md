# Fast Hybrid Pro — Standalone Stock Scanner

This repository's `main` branch is dedicated to the live early-signal stock scanner.

## Canonical notebook on `main`

`main` is the single source of truth for the current scanner. Do not run a notebook opened from a `fix/*` or `feature/*` branch. The historical research notebook is not the active scanner and is not part of the scan workflow.

## Run in Google Colab

Open [Early_Signal_Scanner.ipynb](https://colab.research.google.com/github/worasak2530seed/fast-hybrid-pro/blob/main/notebooks/Early_Signal_Scanner.ipynb) and run the cells from top to bottom.

## Scanner scope

- SET and mai ordinary shares, using the public [Thai Securities Data JSON dataset](https://github.com/lumduan/thai-securities-data) for listing/classification metadata. The scanner checks the dataset update timestamp (maximum age 7 days), schema and SET/mai row counts; it falls back to the official SET listing if the mirror is stale or malformed. This dataset is **not** a price or intraday quote feed.
- Market capitalization strictly greater than THB 5,000 million.
- Latest completed close between THB 1 and THB 80, inclusive.
- Estimated total trading value over the latest 20 sessions greater than THB 20 million.
- Excludes BANK, FIN, INSUR, PF&REIT, PROP, and TOURISM.
- Early-entry and early-warning labels are informational only; no automatic orders or sells.

## Important limitations

The 20-session value is estimated using `Close × Volume` from Yahoo Finance OHLCV, not the exchange's exact traded-value field. Market cap and sector classifications are current lookups and are not point-in-time historical data. The Thai Securities Data dataset may mark mai sectors as `-`; the scanner reports this coverage gap and does not guess a sector from a broad industry label, so the configured sector exclusions cannot be fully verified for those rows. Review borderline candidates against a reliable current source before making decisions. Free Yahoo 15-minute OHLCV bars drive EARLY_ENTRY/EARLY_WARNING calculations during the SET session; indicator periods are counted in 15-minute bars. Daily close is retained for the agreed THB 1–80 universe price filter. Yahoo's actual delay/coverage is not guaranteed, so every published intraday row must pass a completed-bar age gate (30 minutes maximum) or be excluded and the report marked `PARTIAL`. Stale or unverifiable rows remain in the audit CSV for diagnosis, but their actionable `EARLY_ENTRY`/`EARLY_WARNING` labels are suppressed; raw pre-suppression candidates are retained in `RawEARLY_ENTRY` and `RawEARLY_WARNING`, with `SignalSuppressedReason` explaining why they were blocked. Outside the expected SET session, the report remains `PARTIAL`; it never claims a verified live intraday scan when the market is closed.

This branch does not run research/backtests or parameter sweeps and does not use GitHub Actions. After a scan, the final notebook cell publishes the latest CSV, summary JSON, and success status to the dedicated [scan-reports branch](https://github.com/worasak2530seed/fast-hybrid-pro/tree/scan-reports). Configure `FAST_HYBRID_GITHUB_TOKEN` in the new Colab account (`before12august@gmail.com`) with repository Contents read/write access. `GITHUB_TOKEN` remains a compatibility alias. Never paste the token into a cell or chat.

## Telegram notifications from Termux

The existing Telegram bot is retained for Termux use. After pulling the latest `main` branch into your existing local repository, start the watcher with:

```bash
bash termux/watch_scanner_reports.sh
```

It uses the existing `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` environment variables and GitHub CLI authentication. It only watches published scan reports; it never runs the scanner.

The previous repository tree is preserved on [archive/pre-scanner-main-2026-10-13](https://github.com/worasak2530seed/fast-hybrid-pro/tree/archive/pre-scanner-main-2026-10-13).

## After-hours daily-bar scanner

Use the separate [After-hours Scanner notebook](notebooks/After_Hours_Scanner.ipynb) when the SET market is closed. It calculates EARLY ENTRY / EARLY WARNING from the latest verified completed daily OHLCV bars, publishes the scan report to the `scan-reports` branch, and labels the output as `AFTER_HOURS_DAILY_CLOSED_BAR`. These are watchlist candidates for the next session, not live intraday signals. The existing intraday scanner remains available separately and requires fresh completed 15-minute bars during the SET session.

