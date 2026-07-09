SET @cstm_cd = '19951115';
SET @eigyosyo_cd = '00000001';
SET @month = '2027/01';

-- パフォーマンスを考慮し、WITH句で事前に対象データを絞り込み
WITH
unko_flat_filtered AS (
    SELECT *
    FROM taxicloud.unko_flat
    WHERE
        sales_month = @month
        AND cstm_cd = @cstm_cd
        AND eigyosyo_cd = @eigyosyo_cd
),
eigyo_flat_filtered AS (
    SELECT cstm_cd, eigyosyo_cd, jomuin_cd, sales_date, SUM(geisya_cnt) AS geisya_cnt
    FROM taxicloud.eigyo_flat
    WHERE
        sales_month = @month
        AND cstm_cd = @cstm_cd
        AND eigyosyo_cd = @eigyosyo_cd
    GROUP BY cstm_cd, eigyosyo_cd, jomuin_cd, sales_date
),
-- 前月の乗務員別・目標達成率を事前に集計する
previous_month_rates AS (
    SELECT
        cstm_cd,
        eigyosyo_cd,
        jomuin_cd,
        ROUND((SUM(soeisyu) / NULLIF(MAX(jomuin_target_month), 0)) * 100, 2) AS prev_achievement_rate
    FROM
        taxicloud.unko_flat
    WHERE
        sales_month = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(@month, '/01'), '%Y/%m/%d'), INTERVAL 1 MONTH), '%Y/%m')
        AND cstm_cd = @cstm_cd
        AND eigyosyo_cd = @eigyosyo_cd
    GROUP BY
        jomuin_cd
)

SELECT
    uf.jomuin_cd AS `対象乗務員コード`,
    jm.jomuin_nm AS `対象乗務員名`,

    -- ▼▼▼ 1. 目標達成率[％] の検証 ▼▼▼
    SUM(uf.soeisyu) AS `(1)_売上合計`,
    MAX(uf.jomuin_target_month) AS `(1)_月間目標`,
    ROUND((SUM(uf.soeisyu) / NULLIF(MAX(uf.jomuin_target_month), 0)) * 100, 2) AS `(1)_目標達成率_最終結果`,

    -- ▼▼▼ 2. 売上/時間[円] の検証 ▼▼▼
    SUM(uf.soeisyu) AS `(2)_売上合計`,
    SUM(ABS(TIMESTAMPDIFF(MINUTE, uf.nyuko_dtm, uf.syukko_dtm))) / 60 AS `(2)_乗務時間_時間`,
    ROUND(SUM(uf.soeisyu) / NULLIF(SUM(ABS(TIMESTAMPDIFF(MINUTE, uf.nyuko_dtm, uf.syukko_dtm))) / 60, 0)) AS `(2)_売上毎時_最終結果`,

    -- ▼▼▼ 3. 乗務時間[分] の検証 (元のSQLの定義通り) ▼▼▼
    SUM(ABS(TIMESTAMPDIFF(MINUTE, uf.nyuko_dtm, uf.syukko_dtm))) AS `(3)_乗務時間_分_最終結果`,

    -- ▼▼▼ 4. 実車率[％] の検証 ▼▼▼
    SUM(uf.sa_eigyosoko_km) AS `(4)_営業走行`,
    SUM(uf.sa_zensoko_km) AS `(4)_全走行`,
    ROUND(SUM(uf.sa_eigyosoko_km) / NULLIF(SUM(uf.sa_zensoko_km), 0) * 100, 2) AS `(4)_実車率_最終結果`,

    -- ▼▼▼ 5. キロ当たり収入[円] の検証 ▼▼▼
    SUM(uf.zeinuki_soeisyu) AS `(5)_税抜売上`,
    SUM(uf.sa_zensoko_km) AS `(5)_全走行`,
    ROUND(SUM(uf.zeinuki_soeisyu) / NULLIF(SUM(uf.sa_zensoko_km), 0), 2) AS `(5)_キロ当たり収入_最終結果`,

    -- ▼▼▼ 6. 実車キロ当たり収入[円] の検証 ▼▼▼
    SUM(uf.zeinuki_soeisyu) AS `(6)_税抜売上`,
    SUM(uf.sa_eigyosoko_km) AS `(6)_営業走行`,
    ROUND(SUM(uf.zeinuki_soeisyu) / NULLIF(SUM(uf.sa_eigyosoko_km), 0), 2) AS `(6)_実車キロ当たり収入_最終結果`,

    -- ▼▼▼ 7. 前月比（目標達成率）[ポイント] の検証 ▼▼▼
    ROUND((SUM(uf.soeisyu) / NULLIF(MAX(uf.jomuin_target_month), 0)) * 100, 2) AS `(7)_当月達成率`,
    pmr.prev_achievement_rate AS `(7)_前月達成率`,
    (ROUND((SUM(uf.soeisyu) / NULLIF(MAX(uf.jomuin_target_month), 0)) * 100, 2) - pmr.prev_achievement_rate) AS `(7)_前月比_最終結果`
    
FROM
    unko_flat_filtered uf
LEFT OUTER JOIN
    eigyo_flat_filtered efg
		ON uf.cstm_cd = efg.cstm_cd AND uf.eigyosyo_cd = efg.eigyosyo_cd AND uf.jomuin_cd = efg.jomuin_cd AND uf.sales_date = efg.sales_date
LEFT OUTER JOIN
	taxicloud.jomuin_mst jm
		ON uf.cstm_cd = jm.cstm_cd AND uf.eigyosyo_cd = jm.eigyosyo_cd AND uf.jomuin_cd = jm.jomuin_cd
LEFT OUTER JOIN
	taxicloud.kubun_mst km
		ON jm.kbn_cd = km.kbn_cd AND jm.cstm_cd = km.cstm_cd AND jm.eigyosyo_cd = km.eigyosyo_cd
LEFT OUTER JOIN
    previous_month_rates pmr 
    	ON uf.cstm_cd = pmr.cstm_cd AND uf.eigyosyo_cd = pmr.eigyosyo_cd AND uf.jomuin_cd = pmr.jomuin_cd
GROUP BY
	uf.jomuin_cd,
    jm.jomuin_nm,
    pmr.prev_achievement_rate
ORDER BY
	uf.jomuin_cd;