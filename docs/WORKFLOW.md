# Fast Hybrid Pro — Canonical Workflow

## Source of truth

- Repository: `worasak2530seed/fast-hybrid-pro`
- Default branch: `main`
- GitHub stores canonical code and validated run artifacts.
- Termux is the local controller.
- Google Colab is the execution engine.

## Supported routine runner

Use the complete script at `termux/run_fast_hybrid_pro_colab.sh`. The script:

1. Checks the existing Termux GitHub CLI login and configures Git's credential helper.
2. Clones or fast-forward-updates the canonical `main` branch without overwriting local modifications.
3. Installs the official Google Colab CLI if it is missing.
4. Uses the Colab CLI's local OAuth2 login/cache; no downloaded service-account JSON or `COLAB_ADC_JSON` GitHub secret is needed for this local path.
5. Creates a fresh CPU Colab session and uploads the existing production signal journal.
6. Runs the complete canonical notebook on Colab.
7. Checks notebook JSON, matching source/output cell counts, absence of code-cell errors, and required fresh outputs from Cell 12.34 and Cells 13.5, 13.6, and 13.7.
8. Downloads the updated journal and session log.
9. Pushes result files to `main` only after every validation passes.
10. Stops the Colab session on exit, including error exits.

A validated run can be started from Termux with:

```bash
mkdir -p ~/colab-automation
curl -fsSL https://raw.githubusercontent.com/worasak2530seed/fast-hybrid-pro/main/termux/run_fast_hybrid_pro_colab.sh -o ~/colab-automation/run_fast_hybrid_pro_colab.sh
bash ~/colab-automation/run_fast_hybrid_pro_colab.sh
```

The first direct Colab CLI OAuth2 login may ask the user to visit a Google URL and paste a one-time verification code. The token is cached locally by the CLI. This is an authentication consent step, not a research step. Do not put the token or credential files in GitHub.

## GitHub Actions boundary

The legacy workflow at `.github/workflows/run-fast-hybrid-pro-colab.yml` is manual-dispatch-only. Do not use it for routine research, and do not enable push triggers. The Termux script does not dispatch Actions.

## Research integrity

- No look-ahead bias.
- Explicit chronological train/validation/test separation.
- Portfolio capital and overlap constraints are audited.
- Trade-data integrity is checked before aggregation.
- Stress tests and optimization remain separate.
- Daily trading-date labels are normalized to `Asia/Bangkok`; naive exchange-date labels must not be shifted from UTC.
- Holding-period limits are measured in exchange trading sessions, not calendar days.
- Production parameters stay frozen unless a robust OOS promotion gate passes and the user approves promotion.
- Archived Cells 12.5–12.31 are historical only and must not be revived automatically.
