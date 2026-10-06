# Fast Hybrid Pro

Research and backtesting project for the Hybrid strategy.

## Architecture

**GitHub = source of truth**  
**Google Colab = execution engine**

Repository: `worasak2530seed/fast-hybrid-pro`

## Current status

The repository has been prepared as the canonical home for the Hybrid project without overwriting the existing Colab notebook.

Structure:

```text
fast-hybrid-pro/
├── cells/          # standalone canonical research cells
├── docs/           # workflow and research rules
├── notebooks/      # canonical Colab notebooks
├── src/            # reusable Python modules
└── README.md
```

## Validation principles

- No look-ahead bias.
- Explicit train/OOS separation.
- Portfolio capital constraints are audited.
- Overlapping capital exposure is audited.
- Trade-data integrity is checked before portfolio aggregation.
- Robustness tests are kept separate from optimization.

## Execution model

Open the canonical notebook from GitHub in Google Colab and execute it there. GitHub can store and version the notebook, while Colab provides the runtime.

A fully unattended GitHub → private Colab runtime → results loop requires a separate automation layer; it is intentionally not added here yet.

## Current research baseline

The current Hybrid work includes portfolio-capital auditing, OOS/time-split validation, and MACD robustness analysis. Existing Colab results are not overwritten by this repository setup.
