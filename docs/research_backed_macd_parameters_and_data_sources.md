# Research-backed MACD candidates and external data-source plan

Updated: 2026-10-12

## Decision

Keep Production frozen. The latest True Global Portfolio result is not investable evidence: with realistic friction it lost 63.89% of the initial THB 100,000, with profit factor 0.646 and maximum mark-to-market drawdown -69.23%. The gross portfolio also lost 43.38%, so friction is not the only problem. Parameter research must not be used to disguise a negative baseline.

## Published research and what it does (and does not) support

1. **Kang (2021), Journal of Risk and Financial Management, 14(1), 37.** “Improving MACD Technical Analysis by Optimizing Parameters and Modifying Trading Rules: Evidence from the Japanese Nikkei 225 Futures Market.” The study reports that traditional MACD (12,26,9) had negative performance on Nikkei 225 futures in 2011–2019, while selected optimized models were profitable. This is evidence that parameters can be market-dependent, not evidence that the same parameters will work on Thai individual equities. The paper tested 19,456 combinations; this also raises a multiple-testing/data-snooping concern that our OOS process must address.
   - Paper: https://www.mdpi.com/1911-8074/14/1/37
   - DOI: https://doi.org/10.3390/jrfm14010037

2. **Kang (2022), International Journal of Financial Research, 13(3), 1–24.** “Finding Optimal Parameter Values for the MACD Indicator: Evidence from the Japanese Nikkei 225 Futures Market Using a New Methodology.” The reported frequent high-performing region was fast EMA 3–8, slow EMA 18–25, signal EMA 3–8, with the slow period longer than the fast and signal periods. This is used only to define a small, pre-registered candidate set, not to declare a winner for SET stocks.
   - Paper: https://www.sciedu.ca/journal/index.php/ijfr/article/view/22118
   - DOI: https://doi.org/10.5430/ijfr.v13n3p1

3. **Kang's paper describes Appel's asymmetric settings** (8,17,9) for buy signals and (12,25,9) for sell signals; the widely used (12,26,9) is included as a conventional benchmark. The notebook tests these as symmetric long-only signal candidates for comparison only; this is not a claim that the original asymmetric rule has been reproduced.

4. **Zakamulin & Giner (2020), Quantitative Finance 20(6), 985–1007.** “Trend following with momentum versus moving averages: a tale of differences.” The paper finds that moving-average rules can be more robust to parameter changes than momentum rules under uncertain dynamics. This supports testing parameter neighborhoods and robustness, not choosing the best full-history return.
   - Paper: https://www.tandfonline.com/doi/full/10.1080/14697688.2020.1716057

5. **“Stock Market Efficiency and the MACD. Evidence from Countries around the World” (2015).** Uses out-of-sample simulations across 75 countries and 1,336 companies. Its broad coverage is useful context, but results are not a transferable parameter recommendation for Thai stocks.
   - Paper: https://www.sciencedirect.com/science/article/pii/S221256711501518X

## Candidate set to test in the canonical notebook

The new Cell 13.15 evaluates these predeclared candidates under the same trend, score threshold, stop, position sizing, portfolio-capacity rules, and realistic friction. It reports full-history diagnostics plus three chronological entry-date cohorts. It does not alter Production.

- Existing baselines: (4,12,9), (6,13,5)
- Historical Appel/conventional references: (8,17,9), (12,25,9), (12,26,9)
- Samples from the reported Kang (2022) parameter region: (3,18,3), (3,21,5), (5,21,5), (6,24,6), (8,25,8)
- Existing event-study reference: (8,21,5)

A candidate is not promoted because it has the best full-history P&L. A credible candidate must show positive net returns after costs across untouched chronological folds, acceptable drawdown and trade count, stability in nearby parameters, and a clear improvement over the same-engine baseline. Since the prior nested OOS filters and partial-profit tests failed, the burden of proof is high.

## Data sources and limitations

- **Current source: Yahoo Finance via yfinance.** Convenient and reproducible, but not an official SET historical database; ticker coverage, adjustments, delistings, and historical symbol mapping must be audited.
- **Primary Thai-market alternative: SET SMART Marketplace / SETSMART.** SET describes SMART Marketplace as an API-accessible service for SET/TFEX real-time/delayed, end-of-day/historical, and historical intraday data. Access and licensing may require a product/subscription. Use this as the preferred independent cross-check if an authorized API entitlement and credentials are available: https://www.set.or.th/th/services/connectivity-and-data/data/smart-marketplace
- **Do not silently mix data vendors.** Before comparing strategy results, align exchange calendar, adjusted/unadjusted prices, corporate actions, symbol changes, delisted names, timezone, and missing bars. Store vendor/source metadata and compare overlapping OHLCV bars.
- **Survivorship and point-in-time fundamentals remain material.** The current market-cap snapshot is not a historical point-in-time market-cap series. An authoritative historical-price feed alone does not remove survivorship bias; historical constituents and market-cap snapshots are also required.

No private or subscription database was queried from this environment. The current research step uses public paper metadata/full-text excerpts and adds a reproducible candidate test to run against the existing Colab data. It does not claim an independent SETSMART download without credentials.
