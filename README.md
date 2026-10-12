# Fast Hybrid Pro

Research and production execution repository for the Hybrid strategy.

## Architecture

**GitHub = source of truth**  
**Google Colab = execution engine**  
**Termux = Telegram notification watcher only**

Routine research is launched directly from the canonical notebook in Google Colab. Termux must not execute the notebook or run backtests. GitHub Actions is not used for routine research.

Repository: `worasak2530seed/fast-hybrid-pro`

## Repository structure

```text
fast-hybrid-pro/
├── .github/workflows/        # legacy manual-only workflow; not for routine research
├── cells/                    # reserved for validated standalone research cells
├── docs/                     # workflow and research rules
├── notebooks/                # notebook documentation; canonical file is at repository root
├── research/                 # archived research only
├── results/                  # published reports, CSVs, and journal
├── src/                      # reusable Python modules
├── termux/                   # notification watcher only
├── Fast_Hybrid_Pro.ipynb     # canonical Colab notebook
└── README.md
```

## Which notebook is authoritative?

`Fast_Hybrid_Pro.ipynb` at the repository root is the **only canonical runnable notebook**. The notebooks under `research/` are archived research, and the `.ipynb` files under `results/` are historical execution snapshots with older cell sets/outputs; do not use those copies to launch a new run. `notebooks/README.md` documents this layout.

## Run directly in Google Colab

1. Open [Fast_Hybrid_Pro.ipynb in Google Colab](https://colab.research.google.com/github/worasak2530seed/fast-hybrid-pro/blob/main/Fast_Hybrid_Pro.ipynb).
2. In Google Colab, open the **Secrets** panel and add `FAST_HYBRID_GITHUB_TOKEN`. Use a fine-grained GitHub token restricted to this repository with **Contents: Read and write** permission, and enable notebook access for the secret. Never paste the token into a notebook cell or commit it to GitHub.
3. Run **Runtime → Run all**. The first code cell validates the secret and publishes a `RUNNING` status before expensive research starts. Any later cell error attempts to publish `FAILED`; the final cell publishes `SUCCESS` only after the notebook completes and the report artifacts are uploaded. On a cell failure, inspect `results/run_reports/latest_run_error.txt` and the run-specific `colab_error_<run-id>.txt` report when available. These reports may be absent if failure occurs before the error handler starts or GitHub publishing is unavailable.
4. To receive Telegram alerts, start the Termux watcher described below and leave it running while Colab works.
5. Review the published results in [results/run_reports](https://github.com/worasak2530seed/fast-hybrid-pro/tree/main/results/run_reports).

The direct Colab workflow publishes a run summary, the True Global Portfolio stress results and executed trades, risk/capacity sensitivity, loss attribution, nested OOS result tables, MACD event-study tables, the literature-inspired MACD parameter grid, and the production signal journal when available. Cell 13.15 compares a predeclared parameter set using fixed realistic friction and chronological entry cohorts; it is diagnostic research only and never changes Production. The executed notebook's interactive cell outputs remain in the Colab session; save a copy to Drive if you also need the complete rendered notebook.

## Termux: notifications only

Run this in Termux:

```bash
bash "$HOME/colab-automation/fast-hybrid-pro/termux/watch_colab_status.sh"
```

Keep the watcher running to receive start/success/failure messages. It reads `results/run_reports/latest_run_status.json` from GitHub and sends Telegram alerts using the existing `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` environment variables. It does not launch Colab, execute Python research, run a backtest, or commit results.

The legacy command `termux/run_fast_hybrid_pro_colab.sh` is retained as a compatibility entry point, but now starts the notification watcher only.

## GitHub Actions boundary

The workflow at `.github/workflows/run-fast-hybrid-pro-colab.yml` is legacy/manual-only. Do not use it for routine research, and do not enable push triggers. The direct Colab workflow is the supported path.

## Validation principles

- No look-ahead bias.
- Explicit train/OOS separation.
- Portfolio capital constraints are audited.
- Overlapping capital exposure is audited.
- Trade-data integrity is checked before portfolio aggregation.
- Robustness tests are kept separate from optimization.
- Production configuration is not changed merely because a research variant looks better in-sample.
- Archived research is not part of the Production execution path.

## Production status

Production strategy parameters remain frozen:

- Minimum score: `4`
- Weekly confirmation: `False`
- ATR multiplier: `1.2`
- Target 2: `15%`
- Maximum holding period: `20` trading days

The stock universe is rebuilt from SET/mai listed-company classification before indicators/signals are calculated. It applies the canonical mandatory gates:

- Market: `SET` or `mai`
- Market cap: `> 5,000 MB`
- Total trading value across the latest 20 trading sessions: `> 20 MB`
- Price: `1–80 THB`
- Exclude sectors: `BANK`, `FIN`, `INSUR`, `PROP`, `PF&REIT`, `TOURISM`

The liquidity gate is the **sum** of trading value across the latest 20 trading sessions, strictly greater than `20 MB` in total; it is not a per-day average. The price gate is part of the canonical universe filter, not a strategy-optimization parameter.

The current Yahoo market-cap value is a live universe snapshot, not a point-in-time historical market-cap series. Historical survivorship-free fundamental backtesting requires historical market-cap snapshots. This limitation must remain explicit.

## External research and alternative data sources

The literature review and test plan for MACD parameter candidates, plus official SET data-source options and licensing limitations, are documented in [`docs/research_backed_macd_parameters_and_data_sources.md`](docs/research_backed_macd_parameters_and_data_sources.md). The canonical notebook now includes Cell 13.15 and publishes `results/run_reports/literature_macd_parameter_grid.csv` after a successful Colab run. The SETSMART/SMART Marketplace source is not automatically queried unless authorized access or an export is available; Yahoo Finance remains the current runtime source until an independent dataset is actually obtained and reconciled.

## Research archive

Completed research Cells 12.5–12.31 are preserved at `research/archive_12.5_to_12.31.ipynb`. They are historical evidence only and are not part of the Production execution path.

Production parameters remain frozen unless robust untouched OOS evidence passes the promotion gate and the user approves promotion.
