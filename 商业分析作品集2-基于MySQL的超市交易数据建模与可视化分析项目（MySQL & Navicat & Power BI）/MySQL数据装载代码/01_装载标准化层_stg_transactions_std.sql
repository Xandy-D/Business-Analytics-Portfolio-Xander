-- 切换到项目数据库
USE cba_supermarket_portfolio;

-- 清空标准化层表中的旧数据
TRUNCATE TABLE stg_transactions_std;

-- 向标准化层表中插入处理后的数据
INSERT INTO stg_transactions_std (
    raw_id,
    source_row_num,
    transaction_id_std,
    trx_ts,
    trx_date,
    trx_month,
    trx_year,
    trx_year_month,
    product_id_std,
    product_name_std,
    store_std,
    payment_method_std,
    customer_id_std,
    customer_type_std,
    quantity_num,
    unit_price_num,
    total_amount_num,
    calc_amount,
    amount_check_flag,
    row_fingerprint
)

-- 从原始层 raw_transactions 取数，并在取数的同时完成标准化处理
SELECT
    -- 保留原始层的主键，方便以后从标准化层回溯到原始层
    raw_id,

    -- 保留原 Excel 的原始行号，方便以后回到源文件定位问题行
    source_row_num,

    -- 对 transaction_id 去掉前后空格；如果去空格后变成空字符串，就转成 NULL
    NULLIF(TRIM(transaction_id), '') AS transaction_id_std,

    -- 把原始时间文本按固定格式解析成真正的 DATETIME
    STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y-%m-%d %H:%i:%s.%f') AS trx_ts,

    -- 在解析后的完整时间基础上，再提取“日期”部分
    DATE(STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y-%m-%d %H:%i:%s.%f')) AS trx_date,

    -- 在解析后的完整时间基础上，把月份统一成“当月第一天”，方便后面按月汇总
    CAST(DATE_FORMAT(STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-01') AS DATE) AS trx_month,

    -- 从解析后的时间里直接提取年份
    YEAR(STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y-%m-%d %H:%i:%s.%f')) AS trx_year,

    -- 从解析后的时间里生成“年-月”文本，方便展示和分组查看
    DATE_FORMAT(STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m') AS trx_year_month,

    -- 对商品编码去掉前后空格，并统一成小写；如果清洗后为空，则转成 NULL
    NULLIF(LOWER(TRIM(product_id_raw)), '') AS product_id_std,

    -- 对商品名称做三步标准化：去前后空格、转小写、把多个连续空格压成一个空格
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(product_name_raw)), '\\s+', ' '), '') AS product_name_std,

    -- 对门店名称做三步标准化：去前后空格、转小写、压缩多空格
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(store_raw)), '\\s+', ' '), '') AS store_std,

    -- 对支付方式做三步标准化：去前后空格、转小写、压缩多空格
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(payment_method_raw)), '\\s+', ' '), '') AS payment_method_std,

    -- 对客户ID去掉前后空格并统一小写；如果清洗后为空，则转成 NULL
    NULLIF(LOWER(TRIM(customer_id_raw)), '') AS customer_id_std,

    -- 对客户类型做三步标准化：去前后空格、转小写、压缩多空格
    NULLIF(REGEXP_REPLACE(LOWER(TRIM(customer_type_raw)), '\\s+', ' '), '') AS customer_type_std,

    -- 把原始数量文本转换成数值，方便后面做求和、平均和金额校验
    CAST(NULLIF(TRIM(quantity_raw), '') AS DECIMAL(10,2)) AS quantity_num,

    -- 把原始单价文本转换成数值，保留 4 位小数，方便后面精确计算
    CAST(NULLIF(TRIM(unit_price_raw), '') AS DECIMAL(12,4)) AS unit_price_num,

    -- 把原始总金额文本转换成数值，保留 2 位小数，作为后面核心经营指标的基础
    CAST(NULLIF(TRIM(total_amount_raw), '') AS DECIMAL(12,2)) AS total_amount_num,

    -- 用“数量 × 单价”重新计算金额，后面可以和原始总金额对比检查口径是否一致
    CAST(NULLIF(TRIM(quantity_raw), '') AS DECIMAL(10,2))
    * CAST(NULLIF(TRIM(unit_price_raw), '') AS DECIMAL(12,4)) AS calc_amount,

    -- 这句是金额校验标记：如果“原始总金额”和“数量 × 单价”的差异非常小就标记为 1，否则标记为 0
    CASE
        WHEN ABS(
            CAST(NULLIF(TRIM(total_amount_raw), '') AS DECIMAL(12,2))
            - (
                CAST(NULLIF(TRIM(quantity_raw), '') AS DECIMAL(10,2))
                * CAST(NULLIF(TRIM(unit_price_raw), '') AS DECIMAL(12,4))
            )
        ) < 0.0001 THEN 1
        ELSE 0
    END AS amount_check_flag,

    -- 这句是给每一行生成“行指纹”：把这一行所有关键原始字段拼起来，再做 SHA2 哈希
    SHA2(
        CONCAT_WS(
            '||',
            TRIM(transaction_id),
            TRIM(timestamp_raw),
            TRIM(quantity_raw),
            TRIM(product_id_raw),
            TRIM(product_name_raw),
            TRIM(unit_price_raw),
            TRIM(total_amount_raw),
            TRIM(store_raw),
            TRIM(payment_method_raw),
            TRIM(customer_id_raw),
            TRIM(customer_type_raw)
        ),
        256
    ) AS row_fingerprint

-- 数据来源于原始层 raw_transactions
FROM raw_transactions;