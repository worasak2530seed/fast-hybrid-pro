"""Deterministic smoke tests for the isolated Fast Hybrid Pro scanner.

Run locally with: python -m pytest -q tests/test_early_signal_scanner.py
These are unit tests only; they do not backtest or download market data.
"""
import numpy as np
import pandas as pd
import pytest

from src.early_signal_scanner import (
    CONFIG,
    calculate_indicators,
    scan_stock,
    universe_status,
)


def sample_ohlcv(rows: int = 100) -> pd.DataFrame:
    dates = pd.bdate_range("2025-01-01", periods=rows)
    close = 20 + np.linspace(0, 2, rows) + 0.25 * np.sin(np.arange(rows) / 3)
    return pd.DataFrame(
        {
            "Open": close * 0.995,
            "High": close * 1.015,
            "Low": close * 0.985,
            "Close": close,
            "Volume": np.full(rows, 100_000.0),
        },
        index=dates,
    )


GOOD_META = {
    "Market": "mai",
    "Sector": "TECH",
    "MarketCapMBaht": 6000,
    "Total20TradingValueMBaht": 25,
}


def test_confirmed_config_and_removed_filters():
    assert (CONFIG.macd_fast, CONFIG.macd_slow, CONFIG.macd_signal) == (4, 12, 9)
    assert CONFIG.minimum_score == 3
    assert CONFIG.target1_pct == pytest.approx(0.07)
    assert CONFIG.target2_pct == pytest.approx(0.15)
    assert CONFIG.max_holding_days_reference == 20
    # No ATR stop or Volume MA5 ratio threshold exists in the public output/config.


@pytest.mark.parametrize(
    ("metadata", "close", "expected"),
    [
        (GOOD_META, 1.0, (True, "UNIVERSE_PASS")),
        (GOOD_META, 80.0, (True, "UNIVERSE_PASS")),
        ({**GOOD_META, "Market": "MAI"}, 20.0, (True, "UNIVERSE_PASS")),
        ({**GOOD_META, "MarketCapMBaht": 5000}, 20.0, (False, "MARKET_CAP_FILTER")),
        ({**GOOD_META, "Total20TradingValueMBaht": 20}, 20.0, (False, "TOTAL20_VALUE_FILTER")),
        ({**GOOD_META, "Sector": "BANK"}, 20.0, (False, "SECTOR_EXCLUDED")),
        ({**GOOD_META, "Sector": "PF&REIT"}, 20.0, (False, "SECTOR_EXCLUDED")),
        ({**GOOD_META, "Market": "NASDAQ"}, 20.0, (False, "MARKET_FILTER")),
        ({k: v for k, v in GOOD_META.items() if k != "MarketCapMBaht"}, 20.0, (False, "DATA_INCOMPLETE")),
        (GOOD_META, 0.99, (False, "PRICE_FILTER")),
        (GOOD_META, 80.01, (False, "PRICE_FILTER")),
    ],
)
def test_universe_gate(metadata, close, expected):
    assert universe_status(metadata, close) == expected


def test_indicator_calculation_is_complete_and_finite_after_warmup():
    result = calculate_indicators(sample_ohlcv())
    required = {
        "MACD", "MACD_SIGNAL", "MACD_HIST",
        "EMA5", "EMA10", "EMA75", "STOCH_K", "STOCH_D",
        "BB_UPPER", "BB_LOWER", "KC_UPPER", "KC_LOWER",
        "SQUEEZE", "W_EMA5", "W_EMA10", "ENTRY_SCORE",
        "EARLY_ENTRY", "EARLY_WARNING_LEVEL",
    }
    assert required.issubset(result.columns)
    assert result.index.is_monotonic_increasing
    assert result.index.is_unique
    assert result["MACD"].notna().all()
    assert result["ENTRY_SCORE"].between(0, 5).all()


def test_scanner_output_keeps_targets_reference_only_and_does_not_gate_on_volume_ratio():
    data = sample_ohlcv()
    result = scan_stock("TEST", data, GOOD_META)
    assert result["UniversePass"] is True
    assert result["ReferenceTarget7Pct"] == pytest.approx(result["Close"] * 1.07)
    assert result["ReferenceTarget15Pct"] == pytest.approx(result["Close"] * 1.15)
    assert result["MaxHoldingDaysReference"] == 20
    assert "VOLUME_MA5_RATIO" not in result
    assert "ATR_STOP" not in result


def test_incomplete_metadata_fails_closed():
    result = scan_stock("TEST", sample_ohlcv(), {})
    assert result["UniversePass"] is False
    assert result["UniverseStatus"] == "DATA_INCOMPLETE"
    assert result["EARLY_ENTRY"] is False
    assert result["EARLY_WARNING"] == ""


def test_empty_and_missing_ohlcv_raise_clear_errors():
    with pytest.raises(ValueError, match="OHLCV data is empty"):
        calculate_indicators(pd.DataFrame())
    with pytest.raises(ValueError, match="Missing OHLCV columns"):
        calculate_indicators(pd.DataFrame({"Close": [10]}, index=pd.to_datetime(["2025-01-01"])))
