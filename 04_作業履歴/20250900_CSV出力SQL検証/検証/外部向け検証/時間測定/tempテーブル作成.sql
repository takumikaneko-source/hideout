

-- 測定結果を格納する一時テーブルを作成
CREATE TEMPORARY TABLE query_benchmark_results (
    id INT AUTO  _INCREMENT PRIMARY KEY,
    sql_type VARCHAR(50),          -- '乗務員別' or '日別'
    param_set VARCHAR(50),         -- 'パターン1' などの識別名
    run_count INT,                 -- 何回目の実行か (1-6)
    execution_time_sec DECIMAL(10, 6) -- 処理時間（秒）
);