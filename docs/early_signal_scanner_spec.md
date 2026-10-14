# Fast Hybrid Pro — Early Signal Scanner

Status: isolated implementation draft; not connected to Production.

## Confirmed scanner configuration

- Market: SET and mai.
- Market capitalization: strictly greater than THB 5,000 million.
- Total traded value over the latest 20 trading sessions: strictly greater than THB 20 million (total, not per-day average).
- Latest close: THB 1–80 inclusive.
- Excluded sectors: BANK, FIN, INSUR, PF&REIT, PROP, TOURISM.
- MACD: 4/12/9.
- Daily EMA: 5/10/75; full EMA alignment is not required for early entry.
- Stochastic: 8/3/3.
- Bollinger Bands: 20 periods, 2 standard deviations.
- Keltner Channel multiplier: 1.5.
- Squeeze lookback: 10 bars, supporting factor only.
- Minimum early-entry score: 3 out of 5.
- Weekly EMA 5/10: display-only, never a gate.
- Reference targets: +7% and +15%.
- Maximum holding period: 20 days, displayed as reference only.
- No ATR stop, no ATR-based score, and no Volume MA5 ratio filter.
- Outputs: EARLY ENTRY and EARLY WARNING (WATCH/WARNING).

## Implementation notes

The module src/early_signal_scanner.py accepts OHLCV DataFrames and caller-supplied metadata. It performs no network requests, backtests, portfolio simulation, or order execution.

The Keltner Channel conventionally uses ATR to determine channel width. Therefore, the module calculates an internal ATR series solely to calculate Keltner Channel bounds and the optional Squeeze state. It does not expose ATR as a scan output, use ATR × 1.2, or use ATR for stop-loss or scoring. If “remove ATR” is intended to remove even this internal Keltner calculation, the Squeeze/Keltner definition would need to change; that is not done here because the approved specification keeps KC=1.5 and Squeeze as a supporting factor.

## Signal logic

### EARLY ENTRY
Five transparent score components (one point each):
1. MACD Histogram rises for two consecutive bars.
2. MACD crosses above its Signal line on the latest completed bar.
3. Price recovery: Close above EMA5 or above the prior Close.
4. Stochastic K > D and K is rising.
5. Squeeze release or Squeeze present within the latest 10 bars.

A candidate must show MACD Histogram improvement and have score >= 3. The scanner does not require Close > EMA5 > EMA10 > EMA75. The score is a rule-based prioritization score, not a claim of validated profitability.

### EARLY WARNING
- WATCH: positive MACD Histogram is falling for two consecutive bars.
- WARNING: MACD crosses below Signal with at least one other warning signal, or at least three warning signals are present.
- Additional warning evidence: Histogram falling for two bars, Close below EMA5, Stochastic weakening, and a down-close with volume above the prior day.
- Warnings are informational; no automatic sell action is performed.

## Data quality and limitations

- Missing required metadata fails closed as DATA_INCOMPLETE.
- The caller must provide the current market classification, sector, market cap (in THB millions), and total 20-session trading value (in THB millions). The module does not source or infer these values.
- Only completed daily bars should be passed for a stable end-of-day scan.
- Current market cap/classification is not point-in-time historical data; this scanner is not a survivorship-free historical research dataset.
- The target prices are close-based reference values, not guarantees or execution instructions.

## Validation scope

Permitted next validation: syntax/import check and small deterministic unit tests using synthetic OHLCV data. No backtest, parameter sweep, Production edit, notebook execution, or GitHub Actions run is part of this implementation.
