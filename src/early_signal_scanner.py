"""Fast Hybrid Pro standalone early-signal scanner.

This module is intentionally isolated from the frozen Production strategy.
It does not place orders, simulate trades, calculate ATR stops, or run backtests.

Expected input:
- Daily OHLCV DataFrame indexed by trading date.
- Metadata mapping with Market, Sector, MarketCapMBaht,
  Total20TradingValueMBaht (total across the latest 20 sessions).

Dependencies: pandas, numpy.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Mapping

import numpy as np
import pandas as pd


@dataclass(frozen=True)
class ScannerConfig:
    macd_fast: int = 4
    macd_slow: int = 12
    macd_signal: int = 9
    stoch_window: int = 8
    stoch_smooth_k: int = 3
    stoch_smooth_d: int = 3
    ema_fast: int = 5
    ema_mid: int = 10
    ema_long: int = 75
    bb_window: int = 20
    bb_std: float = 2.0
    kc_atr_window: int = 14
    kc_multiplier: float = 1.5
    squeeze_lookback: int = 10
    minimum_score: int = 3
    target1_pct: float = 0.07
    target2_pct: float = 0.15
    max_holding_days_reference: int = 20


CONFIG = ScannerConfig()
ALLOWED_MARKETS = frozenset({"SET", "MAI"})
EXCLUDED_SECTORS = frozenset(
    {"BANK", "FIN", "INSUR", "PF&REIT", "PROP", "TOURISM"}
)
REQUIRED_OHLCV = ("Open", "High", "Low", "Close", "Volume")


def _number(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return float("nan")


def universe_status(metadata: Mapping[str, Any], close: float) -> tuple[bool, str]:
    """Return whether a stock passes the confirmed scanner universe gate."""
    required = ("Market", "Sector", "MarketCapMBaht", "Total20TradingValueMBaht")
    if any(key not in metadata or pd.isna(metadata[key]) for key in required):
        return False, "DATA_INCOMPLETE"

    market = str(metadata["Market"]).strip().upper()
    sector = str(metadata["Sector"]).strip().upper()
    market_cap = _number(metadata["MarketCapMBaht"])
    total20_value = _number(metadata["Total20TradingValueMBaht"])

    if market not in ALLOWED_MARKETS:
        return False, "MARKET_FILTER"
    if sector in EXCLUDED_SECTORS:
        return False, "SECTOR_EXCLUDED"
    if not np.isfinite(close) or not (1.0 <= close <= 80.0):
        return False, "PRICE_FILTER"
    if not np.isfinite(market_cap) or market_cap <= 5000.0:
        return False, "MARKET_CAP_FILTER"
    if not np.isfinite(total20_value) or total20_value <= 20.0:
        return False, "TOTAL20_VALUE_FILTER"
    return True, "UNIVERSE_PASS"


def calculate_indicators(ohlcv: pd.DataFrame, config: ScannerConfig = CONFIG) -> pd.DataFrame:
    """Calculate causal daily indicators; no future rows are used."""
    if ohlcv is None or ohlcv.empty:
        raise ValueError("OHLCV data is empty")

    df = ohlcv.copy()
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    df.columns = [str(c).strip().title() for c in df.columns]
    missing = [column for column in REQUIRED_OHLCV if column not in df.columns]
    if missing:
        raise ValueError(f"Missing OHLCV columns: {missing}")

    df = df.loc[:, ~df.columns.duplicated()]
    df = df[list(REQUIRED_OHLCV)].copy()
    df.index = pd.to_datetime(df.index)
    df = df[~df.index.duplicated(keep="last")].sort_index()
    for column in REQUIRED_OHLCV:
        df[column] = pd.to_numeric(df[column], errors="coerce")
    df = df.dropna(subset=["Open", "High", "Low", "Close", "Volume"])
    if df.empty:
        raise ValueError("No valid OHLCV rows after cleaning")

    close, high, low = df["Close"], df["High"], df["Low"]
    df["EMA5"] = close.ewm(span=config.ema_fast, adjust=False).mean()
    df["EMA10"] = close.ewm(span=config.ema_mid, adjust=False).mean()
    df["EMA75"] = close.ewm(span=config.ema_long, adjust=False).mean()

    fast = close.ewm(span=config.macd_fast, adjust=False).mean()
    slow = close.ewm(span=config.macd_slow, adjust=False).mean()
    df["MACD"] = fast - slow
    df["MACD_SIGNAL"] = df["MACD"].ewm(span=config.macd_signal, adjust=False).mean()
    df["MACD_HIST"] = df["MACD"] - df["MACD_SIGNAL"]

    lowest = low.rolling(config.stoch_window, min_periods=config.stoch_window).min()
    highest = high.rolling(config.stoch_window, min_periods=config.stoch_window).max()
    span = (highest - lowest).replace(0, np.nan)
    raw_k = 100.0 * (close - lowest) / span
    df["STOCH_K"] = raw_k.rolling(config.stoch_smooth_k, min_periods=config.stoch_smooth_k).mean()
    df["STOCH_D"] = df["STOCH_K"].rolling(config.stoch_smooth_d, min_periods=config.stoch_smooth_d).mean()

    bb_mid = close.rolling(config.bb_window, min_periods=config.bb_window).mean()
    bb_std = close.rolling(config.bb_window, min_periods=config.bb_window).std()
    df["BB_MID"] = bb_mid
    df["BB_UPPER"] = bb_mid + config.bb_std * bb_std
    df["BB_LOWER"] = bb_mid - config.bb_std * bb_std

    # ATR is calculated only as the conventional Keltner Channel width input.
    # It is not exposed as an ATR stop, score factor, or entry/exit rule.
    prev_close = close.shift(1)
    true_range = pd.concat(
        [(high - low), (high - prev_close).abs(), (low - prev_close).abs()],
        axis=1,
    ).max(axis=1)
    kc_atr = true_range.ewm(
        alpha=1.0 / config.kc_atr_window,
        adjust=False,
        min_periods=config.kc_atr_window,
    ).mean()
    # Conventional Keltner Channel uses an EMA centerline (unlike BB's SMA centerline).
    kc_mid = close.ewm(span=config.bb_window, adjust=False).mean()
    df["KC_MID"] = kc_mid
    df["KC_UPPER"] = kc_mid + config.kc_multiplier * kc_atr
    df["KC_LOWER"] = kc_mid - config.kc_multiplier * kc_atr
    df["SQUEEZE"] = (
        (df["BB_UPPER"] <= df["KC_UPPER"])
        & (df["BB_LOWER"] >= df["KC_LOWER"])
    ).fillna(False)
    df["SQUEEZE_RELEASE"] = (
        (~df["SQUEEZE"]) & df["SQUEEZE"].shift(1, fill_value=False)
    )
    df["SQUEEZE_RECENT"] = (
        df["SQUEEZE"].rolling(config.squeeze_lookback, min_periods=1).max().astype(bool)
    )

    # Weekly EMA values are informational only. A completed Friday bar is made
    # available from the following Monday to avoid using the current week's close.
    weekly = df[["Open", "High", "Low", "Close", "Volume"]].resample("W-FRI").agg(
        {"Open": "first", "High": "max", "Low": "min", "Close": "last", "Volume": "sum"}
    ).dropna(subset=["Close"])
    weekly["W_EMA5"] = weekly["Close"].ewm(span=5, adjust=False).mean()
    weekly["W_EMA10"] = weekly["Close"].ewm(span=10, adjust=False).mean()
    weekly_features = weekly[["W_EMA5", "W_EMA10"]].copy()
    weekly_features.index = weekly_features.index + pd.Timedelta(days=3)
    df = df.join(weekly_features.reindex(df.index.union(weekly_features.index)).sort_index().ffill().reindex(df.index))

    # Signal-date-only changes.
    df["HIST_RISING_2"] = (
        (df["MACD_HIST"] > df["MACD_HIST"].shift(1))
        & (df["MACD_HIST"].shift(1) > df["MACD_HIST"].shift(2))
    )
    df["MACD_CROSS_UP"] = (
        (df["MACD"] > df["MACD_SIGNAL"])
        & (df["MACD"].shift(1) <= df["MACD_SIGNAL"].shift(1))
    )
    df["MACD_CROSS_DOWN"] = (
        (df["MACD"] < df["MACD_SIGNAL"])
        & (df["MACD"].shift(1) >= df["MACD_SIGNAL"].shift(1))
    )
    df["PRICE_RECOVERY"] = (df["Close"] > df["EMA5"]) | (df["Close"] > df["Close"].shift(1))
    df["STOCH_BULL"] = (df["STOCH_K"] > df["STOCH_D"]) & (df["STOCH_K"] > df["STOCH_K"].shift(1))
    df["STOCH_BEAR"] = (df["STOCH_K"] < df["STOCH_D"]) & (df["STOCH_K"] < df["STOCH_K"].shift(1))
    df["HIST_FALLING_2"] = (
        (df["MACD_HIST"] < df["MACD_HIST"].shift(1))
        & (df["MACD_HIST"].shift(1) < df["MACD_HIST"].shift(2))
    )
    df["PRICE_BELOW_EMA5"] = df["Close"] < df["EMA5"]
    df["DOWN_VOLUME_CONTEXT"] = (df["Close"] < df["Close"].shift(1)) & (
        df["Volume"] > df["Volume"].shift(1)
    )

    # Score is transparent and bounded 0..5. No volume-ratio or ATR score.
    score_parts = {
        "Score_HistRising2": df["HIST_RISING_2"],
        "Score_MACDCrossUp": df["MACD_CROSS_UP"],
        "Score_PriceRecovery": df["PRICE_RECOVERY"],
        "Score_StochBull": df["STOCH_BULL"],
        "Score_SqueezeSupport": df["SQUEEZE_RELEASE"] | df["SQUEEZE_RECENT"],
    }
    for name, values in score_parts.items():
        df[name] = values.fillna(False).astype(bool)
    df["ENTRY_SCORE"] = pd.DataFrame(score_parts, index=df.index).fillna(False).astype(bool).sum(axis=1)

    # Early entry requires a rising MACD histogram; EMA alignment is deliberately not required.
    # The previous recovering/near-zero branches covered every possible histogram value,
    # so they were logically equivalent to HIST_RISING_2 and added no extra filter.
    df["EARLY_ENTRY"] = df["HIST_RISING_2"] & (df["ENTRY_SCORE"] >= config.minimum_score)

    # Early warning is informational only; it never issues a sell order.
    warning_evidence = (
        df["MACD_CROSS_DOWN"].astype(int)
        + df["HIST_FALLING_2"].astype(int)
        + df["PRICE_BELOW_EMA5"].astype(int)
        + df["STOCH_BEAR"].astype(int)
        + df["DOWN_VOLUME_CONTEXT"].astype(int)
    )
    df["WARNING_EVIDENCE_COUNT"] = warning_evidence
    df["EARLY_WARNING_LEVEL"] = np.select(
        [
            (df["MACD_CROSS_DOWN"] & (warning_evidence >= 2)) | (warning_evidence >= 3),
            (df["MACD_HIST"] > 0) & df["HIST_FALLING_2"] & (warning_evidence >= 1),
        ],
        ["WARNING", "WATCH"],
        default="",
    )
    return df


def scan_stock(
    symbol: str,
    ohlcv: pd.DataFrame,
    metadata: Mapping[str, Any],
    config: ScannerConfig = CONFIG,
) -> dict[str, Any]:
    """Scan one stock's latest completed daily bar and return an audit-friendly row."""
    indicators = calculate_indicators(ohlcv, config)
    row = indicators.iloc[-1]
    close = _number(row["Close"])
    passed, universe_reason = universe_status(metadata, close)
    entry = bool(row.get("EARLY_ENTRY", False)) if passed else False
    warning_level = str(row.get("EARLY_WARNING_LEVEL", "")) if passed else ""
    if warning_level.lower() == "nan":
        warning_level = ""

    return {
        "Symbol": str(symbol).strip().upper(),
        "Date": indicators.index[-1],
        "Close": close,
        "UniversePass": passed,
        "UniverseStatus": universe_reason,
        "EARLY_ENTRY": entry,
        "ENTRY_SCORE": int(row["ENTRY_SCORE"]) if pd.notna(row["ENTRY_SCORE"]) else None,
        "EARLY_WARNING": warning_level,
        "MACD": _number(row["MACD"]),
        "MACD_SIGNAL": _number(row["MACD_SIGNAL"]),
        "MACD_HIST": _number(row["MACD_HIST"]),
        "HIST_RISING_2": bool(row["HIST_RISING_2"]),
        "MACD_CROSS_UP": bool(row["MACD_CROSS_UP"]),
        "MACD_CROSS_DOWN": bool(row["MACD_CROSS_DOWN"]),
        "EMA5": _number(row["EMA5"]),
        "EMA10": _number(row["EMA10"]),
        "EMA75": _number(row["EMA75"]),
        "STOCH_K": _number(row["STOCH_K"]),
        "STOCH_D": _number(row["STOCH_D"]),
        "SQUEEZE": bool(row["SQUEEZE"]),
        "SQUEEZE_RELEASE": bool(row["SQUEEZE_RELEASE"]),
        "W_EMA5": _number(row["W_EMA5"]),
        "W_EMA10": _number(row["W_EMA10"]),
        "ReferenceTarget7Pct": close * (1.0 + config.target1_pct),
        "ReferenceTarget15Pct": close * (1.0 + config.target2_pct),
        "MaxHoldingDaysReference": config.max_holding_days_reference,
        "SignalReasons": _signal_reasons(row, entry, warning_level),
    }


def _signal_reasons(row: pd.Series, entry: bool, warning_level: str) -> str:
    reasons: list[str] = []
    if entry:
        if bool(row.get("HIST_RISING_2", False)):
            reasons.append("MACD Histogram rising for 2 bars")
        if bool(row.get("MACD_CROSS_UP", False)):
            reasons.append("MACD crossed above Signal")
        if bool(row.get("PRICE_RECOVERY", False)):
            reasons.append("price recovery / above EMA5")
        if bool(row.get("STOCH_BULL", False)):
            reasons.append("Stochastic bullish")
        if bool(row.get("SQUEEZE_RELEASE", False)):
            reasons.append("Squeeze release")
        elif bool(row.get("SQUEEZE_RECENT", False)):
            reasons.append("recent Squeeze support")
    if warning_level:
        if bool(row.get("MACD_CROSS_DOWN", False)):
            reasons.append("MACD crossed below Signal")
        if bool(row.get("HIST_FALLING_2", False)):
            reasons.append("MACD Histogram falling for 2 bars")
        if bool(row.get("PRICE_BELOW_EMA5", False)):
            reasons.append("Close below EMA5")
        if bool(row.get("STOCH_BEAR", False)):
            reasons.append("Stochastic weakening")
        if bool(row.get("DOWN_VOLUME_CONTEXT", False)):
            reasons.append("down close with higher volume than prior day")
    return "; ".join(dict.fromkeys(reasons)) if reasons else "No active signal"


def scan_universe(
    stock_data: Mapping[str, pd.DataFrame],
    metadata_by_symbol: Mapping[str, Mapping[str, Any]],
    config: ScannerConfig = CONFIG,
) -> pd.DataFrame:
    """Scan supplied stock data only; no network requests, backtests, or order execution."""
    rows = []
    for symbol, data in stock_data.items():
        metadata = metadata_by_symbol.get(symbol, {})
        try:
            rows.append(scan_stock(symbol, data, metadata, config))
        except Exception as exc:
            rows.append(
                {
                    "Symbol": str(symbol).strip().upper(),
                    "UniversePass": False,
                    "UniverseStatus": "SCAN_ERROR",
                    "EARLY_ENTRY": False,
                    "EARLY_WARNING": "",
                    "SignalReasons": f"{type(exc).__name__}: {exc}",
                }
            )
    if not rows:
        return pd.DataFrame()
    result = pd.DataFrame(rows)
    for column, default in (("EARLY_ENTRY", False), ("ENTRY_SCORE", np.nan), ("EARLY_WARNING", "")):
        if column not in result.columns:
            result[column] = default
    return result.sort_values(
        by=["EARLY_ENTRY", "ENTRY_SCORE", "EARLY_WARNING"],
        ascending=[False, False, False],
        na_position="last",
    ).reset_index(drop=True)
