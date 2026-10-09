# Fast Hybrid Pro — Canonical Workflow

## Source of truth

GitHub repository:

- `worasak2530seed/fast-hybrid-pro`
- default branch: `main`

The canonical source code and research logic should live in this repository.

## Execution

Google Colab is the execution environment; Termux is the intended local controller.

Recommended flow:

1. Keep canonical source in GitHub.
2. Use the existing Termux setup to initiate a Colab runtime directly.
3. Execute the canonical notebook on Colab, not on GitHub Actions.
4. Retrieve and inspect the executed notebook and outputs.
5. Save validated source/results to GitHub only after checks pass.

## Important boundary

GitHub by itself does not remotely press "Run All" on a private Colab runtime. A separate automation layer is required for fully unattended execution.

The repository's old Actions workflow is manual-dispatch-only and must not be used for routine research. Pushes to the notebook no longer trigger it.

**GitHub = source of truth**  
**Termux = local controller**  
**Colab = execution engine**

No Render, GitLab, CircleCI, or routine GitHub Actions research execution is part of this workflow.

## Canonical research rules

- Avoid look-ahead bias.
- Keep train/in-sample and out-of-sample periods explicit.
- Audit overlapping capital exposure.
- Keep portfolio capital constraints explicit.
- Validate trade data integrity before portfolio aggregation.
- Treat robustness tests as validation, not as parameter optimization unless explicitly documented.
- Prefer full reproducible cells/scripts over hidden notebook state.
