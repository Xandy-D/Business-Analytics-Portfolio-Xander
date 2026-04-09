-- 向门店维表插入去重后的门店名称
INSERT INTO dim_store (
    store_name
)
SELECT DISTINCT
    -- 取清洗层中的门店名称，作为门店维表的业务字段
    store_name
FROM stg_transactions_clean
WHERE 1 = 1
    -- 门店名称不能为空
    AND store_name IS NOT NULL
ORDER BY store_name;


-- 向客户类型维表插入去重后的客户类型
INSERT INTO dim_customer_type (
    customer_type
)
SELECT DISTINCT
    -- 取清洗层中的客户类型
    customer_type
FROM stg_transactions_clean
WHERE 1 = 1
    -- 要求客户类型不能为空
    AND customer_type IS NOT NULL
ORDER BY customer_type;


-- 向支付方式维表插入去重后的支付方式
INSERT INTO dim_payment_method (
    payment_method
)
SELECT DISTINCT
    -- 取清洗层中的支付方式
    payment_method
FROM stg_transactions_clean
WHERE 1 = 1
    -- 要求支付方式不能为空
    AND payment_method IS NOT NULL
ORDER BY payment_method;


-- 向商品名称维表插入去重后的商品名称
INSERT INTO dim_product_name (
    product_name
)
SELECT DISTINCT
    -- 取清洗层中的商品名称
    product_name
FROM stg_transactions_clean
WHERE 1 = 1
    -- 要求商品名称不能为空
    AND product_name IS NOT NULL
ORDER BY product_name;


-- 向商品维表插入商品编码，并通过商品名称去关联商品名称维表
INSERT INTO dim_product (
    product_id,
    product_name_key,
    product_name
)
SELECT DISTINCT
    -- 写入商品编码
    c.product_id,

    -- 写入商品名称维表里的代理键
    pn.product_name_key,

    -- 保留商品名称文本，便于查看和调试
    c.product_name
FROM stg_transactions_clean c
INNER JOIN dim_product_name pn
    -- 用商品名称把 clean 层和商品名称维表连起来
    ON c.product_name = pn.product_name
WHERE 1 = 1
    -- 商品编码不能为空
    AND c.product_id IS NOT NULL
    -- 商品名称不能为空
    AND c.product_name IS NOT NULL
ORDER BY c.product_id;


-- 向日期维表插入清洗层里出现过的所有日期
INSERT INTO dim_calendar (
    date_key,
    calendar_date,
    year_num,
    month_num,
    trx_year_month,
    month_start_date,
    quarter_num
)
SELECT DISTINCT
    -- 把日期转成 YYYYMMDD 形式的整数，作为日期键
    CAST(DATE_FORMAT(trx_date, '%Y%m%d') AS UNSIGNED) AS date_key,

    -- 写入原始日期
    trx_date AS calendar_date,

    -- 提取年份
    YEAR(trx_date) AS year_num,

    -- 提取月份
    MONTH(trx_date) AS month_num,

    -- 生成 YYYY-MM 形式的年月文本
    DATE_FORMAT(trx_date, '%Y-%m') AS trx_year_month,

    -- 把月份统一映射到该月第一天
    CAST(DATE_FORMAT(trx_date, '%Y-%m-01') AS DATE) AS month_start_date,

    -- 计算季度
    QUARTER(trx_date) AS quarter_num
FROM stg_transactions_clean
WHERE 1 = 1
    -- 要求交易日期不能为空
    AND trx_date IS NOT NULL
ORDER BY trx_date;