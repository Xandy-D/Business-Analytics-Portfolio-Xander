-- 切换到项目数据库
USE cba_supermarket_portfolio;

-- 清空清洗层表中的旧数据
TRUNCATE TABLE stg_transactions_clean;

-- 向清洗层表中插入经过筛选后的干净数据
INSERT INTO stg_transactions_clean (
    std_id,
    raw_id,
    source_row_num,
    transaction_id,
    trx_ts,
    trx_date,
    trx_month,
    trx_year,
    trx_year_month,
    product_id,
    product_name,
    store_name,
    payment_method,
    customer_id,
    customer_type,
    quantity,
    unit_price,
    total_amount,
    calc_amount,
    amount_check_flag,
    row_fingerprint
)

-- 从标准化层 stg_transactions_std 取数
SELECT
    -- 保留标准化层主键
    std_id,

    -- 保留原始层主键
    raw_id,

    -- 保留原 Excel 行号
    source_row_num,

    -- 把标准化后的交易ID写入 clean 层
    transaction_id_std AS transaction_id,

    -- 把标准化后的完整交易时间写入 clean 层
    trx_ts,

    -- 把标准化后的交易日期写入 clean 层
    trx_date,

    -- 把标准化后的交易月份写入 clean 层
    trx_month,

    -- 把标准化后的交易年份写入 clean 层
    trx_year,

    -- 把标准化后的“年-月”文本写入 clean 层
    trx_year_month,

    -- 把标准化后的商品编码写入 clean 层
    product_id_std AS product_id,

    -- 把标准化后的商品名称写入 clean 层
    product_name_std AS product_name,

    -- 把标准化后的门店名称写入 clean 层
    store_std AS store_name,

    -- 把标准化后的支付方式写入 clean 层
    payment_method_std AS payment_method,

    -- 把标准化后的客户ID写入 clean 层
    customer_id_std AS customer_id,

    -- 把标准化后的客户类型写入 clean 层
    customer_type_std AS customer_type,

    -- 把标准化后的数量写入 clean 层
    quantity_num AS quantity,

    -- 把标准化后的单价写入 clean 层
    unit_price_num AS unit_price,

    -- 把标准化后的总金额写入 clean 层
    total_amount_num AS total_amount,

    -- 把“数量 × 单价”的重算金额写入 clean 层
    calc_amount,

    -- 把金额校验标记写入 clean 层
    amount_check_flag,

    -- 这句把行指纹写入 clean 层
    row_fingerprint

-- 说明数据来源于标准化层
FROM stg_transactions_std

-- 定义清洗规则
WHERE 1 = 1

    -- 交易ID不能为空
    AND transaction_id_std IS NOT NULL

    -- 交易时间不能为空
    AND trx_ts IS NOT NULL

    -- 商品编码不能为空
    AND product_id_std IS NOT NULL

    -- 商品名称不能为空
    AND product_name_std IS NOT NULL

    -- 门店名称不能为空
    AND store_std IS NOT NULL

    -- 支付方式不能为空
    AND payment_method_std IS NOT NULL

    -- 客户类型不能为空
    AND customer_type_std IS NOT NULL

    -- 数量不能为空
    AND quantity_num IS NOT NULL

    -- 数量必须大于 0
    AND quantity_num > 0

    -- 单价不能为空
    AND unit_price_num IS NOT NULL

    -- 单价不能小于 0
    AND unit_price_num >= 0

    -- 总金额不能为空
    AND total_amount_num IS NOT NULL

    -- 总金额不能小于 0
    AND total_amount_num >= 0;