# Fast Hybrid Pro — Canonical Workflow

## Source of truth

GitHub repository:

- `worasak2530seed/fast-hybrid-pro`
- default branch: `main`

The canonical source code and research logic should live in this repository.

## Execution

Google Colab is the execution environment.

Recommended flow:

1. Edit/fix canonical code in GitHub.
2. Open the canonical notebook or runner from GitHub in Colab.
3. Colab pulls the selected `main` revision.
4. Run the research/backtest.
5. Save important source changes back to GitHub.
6. Record validation results in the repository.

## Important boundary

GitHub by itself does not remotely press "Run All" on a private Colab runtime. A separate automation layer is required for fully unattended execution.

Until such an automation layer is deliberately added, this project uses:

**GitHub = source of truth**  
**Colab = execution engine**

No Render, GitLab, CircleCI, or other CI system is part of this workflow.

## Canonical research rules

- Avoid look-ahead bias.
- Keep train/in-sample and out-of-sample periods explicit.
- Audit overlapping capital exposure.
- Keep portfolio capital constraints explicit.
- Validate trade data integrity before portfolio aggregation.
- Treat robustness tests as validation, not as parameter optimization unless explicitly documented.
- Prefer full reproducible cells/scripts over hidden notebook state.
