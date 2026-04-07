"""
The Read - Analytics Dashboard
================================
A comprehensive analytics dashboard for the dbt synthetic data project.
Shows user analytics, transaction metrics, and engagement KPIs.

Usage:
    uv run streamlit run the_read_dashboard.py
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import duckdb

# Page configuration
st.set_page_config(
    page_title="The Read - Analytics Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded",
)

# Custom CSS for better styling
st.markdown(
    """
<style>
    /* Main content styling */
    .stApp {
        background-color: #ffffff;
    }
    
    /* KPI Metric styling - ensure text is visible */
    [data-testid="stMetricValue"] {
        color: #0d47a1 !important;
        font-weight: 700 !important;
        font-size: 1.8rem !important;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif !important;
    }
    
    [data-testid="stMetricLabel"] {
        color: #424242 !important;
        font-weight: 500 !important;
    }
    
    [data-testid="stMetricDelta"] {
        color: #00C853 !important;
    }
    
    /* Metric container styling */
    div[data-testid="stHorizontalBlock"] > div {
        background-color: #f5f5f5;
        padding: 15px;
        border-radius: 8px;
        border: 1px solid #e0e0e0;
    }
    
    /* Header styling */
    h1, h2, h3 {
        color: #1565c0 !important;
    }
    
    /* Ensure general text is visible */
    p, span, div {
        color: #333333;
    }
    
    /* Sidebar styling */
    [data-testid="stSidebar"] {
        background-color: #fafafa;
    }
</style>
""",
    unsafe_allow_html=True,
)


@st.cache_data
def load_data():
    """Load data from DuckDB database - using ONLY mart tables (final business-ready models)."""
    con = duckdb.connect("dbt_synthetic_data.duckdb")

    # Load from mart tables ONLY (final, business-ready models)
    users = con.execute("SELECT * FROM dim_users").df()
    products = con.execute("SELECT * FROM dim_products").df()
    transactions = con.execute("SELECT * FROM fct_transactions").df()
    daily_metrics = con.execute("SELECT * FROM fct_daily_metrics").df()
    user_activity = con.execute("SELECT * FROM fct_user_activity").df()
    sessions = con.execute("SELECT * FROM fct_sessions").df()

    con.close()

    return (
        users,
        products,
        transactions,
        daily_metrics,
        user_activity,
        sessions,
    )


def create_kpi_card(value, label, delta=None, delta_color="normal"):
    """Create a styled KPI card."""
    if delta:
        st.metric(
            label=f"**{label}**", value=value, delta=delta, delta_color=delta_color
        )
    else:
        st.metric(label=f"**{label}**", value=value)


def main():
    # Header
    st.title("📊 The Read")
    st.markdown("*Your window into the data*")
    st.divider()

    # Load data
    with st.spinner("Loading data..."):
        (
            users,
            products,
            transactions,
            daily_metrics,
            user_activity,
            sessions,
        ) = load_data()

    # Sidebar for filters
    st.sidebar.header("Filters")

    # Date range filter
    if "transaction_date" in transactions.columns:
        min_date = pd.to_datetime(transactions["transaction_date"]).min()
        max_date = pd.to_datetime(transactions["transaction_date"]).max()
        date_range = st.sidebar.date_input(
            "Date Range",
            value=(min_date, max_date),
            min_value=min_date,
            max_value=max_date,
        )

        if len(date_range) == 2:
            start_date, end_date = date_range
            transactions = transactions[
                (
                    pd.to_datetime(transactions["transaction_date"])
                    >= pd.to_datetime(start_date)
                )
                & (
                    pd.to_datetime(transactions["transaction_date"])
                    <= pd.to_datetime(end_date)
                )
            ]
            daily_metrics = daily_metrics[
                (pd.to_datetime(daily_metrics["date"]) >= pd.to_datetime(start_date))
                & (pd.to_datetime(daily_metrics["date"]) <= pd.to_datetime(end_date))
            ]

    # User tier filter
    if "user_tier" in users.columns:
        selected_tiers = st.sidebar.multiselect(
            "User Tier",
            options=users["user_tier"].unique(),
            default=users["user_tier"].unique(),
        )
        transactions = transactions[transactions["user_tier"].isin(selected_tiers)]

    # =====================
    # Overview Section
    # =====================
    st.header("Overview")

    # Calculate KPIs
    total_users = len(users)
    active_users = len(users[users["is_active"] == True])
    total_transactions = len(transactions)
    total_revenue = transactions[transactions["payment_status"] == "success"][
        "amount"
    ].sum()
    avg_order_value = transactions[transactions["payment_status"] == "success"][
        "amount"
    ].mean()

    # Display KPIs in columns
    col1, col2, col3, col4, col5 = st.columns(5)

    with col1:
        create_kpi_card(f"{total_users:,}", "Total Users")
    with col2:
        create_kpi_card(
            f"{active_users:,}",
            "Active Users",
            f"{active_users / total_users * 100:.1f}%",
        )
    with col3:
        create_kpi_card(f"{total_transactions:,}", "Transactions")
    with col4:
        create_kpi_card(f"${total_revenue:,.0f}", "Total Revenue")
    with col5:
        create_kpi_card(f"${avg_order_value:.2f}", "Avg Order Value")

    st.divider()

    # =====================
    # User Analytics Section
    # =====================
    st.header("User Analytics")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("User Growth Over Time")
        # Signup trend
        if "signup_date" in users.columns:
            signup_trend = (
                users.groupby(pd.to_datetime(users["signup_date"]).dt.to_period("M"))
                .size()
                .reset_index()
            )
            signup_trend.columns = ["Month", "Users"]
            signup_trend["Month"] = signup_trend["Month"].astype(str)

            fig = px.area(
                signup_trend, x="Month", y="Users", title="User Signups by Month"
            )
            fig.update_traces(fill="tozeroy", fillcolor="rgba(31, 119, 180, 0.3)")
            fig.update_layout(
                xaxis_title="Month",
                yaxis_title="Number of Users",
                showlegend=False,
                height=350,
            )
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("User Tier Distribution")
        if "user_tier" in users.columns:
            tier_counts = users["user_tier"].value_counts().reset_index()
            tier_counts.columns = ["Tier", "Count"]

            fig = px.pie(
                tier_counts,
                values="Count",
                names="Tier",
                hole=0.4,
                color="Tier",
                color_discrete_map={
                    "free": "#636EFA",
                    "premium": "#FECB52",
                    "enterprise": "#00CC96",
                },
            )
            fig.update_layout(height=350, showlegend=True)
            st.plotly_chart(fig, use_container_width=True)

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Users by Region")
        if "region" in transactions.columns:
            region_users = (
                transactions.groupby("region")["user_id"].nunique().reset_index()
            )
            region_users.columns = ["Region", "Unique Users"]
            region_users = region_users.sort_values("Unique Users", ascending=True)

            fig = px.bar(
                region_users,
                y="Region",
                x="Unique Users",
                orientation="h",
                color="Unique Users",
                color_continuous_scale="Blues",
            )
            fig.update_layout(
                yaxis_title="", xaxis_title="Unique Users", showlegend=False, height=350
            )
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Customer Value Segment")
        if "customer_value_segment" in user_activity.columns:
            segment_counts = (
                user_activity["customer_value_segment"].value_counts().reset_index()
            )
            segment_counts.columns = ["Segment", "Count"]

            fig = px.bar(
                segment_counts,
                x="Segment",
                y="Count",
                color="Segment",
                color_discrete_map={
                    "high_value": "#00CC96",
                    "medium_value": "#FECB52",
                    "low_value": "#FF6B6B",
                },
            )
            fig.update_layout(
                xaxis_title="",
                yaxis_title="Number of Users",
                showlegend=False,
                height=350,
            )
            st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # =====================
    # Transaction Analytics Section
    # =====================
    st.header("Transaction Analytics")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Revenue Trends")
        if "daily_revenue" in daily_metrics.columns and "date" in daily_metrics.columns:
            daily_metrics["date"] = pd.to_datetime(daily_metrics["date"])
            daily_metrics_sorted = daily_metrics.sort_values("date")

            fig = make_subplots(specs=[[{"secondary_y": True}]])

            fig.add_trace(
                go.Scatter(
                    x=daily_metrics_sorted["date"],
                    y=daily_metrics_sorted["daily_revenue"],
                    name="Daily Revenue",
                    line=dict(color="#1f77b4", width=2),
                ),
                secondary_y=False,
            )

            fig.add_trace(
                go.Bar(
                    x=daily_metrics_sorted["date"],
                    y=daily_metrics_sorted["transaction_count"],
                    name="Transaction Count",
                    marker_color="rgba(99, 110, 250, 0.3)",
                ),
                secondary_y=True,
            )

            fig.update_layout(
                title="Daily Revenue vs Transaction Count",
                xaxis_title="Date",
                height=400,
                legend=dict(orientation="h", yanchor="bottom", y=1.02),
            )
            fig.update_yaxes(title_text="Revenue ($)", secondary_y=False)
            fig.update_yaxes(title_text="Transactions", secondary_y=True)
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Payment Status Breakdown")
        if "payment_status" in transactions.columns:
            status_counts = transactions["payment_status"].value_counts().reset_index()
            status_counts.columns = ["Status", "Count"]

            fig = px.pie(
                status_counts,
                values="Count",
                names="Status",
                hole=0.4,
                color="Status",
                color_discrete_map={
                    "success": "#00CC96",
                    "failed": "#FF6B6B",
                    "pending": "#FECB52",
                },
            )
            fig.update_layout(height=400, showlegend=True)
            st.plotly_chart(fig, use_container_width=True)

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Revenue by Product Category")
        if "product_category" in transactions.columns:
            cat_revenue = (
                transactions[transactions["payment_status"] == "success"]
                .groupby("product_category")["amount"]
                .sum()
                .reset_index()
            )
            cat_revenue.columns = ["Category", "Revenue"]
            cat_revenue = cat_revenue.sort_values("Revenue", ascending=True)

            fig = px.bar(
                cat_revenue,
                y="Category",
                x="Revenue",
                orientation="h",
                color="Revenue",
                color_continuous_scale="Greens",
            )
            fig.update_layout(
                yaxis_title="", xaxis_title="Revenue ($)", showlegend=False, height=350
            )
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Average Order Value Trend")
        if (
            "daily_net_revenue" in daily_metrics.columns
            and "unique_transaction_users" in daily_metrics.columns
        ):
            daily_metrics["aov"] = daily_metrics["daily_net_revenue"] / daily_metrics[
                "unique_transaction_users"
            ].replace(0, pd.NA)

            fig = px.line(
                daily_metrics, x="date", y="aov", title="Average Order Value Over Time"
            )
            fig.update_layout(
                xaxis_title="Date", yaxis_title="AOV ($)", showlegend=False, height=350
            )
            fig.update_traces(line=dict(color="#1f77b4", width=2))
            st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # =====================
    # Engagement Analytics Section
    # =====================
    st.header("Engagement Analytics")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Session Duration Distribution")
        if "avg_session_duration" in daily_metrics.columns:
            fig = px.histogram(
                daily_metrics,
                x="avg_session_duration",
                nbins=30,
                title="Average Session Duration Distribution",
                color_discrete_sequence=["#636EFA"],
            )
            fig.update_layout(
                xaxis_title="Duration (minutes)",
                yaxis_title="Frequency",
                showlegend=False,
                height=350,
            )
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Events Per Session")
        if (
            "total_session_events" in daily_metrics.columns
            and "session_count" in daily_metrics.columns
        ):
            daily_metrics["events_per_session"] = daily_metrics[
                "total_session_events"
            ] / daily_metrics["session_count"].replace(0, pd.NA)

            fig = px.line(
                daily_metrics,
                x="date",
                y="events_per_session",
                title="Events Per Session Over Time",
            )
            fig.update_layout(
                xaxis_title="Date",
                yaxis_title="Events per Session",
                showlegend=False,
                height=350,
            )
            fig.update_traces(line=dict(color="#00CC96", width=2))
            st.plotly_chart(fig, use_container_width=True)

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Engagement Score Distribution")
        if "engagement_score" in user_activity.columns:
            fig = px.histogram(
                user_activity,
                x="engagement_score",
                nbins=50,
                title="User Engagement Score Distribution",
                color_discrete_sequence=["#FECB52"],
            )
            fig.update_layout(
                xaxis_title="Engagement Score",
                yaxis_title="Number of Users",
                showlegend=False,
                height=350,
            )
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("User Activity by Tier")
        if (
            "user_tier" in user_activity.columns
            and "engagement_score" in user_activity.columns
        ):
            tier_engagement = (
                user_activity.groupby("user_tier")["engagement_score"]
                .mean()
                .reset_index()
            )
            tier_engagement.columns = ["Tier", "Avg Engagement"]

            fig = px.bar(
                tier_engagement,
                x="Tier",
                y="Avg Engagement",
                color="Tier",
                color_discrete_map={
                    "free": "#636EFA",
                    "premium": "#FECB52",
                    "enterprise": "#00CC96",
                },
            )
            fig.update_layout(
                xaxis_title="",
                yaxis_title="Average Engagement Score",
                showlegend=False,
                height=350,
            )
            st.plotly_chart(fig, use_container_width=True)

    st.divider()

    # =====================
    # Device Analytics Section
    # =====================
    st.header("Device Analytics")

    col1, col2 = st.columns(2)

    with col1:
        st.subheader("Device Type Distribution")
        if "device_type" in sessions.columns:
            device_counts = sessions["device_type"].value_counts().reset_index()
            device_counts.columns = ["Device", "Sessions"]

            fig = px.pie(
                device_counts,
                values="Sessions",
                names="Device",
                hole=0.4,
                color="Device",
                color_discrete_map={
                    "mobile": "#636EFA",
                    "desktop": "#00CC96",
                    "tablet": "#FECB52",
                },
            )
            fig.update_layout(height=350, showlegend=True)
            st.plotly_chart(fig, use_container_width=True)

    with col2:
        st.subheader("Top Products by Revenue")
        if "product_name" in transactions.columns:
            top_products = (
                transactions[transactions["payment_status"] == "success"]
                .groupby("product_name")["amount"]
                .sum()
                .reset_index()
            )
            top_products.columns = ["Product", "Revenue"]
            top_products = top_products.sort_values("Revenue", ascending=False).head(10)

            fig = px.bar(
                top_products,
                y="Product",
                x="Revenue",
                orientation="h",
                color="Revenue",
                color_continuous_scale="Purples",
            )
            fig.update_layout(
                yaxis_title="", xaxis_title="Revenue ($)", showlegend=False, height=350
            )
            st.plotly_chart(fig, use_container_width=True)

    # Footer
    st.divider()
    st.markdown(
        "<div style='text-align: center; color: gray;'>"
        "Built with Streamlit | Data from dbt + DuckDB | The Read Analytics Dashboard"
        "</div>",
        unsafe_allow_html=True,
    )


if __name__ == "__main__":
    main()
