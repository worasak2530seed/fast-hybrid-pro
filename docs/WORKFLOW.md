# Fast Hybrid Pro — Direct Colab Workflow

## Roles

- **GitHub:** canonical source and validated structured result artifacts.
- **Google Colab:** the only environment used to run the research notebook.
- **Termux:** watches the published GitHub status and sends Telegram notifications only.

## One-time Colab setup

1. Open the canonical notebook:
   https://colab.research.google.com/github/worasak2530seed/fast-hybrid-pro/blob/main/Fast_Hybrid_Pro.ipynb
2. In Colab Secrets, create \`FAST_HYBRID_GITHUB_TOKEN\` using a fine-grained token restricted to \`worasak2530seed/fast-hybrid-pro\`, with **Contents: Read and write** permission. Enable notebook access for that secret.
3. Do not print, paste into a code cell, or commit the token. The notebook retrieves it from Colab Secrets.
4. Use **Runtime → Run all**.

## Run lifecycle

1. The first code cell validates GitHub access and publishes \`results/run_reports/latest_run_status.json\` with status \`RUNNING\`. If credentials are missing or GitHub write access is unavailable, execution stops before research begins.
2. A post-cell error handler attempts to publish \`FAILED\` with a short redacted error summary.
3. The final cell runs only after prior cells have completed without errors. It publishes a run-specific JSON summary and updates \`latest_run_summary.json\`.
4. Available CSV artifacts include True Global Portfolio stress results and trades, risk/capacity sensitivity, loss attribution, nested OOS filters, partial-profit OOS, trend/MACD/stop ablation, MACD lead/warning event-study summary and shortlist, and the production signal journal.
5. Status becomes \`SUCCESS\` only after the report artifacts have been published. Research diagnostics do not automatically modify Production settings.

The Colab runtime cannot directly read the browser's saved interactive notebook file, so the structured reports and CSVs are published automatically; use Colab's Drive save option if a fully rendered notebook copy is also required.

## Termux notification watcher

Run:

\`\`\`bash
bash "$HOME/colab-automation/fast-hybrid-pro/termux/watch_colab_status.sh"
\`\`\`

Leave it running while Colab executes. It polls GitHub every 30 seconds and sends one Telegram message per run state (RUNNING, SUCCESS, FAILED), using the existing \`TELEGRAM_BOT_TOKEN\` and \`TELEGRAM_CHAT_ID\` environment variables. It does not launch a notebook, run research, or push results.

For backward compatibility, \`termux/run_fast_hybrid_pro_colab.sh\` now delegates to this watcher only.

## Safety and research integrity

- Never run the research notebook from Termux.
- Do not use GitHub Actions for routine research execution.
- Do not promote exploratory full-history results as independent OOS evidence.
- Preserve chronological splits, capital/overlap constraints, realistic costs, slippage, and gap-loss stress.
- Keep Production parameters frozen unless the predefined OOS promotion gate passes and the user explicitly approves a change.
