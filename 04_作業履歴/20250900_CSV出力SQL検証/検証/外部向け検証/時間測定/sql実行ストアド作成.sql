-- ① プロシージャ作成
DELIMITER $$
CREATE PROCEDURE run_benchmark()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE start_time DATETIME(6);
    WHILE i <= 6 DO
        SET start_time = NOW(6);

        -- ▼▼▼ ここに【SET句】と【実行SQL】の両方を記述します ▼▼▼
        
        -- パラメータの宣言
        SET @crew_id = 123;
        SET @start_date = '2025-09-01';
        SET @end_date = '2025-09-07';

        -- 本体となるSQL（変数をそのまま使います）
        SELECT SQL_NO_CACHE * FROM your_table 
        WHERE crew_id = @crew_id AND some_date BETWEEN @start_date AND @end_date;
        
        -- ▲▲▲ 記述はここまで ▲▲▲

        INSERT INTO query_benchmark_results (sql_type, param_set, run_count, execution_time_sec)
        VALUES ('乗務員別', 'パターン1', i, TIMESTAMPDIFF(MICROSECOND, start_time, NOW(6)) / 1000000.0);
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

-- ② プロシージャ実行
CALL run_benchmark();

-- ③ 後片付け
DROP PROCEDURE run_benchmark;