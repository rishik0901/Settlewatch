"""
Generate fake equity trade data for the SettleWatch project.

Writes three CSV files into ../data/ (or the folder you pass with --out):
  stocks.csv   - one row per stock (symbol, company, sector, exchange)
  brokers.csv  - one row per broker / clearing member
  trades.csv   - one row per trade, with T+1 settlement and ~5% fails

Uses only the Python standard library, so there is nothing to install.

Usage:
  python generate_trades.py                    # 100,000 trades (default)
  python generate_trades.py --trades 500000    # more trades
  python generate_trades.py --seed 7           # different random data
"""

import argparse
import csv
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path

STOCKS = [
    ("AAPL", "Apple Inc.", "Technology", "NASDAQ", 230.0),
    ("MSFT", "Microsoft Corp.", "Technology", "NASDAQ", 420.0),
    ("NVDA", "NVIDIA Corp.", "Technology", "NASDAQ", 130.0),
    ("AMZN", "Amazon.com Inc.", "Consumer Discretionary", "NASDAQ", 190.0),
    ("GOOGL", "Alphabet Inc.", "Communication Services", "NASDAQ", 170.0),
    ("META", "Meta Platforms Inc.", "Communication Services", "NASDAQ", 560.0),
    ("JPM", "JPMorgan Chase & Co.", "Financials", "NYSE", 220.0),
    ("BAC", "Bank of America Corp.", "Financials", "NYSE", 40.0),
    ("GS", "Goldman Sachs Group Inc.", "Financials", "NYSE", 510.0),
    ("V", "Visa Inc.", "Financials", "NYSE", 280.0),
    ("JNJ", "Johnson & Johnson", "Health Care", "NYSE", 160.0),
    ("PFE", "Pfizer Inc.", "Health Care", "NYSE", 29.0),
    ("XOM", "Exxon Mobil Corp.", "Energy", "NYSE", 115.0),
    ("CVX", "Chevron Corp.", "Energy", "NYSE", 150.0),
    ("WMT", "Walmart Inc.", "Consumer Staples", "NYSE", 80.0),
    ("KO", "Coca-Cola Co.", "Consumer Staples", "NYSE", 70.0),
    ("DIS", "Walt Disney Co.", "Communication Services", "NYSE", 95.0),
    ("BA", "Boeing Co.", "Industrials", "NYSE", 165.0),
    ("CAT", "Caterpillar Inc.", "Industrials", "NYSE", 360.0),
    ("TSLA", "Tesla Inc.", "Consumer Discretionary", "NASDAQ", 250.0),
]

# (broker_id, broker_name, region, fail_tendency)
# fail_tendency makes some brokers fail more often, so the reports have
# something interesting to find.
BROKERS = [
    ("BRK001", "Atlas Securities", "US-East", 0.02),
    ("BRK002", "Beacon Capital Markets", "US-East", 0.03),
    ("BRK003", "Cedar Street Brokerage", "US-West", 0.04),
    ("BRK004", "Delta Clearing LLC", "US-Central", 0.05),
    ("BRK005", "Evergreen Trading", "US-West", 0.05),
    ("BRK006", "Fulton Prime Services", "US-East", 0.06),
    ("BRK007", "Granite Financial", "US-Central", 0.08),
    ("BRK008", "Harbor Point Securities", "US-East", 0.12),
]

FAIL_REASONS = [
    "INSUFFICIENT_SHARES",
    "LATE_INSTRUCTIONS",
    "QUANTITY_MISMATCH",
    "INSUFFICIENT_FUNDS",
    "MISSING_SSI",
]


def next_business_day(d: date) -> date:
    """T+1: the next weekday after d (holidays ignored to keep it simple)."""
    d += timedelta(days=1)
    while d.weekday() >= 5:  # 5 = Saturday, 6 = Sunday
        d += timedelta(days=1)
    return d


def business_days(start: date, end: date) -> list[date]:
    days = []
    d = start
    while d <= end:
        if d.weekday() < 5:
            days.append(d)
        d += timedelta(days=1)
    return days


def write_csv(path: Path, header: list[str], rows) -> int:
    count = 0
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        for row in rows:
            writer.writerow(row)
            count += 1
    return count


def generate_trades(n: int, trading_days: list[date], rng: random.Random):
    # One fixed pool of accounts per broker, 12-digit account numbers.
    accounts = {
        b[0]: [f"{rng.randint(10**11, 10**12 - 1)}" for _ in range(200)] for b in BROKERS
    }
    broker_weights = [5, 5, 4, 4, 3, 3, 2, 2]

    for i in range(1, n + 1):
        symbol, _, _, _, base_price = rng.choice(STOCKS)
        broker_id, _, _, fail_tendency = rng.choices(BROKERS, weights=broker_weights)[0]
        trade_date = rng.choice(trading_days)

        # Market hours 09:30 to 16:00
        seconds = rng.randint(9 * 3600 + 1800, 16 * 3600)
        trade_ts = datetime.combine(trade_date, time()) + timedelta(seconds=seconds)

        side = rng.choice(["BUY", "SELL"])
        quantity = rng.choice([10, 25, 50, 100, 200, 500, 1000, 2500, 5000])
        price = round(base_price * rng.uniform(0.9, 1.1), 2)
        settle_date = next_business_day(trade_date)

        # Trades made late in the day fail a bit more often (late instructions).
        fail_chance = fail_tendency + (0.03 if trade_ts.hour >= 15 else 0.0)
        if rng.random() < fail_chance:
            status = "FAILED"
            fail_reason = rng.choice(FAIL_REASONS)
        else:
            status = "SETTLED"
            fail_reason = ""

        yield (
            f"T{i:010d}",
            trade_ts.strftime("%Y-%m-%d %H:%M:%S"),
            trade_date.isoformat(),
            settle_date.isoformat(),
            symbol,
            side,
            quantity,
            f"{price:.2f}",
            broker_id,
            rng.choice(accounts[broker_id]),
            status,
            fail_reason,
        )


def main():
    parser = argparse.ArgumentParser(description="Generate fake trade CSVs for SettleWatch.")
    parser.add_argument("--trades", type=int, default=100_000, help="number of trades (default 100000)")
    parser.add_argument("--start", default="2026-01-02", help="first trade date, YYYY-MM-DD")
    parser.add_argument("--end", default="2026-09-30", help="last trade date, YYYY-MM-DD")
    parser.add_argument("--seed", type=int, default=42, help="random seed, so runs are repeatable")
    parser.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "data"))
    args = parser.parse_args()

    rng = random.Random(args.seed)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    trading_days = business_days(date.fromisoformat(args.start), date.fromisoformat(args.end))

    n_stocks = write_csv(
        out / "stocks.csv",
        ["symbol", "company_name", "sector", "exchange"],
        (s[:4] for s in STOCKS),
    )
    n_brokers = write_csv(
        out / "brokers.csv",
        ["broker_id", "broker_name", "region"],
        (b[:3] for b in BROKERS),
    )
    n_trades = write_csv(
        out / "trades.csv",
        [
            "trade_id", "trade_ts", "trade_date", "settle_date", "symbol", "side",
            "quantity", "price", "broker_id", "account_number", "status", "fail_reason",
        ],
        generate_trades(args.trades, trading_days, rng),
    )
    print(f"Wrote {n_stocks} stocks, {n_brokers} brokers, {n_trades} trades to {out}")


if __name__ == "__main__":
    main()
