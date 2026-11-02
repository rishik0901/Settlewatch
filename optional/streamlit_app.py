"""
SettleWatch dashboard for Streamlit in Snowflake.

How to use:
  Snowsight > Projects > Streamlit > + Streamlit App
  Database SETTLEWATCH, schema MARTS, warehouse REPORTING_WH.
  Replace the example code with this file and click Run.
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session

session = get_active_session()

st.title("SettleWatch: Trade Settlement Monitor")


@st.cache_data(ttl=600)
def run(sql: str):
    return session.sql(sql).to_pandas()


tab_ops, tab_cost = st.tabs(["Settlement operations", "Snowflake cost"])

with tab_ops:
    brokers = run("select broker_name from SETTLEWATCH.MARTS.DIM_BROKER order by 1")
    picked = st.multiselect("Brokers", brokers["BROKER_NAME"].tolist())
    broker_filter = ""
    if picked:
        names = ", ".join("'" + b.replace("'", "''") + "'" for b in picked)
        broker_filter = f"where broker_name in ({names})"

    daily = run(f"""
        select trade_date,
               sum(total_trades)  as total_trades,
               sum(failed_trades) as failed_trades,
               round(100 * sum(failed_trades) / sum(total_trades), 2) as fail_rate_pct
        from SETTLEWATCH.MARTS.RPT_DAILY_FAILS
        {broker_filter}
        group by trade_date
        order by trade_date
    """)

    c1, c2, c3 = st.columns(3)
    c1.metric("Trades", f"{int(daily['TOTAL_TRADES'].sum()):,}")
    c2.metric("Failed trades", f"{int(daily['FAILED_TRADES'].sum()):,}")
    overall = 100 * daily["FAILED_TRADES"].sum() / max(daily["TOTAL_TRADES"].sum(), 1)
    c3.metric("Fail rate", f"{overall:.2f}%")

    st.subheader("Daily fail rate (%)")
    st.line_chart(daily, x="TRADE_DATE", y="FAIL_RATE_PCT")

    st.subheader("Broker scorecard")
    st.dataframe(
        run("""
            select broker_name, region, total_trades, failed_trades,
                   fail_rate_pct, needs_review
            from SETTLEWATCH.MARTS.RPT_BROKER_SCORECARD
            order by fail_rate_pct desc
        """),
        use_container_width=True,
    )

    st.subheader("Why trades fail")
    reasons = run("""
        select fail_reason, sum(failed_trades) as failed_trades
        from SETTLEWATCH.MARTS.RPT_FAIL_REASONS
        group by fail_reason
        order by failed_trades desc
    """)
    st.bar_chart(reasons, x="FAIL_REASON", y="FAILED_TRADES")

with tab_cost:
    st.caption("Needs a role that can read SNOWFLAKE.ACCOUNT_USAGE (for example ACCOUNTADMIN).")
    try:
        credits = run("""
            select date_trunc(day, start_time)::date as usage_day,
                   warehouse_name,
                   round(sum(credits_used), 3)       as credits_used
            from SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
            where start_time >= dateadd(day, -30, current_timestamp())
            group by 1, 2
            order by 1
        """)
        st.subheader("Credits per day, last 30 days")
        st.bar_chart(credits, x="USAGE_DAY", y="CREDITS_USED", color="WAREHOUSE_NAME")
        st.metric("Total credits (30 days)", f"{credits['CREDITS_USED'].sum():.2f}")
    except Exception as e:  # role has no access to ACCOUNT_USAGE
        st.warning(f"Could not read cost data: {e}")
