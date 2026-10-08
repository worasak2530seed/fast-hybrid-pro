# Fast Hybrid Pro

Research and production execution repository for the Hybrid strategy.

## Architecture

**GitHub = source of truth**  
**Google Colab = execution engine**  
**GitHub Actions = orchestration and result persistence**

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

The production notebook can be executed on a fresh Google Colab runtime through GitHub Actions.

The workflow is:

1. GitHub Actions checks out the repository.
2. The workflow authenticates to Google Cloud/Colab using the `COLAB_ADC_JSON` GitHub Actions secret.
3. A fresh Colab runtime is created for the run.
4. `Fast_Hybrid_Pro.ipynb` is executed in that runtime.
5. The executed notebook is validated and any notebook code-cell errors fail the workflow.
6. The executed notebook is saved as `results/Fast_Hybrid_Pro_latest.ipynb`.
7. The Colab execution log is saved as `results/Fast_Hybrid_Pro_execution_log.ipynb`.
8. The results are committed back to GitHub.

The workflow supports both:

- manual execution with `workflow_dispatch`
- automatic execution when `Fast_Hybrid_Pro.ipynb` changes on `main`

There is currently **no scheduled daily run**. This is intentional; no recurring execution has been added.

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
- Average 20-day trading value: `>= 10 MB/day`
- Exclude sectors: `BANK`, `FIN`, `INSUR`, `PROP`, `PF&REIT`, `TOURISM`

The excluded sectors correspond to banking, finance/hire-purchase, insurance, property/REITs, and tourism/leisure (including hotels) under SET classification.

The `10 MB/day` liquidity threshold is the current scanner floor; it can be raised later only through an explicit research/validation cycle.

The production-readiness audit is rerun after each universe rebuild; the number of production symbols is therefore dynamic. The audit confirmed sufficient historical bars and readiness of the required OHLCV, EMA75, and ATR14 inputs.

A run with zero current Canonical signals is a valid scanner result; it is not treated as an execution error.

## Research archive

Completed research Cells 12.5–12.31 have been moved out of the Production notebook and preserved at:

`research/archive_12.5_to_12.31.ipynb`

These cells are historical evidence only. They are **not** part of the Production execution path and must not be continued or promoted without a new, explicitly approved out-of-sample research cycle.

The new universe filter is a scanner/universe change, not a promotion of any archived research variant.

The cleanup did not change the frozen Production strategy.

## Current operating rule

Prefer verification of the current repository and executed results over assumptions from older research runs. Do not revive archived research branches accidentally.
