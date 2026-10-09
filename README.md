# Fast Hybrid Pro

Research and production execution repository for the Hybrid strategy.

## Architecture

**GitHub = source of truth**  
**Termux = local controller**  
**Google Colab = execution engine**  

GitHub Actions is not used for routine research execution. The repository workflow is manual-dispatch-only as a legacy fallback; pushing notebook changes must not launch a research run.

Repository: `worasak2530seed/fast-hybrid-pro`

## Repository structure

```text
fast-hybrid-pro/
├── .github/workflows/        # GitHub Actions → Colab automation
├── cells/                    # standalone canonical research cells
├── docs/                     # workflow and research rules
├── notebooks/                # canonical Colab notebooks
├── research/                 # archived research only
├── results/                  # latest executed notebook and execution log
├── src/                      # reusable Python modules
├── Fast_Hybrid_Pro.ipynb     # production notebook
└── README.md
```

## Automated execution

Use the complete Termux runner at `termux/run_fast_hybrid_pro_colab.sh`. It fetches the canonical `main` branch, authenticates directly to Colab through the local Colab CLI OAuth2 cache, creates a fresh Colab session, runs the notebook, validates Cells 12.34 and 13.5–13.7, then commits results only after validation. It does not invoke GitHub Actions and does not require the old `COLAB_ADC_JSON` secret for local execution.

Routine research must be initiated from Termux and executed on Google Colab, so research runs do not consume GitHub Actions minutes.

The legacy workflow is manual-dispatch-only. Do not use it for routine backtests. Its old flow was:

1. GitHub Actions checks out the repository.
2. The workflow authenticates to Google Cloud/Colab using the `COLAB_ADC_JSON` GitHub Actions secret.
3. A fresh Colab runtime is created for the run.
4. `Fast_Hybrid_Pro.ipynb` is executed in that runtime.
5. The executed notebook is validated and any notebook code-cell errors fail the workflow.
6. The executed notebook is saved as `results/Fast_Hybrid_Pro_latest.ipynb`.
7. The Colab execution log is saved as `results/Fast_Hybrid_Pro_execution_log.ipynb`.
8. The results are committed back to GitHub.

Automatic push-triggered execution has been disabled. There is currently **no scheduled daily run**. This is intentional; no recurring execution has been added.

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

The stock universe is **not hand-picked anymore**. Before indicators/signals are calculated, the notebook rebuilds the universe from SET/mai listed-company classification and applies mandatory gates:

- Market: `SET` or `mai`
- Market cap: `> 5,000 MB`
- Total trading value across the latest 20 trading sessions: `> 20 MB`
- Price: `1–80 THB`
- Exclude sectors: `BANK`, `FIN`, `INSUR`, `PROP`, `PF&REIT`, `TOURISM`

The excluded sectors correspond to banking, finance/hire-purchase, insurance, property/REITs, and tourism/leisure (including hotels) under SET classification.

The liquidity gate is the **sum** of trading value across the latest 20 trading sessions, strictly greater than `20 MB` in total; it is not a per-day average. The `1–80 THB` price gate is also part of the canonical universe filter and is not a strategy-optimization parameter.

The production-readiness audit is rerun after each universe rebuild; the number of production symbols is therefore dynamic. The audit confirmed sufficient historical bars and readiness of the required OHLCV, EMA75, and ATR14 inputs.

A run with zero current Canonical signals is a valid scanner result; it is not treated as an execution error.

## Research archive

Completed research Cells 12.5–12.31 have been moved out of the Production notebook and preserved at:

`research/archive_12.5_to_12.31.ipynb`

These cells are historical evidence only. They are **not** part of the Production execution path and must not be continued or promoted without a new, explicitly approved out-of-sample research cycle.

The same canonical fundamental universe gate is applied before indicators, signals, and backtests. The new universe filter is a scanner/universe change, not a promotion of any archived research variant.

For research integrity, the current Yahoo market-cap value is treated as a live universe snapshot. It must not be described as a point-in-time historical market-cap series; a fully survivorship-free historical fundamental backtest requires historical market-cap snapshots. This limitation is kept explicit so future research cannot silently overstate the evidence.

The cleanup did not change the frozen Production strategy.

## Current operating rule

Prefer verification of the current repository and executed results over assumptions from older research runs. Do not revive archived research branches accidentally.
