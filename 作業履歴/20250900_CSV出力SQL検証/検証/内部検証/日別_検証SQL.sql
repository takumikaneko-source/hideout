SET @cstm_cd = '19951115';
SET @eigyosyo_cd = '00000001';
SET @month = '2027/01';

WITH
eft AS (
    SELECT
        ef.cstm_cd,
        ef.eigyosyo_cd,
        ef.geisya_cnt,
        ef.sales_date 
    FROM
        taxicloud.eigyo_flat ef
    WHERE
        ef.cstm_cd = @cstm_cd
    GROUP BY
    	ef.sales_date
)
SELECT
    uf.sales_date AS `対象日付`,

    -- ▼▼▼ 1. 目標達成率[％] の検証 ▼▼▼
    sum(uf.soeisyu) AS `(1)_売上合計`,
    eigyosyo_target_date AS `(1)_目標金額`,
    round(sum(uf.soeisyu) / eigyosyo_target_date * 100, 2) AS `(1)_目標達成率_最終結果`,

    -- ▼▼▼ 2. 売上/時間[円] の検証 ▼▼▼
    sum(uf.soeisyu) AS `(2)_売上合計`,
    sum(abs(timestampdiff(minute, uf.nyuko_dtm, uf.syukko_dtm)))/60 AS `(2)_乗務時間_時間`,
    round(sum(uf.soeisyu) / (sum(abs(timestampdiff(minute, uf.nyuko_dtm, uf.syukko_dtm)))/60)) AS `(2)_売上毎時_最終結果`,

    -- ▼▼▼ 3. 実車率[％] の検証 ▼▼▼
    sum(uf.sa_eigyosoko_km) AS `(3)_営業走行距離`,
    sum(uf.sa_zensoko_km) AS `(3)_全走行距離`,
    round(sum(uf.sa_eigyosoko_km) / sum(uf.sa_zensoko_km) * 100, 2) AS `(3)_実車率_最終結果`,

    -- ▼▼▼ 4. 乗務時間[分] の検証 ▼▼▼
    sum(abs(timestampdiff(minute, uf.nyuko_dtm, uf.syukko_dtm))) AS `(4)_乗務時間_分`,
    sum(abs(timestampdiff(minute, uf.nyuko_dtm, uf.syukko_dtm)))/60 AS `(4)_乗務時間_時間`,

    -- ▼▼▼ 5. 固定迎車ｷｬﾝｾﾙ料金(差引)[円] の検証 ▼▼▼
    sum(uf.sa_geicancel_kin) AS `(5)_キャンセル料金合計`,
    sum(uf.sa_geicancel_kin) * 10 AS `(5)_キャンセル料金x10_最終結果`,
    
    -- ▼▼▼ 6. キロ当たり収入[円] の検証 ▼▼▼
    sum(uf.zeinuki_soeisyu) AS `(6)_税抜売上`,
    sum(uf.sa_zensoko_km) AS `(6)_全走行距離`,
    round(sum(uf.zeinuki_soeisyu) / sum(uf.sa_zensoko_km)) AS `(6)_キロ当たり収入_最終結果`,

    -- ▼▼▼ 7. 実車キロ当たり収入[円] の検証 ▼▼▼
    sum(uf.zeinuki_soeisyu) AS `(7)_税抜売上`,
    sum(uf.sa_eigyosoko_km) AS `(7)_営業走行距離`,
    round(sum(uf.zeinuki_soeisyu) / sum(uf.sa_eigyosoko_km)) AS `(7)_実車キロ当たり収入_最終結果`

FROM
    taxicloud.unko_flat uf
LEFT OUTER JOIN
    eft
ON
    uf.cstm_cd = eft.cstm_cd
AND
    uf.eigyosyo_cd = eft.eigyosyo_cd
AND
    uf.sales_date = eft.sales_date 
WHERE
    uf.sales_month = @month
    AND
    uf.cstm_cd = @cstm_cd
    AND
    uf.eigyosyo_cd = @eigyosyo_cd
GROUP BY
    uf.sales_date,
    eigyosyo_target_date
ORDER BY
    uf.sales_date;