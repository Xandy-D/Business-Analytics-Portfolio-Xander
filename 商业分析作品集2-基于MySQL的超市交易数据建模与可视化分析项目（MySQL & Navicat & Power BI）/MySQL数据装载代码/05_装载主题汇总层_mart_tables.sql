-- 清空客户类型汇总表旧数据
TRUNCATE TABLE mart_customer_type_summary;

-- 把事实表按客户类型汇总后写入客户类型汇总表
INSERT INTO mart_customer_type_summary (
    customer_type_key,
    customer_type,
    total_sales_amount,
    total_quantity,
    transaction_count,
    avg_ticket_amount,
    avg_purchase_qty
)
SELECT
    -- 客户类型维度键
    dct.customer_type_key,

    -- 客户类型文本
    dct.customer_type,

    -- 汇总该客户类型的总销售额
    SUM(fs.total_amount) AS total_sales_amount,

    -- 汇总该客户类型的总购买数量
    SUM(fs.quantity) AS total_quantity,

    -- 统计该客户类型的交易笔数
    COUNT(*) AS transaction_count,

    -- 计算该客户类型的平均每笔交易金额
    AVG(fs.total_amount) AS avg_ticket_amount,

    -- 计算该客户类型的平均购买数量
    AVG(fs.quantity) AS avg_purchase_qty
FROM fact_sales fs
INNER JOIN dim_customer_type dct
    -- 把事实表和客户类型维表按维度键连接起来
    ON fs.customer_type_key = dct.customer_type_key
GROUP BY
    dct.customer_type_key,
    dct.customer_type
ORDER BY
    total_sales_amount DESC;
    
  
-- 清空客户类型-支付方式汇总表旧数据
TRUNCATE TABLE mart_customer_payment_summary;

-- 把事实表按“客户类型 × 支付方式”汇总，再写入主题汇总表
INSERT INTO mart_customer_payment_summary (
    customer_type_key,
    customer_type,
    payment_method_key,
    payment_method,
    txn_count,
    payment_sales_amount,
    customer_type_total_sales,
    payment_sales_share,
    payment_usage_rank,
    is_top_payment_method
)
WITH base AS (
    -- 按“客户类型 × 支付方式”聚合交易次数和销售额
    SELECT
        fs.customer_type_key,
        dct.customer_type,
        fs.payment_method_key,
        dpm.payment_method,
        COUNT(*) AS txn_count,
        SUM(fs.total_amount) AS payment_sales_amount
    FROM fact_sales fs
    INNER JOIN dim_customer_type dct
        ON fs.customer_type_key = dct.customer_type_key
    INNER JOIN dim_payment_method dpm
        ON fs.payment_method_key = dpm.payment_method_key
    GROUP BY
        fs.customer_type_key,
        dct.customer_type,
        fs.payment_method_key,
        dpm.payment_method
),
ranked AS (
    -- 在 base 的基础上，用窗口函数生成客户类型总销售额和支付方式使用次数排名
    SELECT
        customer_type_key,
        customer_type,
        payment_method_key,
        payment_method,
        txn_count,
        payment_sales_amount,

        -- 按客户类型分组，求该客户类型下所有支付方式销售额之和
        SUM(payment_sales_amount) OVER (
            PARTITION BY customer_type_key
        ) AS customer_type_total_sales,

        -- 按客户类型分组、按交易次数降序排列，给支付方式编号
        ROW_NUMBER() OVER (
            PARTITION BY customer_type_key
            ORDER BY txn_count DESC, payment_sales_amount DESC, payment_method
        ) AS payment_usage_rank
    FROM base
)
SELECT
    -- 客户类型维度键
    customer_type_key,

    -- 客户类型文本
    customer_type,

    -- 支付方式维度键
    payment_method_key,

    -- 支付方式文本
    payment_method,

    -- 交易次数
    txn_count,

    -- 支付方式销售额
    payment_sales_amount,

    -- 客户类型总销售额
    customer_type_total_sales,

    -- 计算支付方式金额占比
    payment_sales_amount / NULLIF(customer_type_total_sales, 0) AS payment_sales_share,

    -- 写入支付方式使用次数排名
    payment_usage_rank,

    -- 把排名第 1 的支付方式标记为最常用支付方式
    CASE
        WHEN payment_usage_rank = 1 THEN 1
        ELSE 0
    END AS is_top_payment_method
FROM ranked
ORDER BY
    customer_type_key,
    payment_usage_rank;
    
    
-- 清空商品表现汇总表旧数据
TRUNCATE TABLE mart_product_performance;

-- 把事实表按商品名称汇总，再写入商品表现汇总表
INSERT INTO mart_product_performance (
    product_name_key,
    product_name,
    total_quantity,
    total_sales_amount,
    avg_selling_price,
    sales_rank_by_qty,
    sales_rank_by_amount,
    is_top10_by_qty,
    is_top10_by_amount
)
WITH base AS (
    -- 按商品名称汇总销量和销售额
    SELECT
        fs.product_name_key,
        dpn.product_name,
        SUM(fs.quantity) AS total_quantity,
        SUM(fs.total_amount) AS total_sales_amount
    FROM fact_sales fs
    INNER JOIN dim_product_name dpn
        ON fs.product_name_key = dpn.product_name_key
    GROUP BY
        fs.product_name_key,
        dpn.product_name
),
ranked AS (
    -- 这句在 base 的基础上，用窗口函数生成两个榜单的排名
    SELECT
        product_name_key,
        product_name,
        total_quantity,
        total_sales_amount,

        -- 计算平均成交单价
        total_sales_amount / NULLIF(total_quantity, 0) AS avg_selling_price,

        -- 按总销量降序排名
        ROW_NUMBER() OVER (
            ORDER BY total_quantity DESC, total_sales_amount DESC, product_name
        ) AS sales_rank_by_qty,

        -- 按总销售额降序排名
        ROW_NUMBER() OVER (
            ORDER BY total_sales_amount DESC, total_quantity DESC, product_name
        ) AS sales_rank_by_amount
    FROM base
)
SELECT
    -- 商品名称维度键
    product_name_key,

    -- 商品名称文本
    product_name,

    -- 总销量
    total_quantity,

    -- 总销售额
    total_sales_amount,

    -- 平均成交单价
    avg_selling_price,

    -- 按销量排名
    sales_rank_by_qty,

    -- 按销售额排名
    sales_rank_by_amount,

    -- 标记是否进入销量前十
    CASE
        WHEN sales_rank_by_qty <= 10 THEN 1
        ELSE 0
    END AS is_top10_by_qty,

    CASE
        WHEN sales_rank_by_amount <= 10 THEN 1
        ELSE 0
    END AS is_top10_by_amount
FROM ranked
ORDER BY
    sales_rank_by_amount;
    
    
-- 清空门店汇总表旧数据
TRUNCATE TABLE mart_store_summary;

-- 把事实表按门店汇总后写入门店汇总表
INSERT INTO mart_store_summary (
    store_key,
    store_name,
    total_sales_amount,
    transaction_count,
    store_sales_rank,
    store_sales_share,
    cumulative_sales_share,
    non_member_sales_amount,
    non_member_sales_share,
    cash_sales_amount,
    cash_sales_share,
    is_non_member_share_above_avg,
    is_cash_share_above_avg
)
WITH base AS (
    -- 按门店聚合基础指标
    SELECT
        fs.store_key,
        ds.store_name,
        SUM(fs.total_amount) AS total_sales_amount,
        COUNT(*) AS transaction_count,

        -- 累计非会员销售额
        SUM(
            CASE
                WHEN dct.customer_type = 'non-member' THEN fs.total_amount
                ELSE 0
            END
        ) AS non_member_sales_amount,

        -- 累计现金销售额
        SUM(
            CASE
                WHEN dpm.payment_method = 'cash' THEN fs.total_amount
                ELSE 0
            END
        ) AS cash_sales_amount
    FROM fact_sales fs
    INNER JOIN dim_store ds
        ON fs.store_key = ds.store_key
    INNER JOIN dim_customer_type dct
        ON fs.customer_type_key = dct.customer_type_key
    INNER JOIN dim_payment_method dpm
        ON fs.payment_method_key = dpm.payment_method_key
    GROUP BY
        fs.store_key,
        ds.store_name
),
ranked AS (
    -- 在 base 的基础上，用窗口函数计算排名、占比和累计占比
    SELECT
        store_key,
        store_name,
        total_sales_amount,
        transaction_count,
        non_member_sales_amount,
        cash_sales_amount,

        -- 计算门店销售额排名
        ROW_NUMBER() OVER (
            ORDER BY total_sales_amount DESC, store_name
        ) AS store_sales_rank,

        -- 计算门店销售额占整体销售额比例
        total_sales_amount / NULLIF(SUM(total_sales_amount) OVER (), 0) AS store_sales_share,

        -- 按销售额降序计算累计贡献占比
        SUM(total_sales_amount) OVER (
            ORDER BY total_sales_amount DESC, store_name
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / NULLIF(SUM(total_sales_amount) OVER (), 0) AS cumulative_sales_share,

        -- 计算非会员销售占比
        non_member_sales_amount / NULLIF(total_sales_amount, 0) AS non_member_sales_share,

        -- 计算现金销售占比
        cash_sales_amount / NULLIF(total_sales_amount, 0) AS cash_sales_share
    FROM base
),
final_calc AS (
    -- 这句在 ranked 的基础上，进一步拿整体平均做比较
    SELECT
        *,
        AVG(non_member_sales_share) OVER () AS avg_non_member_share_all_store,
        AVG(cash_sales_share) OVER () AS avg_cash_share_all_store
    FROM ranked
)
SELECT
    -- 门店维度键
    store_key,

    -- 门店名称
    store_name,

    -- 总销售额
    total_sales_amount,

    -- 交易笔数
    transaction_count,

    -- 门店销售额排名
    store_sales_rank,

    -- 门店销售额占比
    store_sales_share,

    -- 累计贡献占比
    cumulative_sales_share,

    -- 非会员销售额
    non_member_sales_amount,

    -- 非会员销售占比
    non_member_sales_share,

    -- 现金销售额
    cash_sales_amount,

    -- 现金销售占比
    cash_sales_share,

    -- 标记该门店非会员占比是否高于整体平均
    CASE
        WHEN non_member_sales_share > avg_non_member_share_all_store THEN 1
        ELSE 0
    END AS is_non_member_share_above_avg,

    -- 标记该门店现金占比是否高于整体平均
    CASE
        WHEN cash_sales_share > avg_cash_share_all_store THEN 1
        ELSE 0
    END AS is_cash_share_above_avg
FROM final_calc
ORDER BY
    store_sales_rank;
    
    
-- 清空门店月度销售汇总表旧数据
TRUNCATE TABLE mart_store_monthly_sales;

-- 把事实表汇总为“门店 × 月份”，再计算环比、同比、滚动均值和风险标记
INSERT INTO mart_store_monthly_sales (
    store_key,
    store_name,
    trx_month,
    trx_year_month,
    monthly_sales_amount,
    prev_month_sales,
    last_year_same_month_sales,
    mom_change_amount,
    mom_change_rate,
    yoy_change_amount,
    yoy_change_rate,
    rolling_3m_avg,
    is_down_vs_prev_month,
    is_down_2_months,
    is_below_rolling_3m_avg,
    is_latest_complete_month_flag
)
WITH monthly_base AS (
    -- 把事实表按“门店 × 月份”聚合为月销售额
    SELECT
        fs.store_key,
        ds.store_name,
        dc.month_start_date AS trx_month,
        dc.trx_year_month,
        SUM(fs.total_amount) AS monthly_sales_amount
    FROM fact_sales fs
    INNER JOIN dim_store ds
        ON fs.store_key = ds.store_key
    INNER JOIN dim_calendar dc
        ON fs.date_key = dc.date_key
    GROUP BY
        fs.store_key,
        ds.store_name,
        dc.month_start_date,
        dc.trx_year_month
),
windowed AS (
    -- 这句在 monthly_base 的基础上，用窗口函数取上月值、去年同月值和此前三个月均值
    SELECT
        store_key,
        store_name,
        trx_month,
        trx_year_month,
        monthly_sales_amount,

        -- 取同一家门店的上个月销售额
        LAG(monthly_sales_amount, 1) OVER (
            PARTITION BY store_key
            ORDER BY trx_month
        ) AS prev_month_sales,

        -- 取同一家门店去年同月销售额
        LAG(monthly_sales_amount, 12) OVER (
            PARTITION BY store_key
            ORDER BY trx_month
        ) AS last_year_same_month_sales,

        -- 计算此前三个月的滚动平均，不含当月
        AVG(monthly_sales_amount) OVER (
            PARTITION BY store_key
            ORDER BY trx_month
            ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AS rolling_3m_avg
    FROM monthly_base
),
calc AS (
    -- 在 windowed 的基础上计算环比、同比以及下降标记
    SELECT
        store_key,
        store_name,
        trx_month,
        trx_year_month,
        monthly_sales_amount,
        prev_month_sales,
        last_year_same_month_sales,

        -- 计算环比变动额
        monthly_sales_amount - prev_month_sales AS mom_change_amount,

        -- 计算环比变动率
        (monthly_sales_amount - prev_month_sales) / NULLIF(prev_month_sales, 0) AS mom_change_rate,

        -- 计算同比变动额
        monthly_sales_amount - last_year_same_month_sales AS yoy_change_amount,

        -- 计算同比变动率
        (monthly_sales_amount - last_year_same_month_sales) / NULLIF(last_year_same_month_sales, 0) AS yoy_change_rate,

        -- 写入此前三个月滚动平均
        rolling_3m_avg,

        -- 标记是否较上月下降
        CASE
            WHEN prev_month_sales IS NOT NULL AND monthly_sales_amount < prev_month_sales THEN 1
            ELSE 0
        END AS is_down_vs_prev_month
    FROM windowed
),
latest_month AS (
    -- 取全表最新的完整月份
    SELECT
        MAX(trx_month) AS latest_complete_month
    FROM calc
),
final_calc AS (
    -- 在 calc 的基础上继续计算“连续两个月下降”和“是否最近完整月”
    SELECT
        c.*,

        -- 取同一家门店上个月的“是否下降”标记
        LAG(is_down_vs_prev_month, 1) OVER (
            PARTITION BY store_key
            ORDER BY trx_month
        ) AS prev_down_flag,

        -- 把是否为最近完整月标记出来
        CASE
            WHEN c.trx_month = lm.latest_complete_month THEN 1
            ELSE 0
        END AS is_latest_complete_month_flag
    FROM calc c
    CROSS JOIN latest_month lm
)
SELECT
    -- 门店维度键
    store_key,

    -- 门店名称
    store_name,

    -- 月份起始日期
    trx_month,

    -- 年月文本
    trx_year_month,

    -- 月销售额
    monthly_sales_amount,

    -- 上月销售额
    prev_month_sales,

    -- 去年同月销售额
    last_year_same_month_sales,

    -- 环比变动额
    mom_change_amount,

    -- 环比变动率
    mom_change_rate,

    -- 同比变动额
    yoy_change_amount,

    -- 同比变动率
    yoy_change_rate,

    -- 此前三个月滚动平均
    rolling_3m_avg,

    -- 是否较上月下降
    is_down_vs_prev_month,

    -- 判断是否连续两个月下降：本月下降且上个月也下降
    CASE
        WHEN is_down_vs_prev_month = 1 AND prev_down_flag = 1 THEN 1
        ELSE 0
    END AS is_down_2_months,

    -- 判断本月是否低于此前三个月滚动平均
    CASE
        WHEN rolling_3m_avg IS NOT NULL AND monthly_sales_amount < rolling_3m_avg THEN 1
        ELSE 0
    END AS is_below_rolling_3m_avg,

    -- 是否最近完整月标记
    is_latest_complete_month_flag
FROM final_calc
ORDER BY
    store_key,
    trx_month;
    
    