-- 切换到项目数据库
USE cba_supermarket_portfolio;

-- 清空事实表中的旧数据
TRUNCATE TABLE fact_sales;

-- 把清洗层明细通过各个维表映射后装入事实表
INSERT INTO fact_sales (
    clean_id,
    std_id,
    raw_id,
    transaction_id,
    customer_id,
    trx_ts,
    date_key,
    store_key,
    customer_type_key,
    payment_method_key,
    product_key,
    product_name_key,
    quantity,
    unit_price,
    total_amount,
    calc_amount,
    amount_check_flag
)

-- 从数据清洗层取数，并联接各个维表拿到代理键
SELECT
    -- 清洗层主键
    c.clean_id,

    -- 标准化层主键
    c.std_id,

    -- 原始层主键
    c.raw_id,

    -- 交易编号
    c.transaction_id,

    -- 客户编号
    c.customer_id,

    -- 完整交易时间
    c.trx_ts,

    -- 日期维度键
    dc.date_key,

    -- 门店维度键
    ds.store_key,

    -- 客户类型维度键
    dct.customer_type_key,

    -- 支付方式维度键
    dpm.payment_method_key,

    -- 商品编码维度键
    dp.product_key,

    -- 商品名称维度键
    dp.product_name_key,

    -- 数量度量
    c.quantity,

    -- 单价度量
    c.unit_price,

    -- 总金额度量
    c.total_amount,

    -- 重算金额
    c.calc_amount,

    -- 金额校验标记
    c.amount_check_flag

-- 说明主数据来源于清洗层
FROM stg_transactions_clean c

-- 门店名称关联门店维表
INNER JOIN dim_store ds
    ON c.store_name = ds.store_name

-- 客户类型关联客户类型维表
INNER JOIN dim_customer_type dct
    ON c.customer_type = dct.customer_type

-- 支付方式关联支付方式维表
INNER JOIN dim_payment_method dpm
    ON c.payment_method = dpm.payment_method

-- 商品编码关联商品维表
INNER JOIN dim_product dp
    ON c.product_id = dp.product_id

-- 交易日期关联日期维表
INNER JOIN dim_calendar dc
    ON c.trx_date = dc.calendar_date;
    
  