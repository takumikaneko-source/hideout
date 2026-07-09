-- New script in 【SNAP】yzk-duel-stg.
-- Date: 2025 Sep 17
-- Time: 10:34:40

-- 営業所,月毎の運行フラット件数
select
uf.cstm_cd
,km.kokyaku_nm
,eigyosyo_cd
,eigyosyo_nm
,uf.sales_month
,count(uf.cstm_cd)

from
taxicloud.unko_flat uf

left outer join
taxicloud.kokyaku_mst km
	ON
		uf.cstm_cd = km.cstm_cd
where
	sales_month>'2023/01' -- あまり意味なさそう
group by
	cstm_cd
	,eigyosyo_cd
	,sales_month

order by
	sales_month asc
;

-- 月ごとの運行フラット件数
select
uf.sales_month
,count(uf.cstm_cd)

from
taxicloud.unko_flat uf

left outer join
taxicloud.kokyaku_mst km
	ON
		uf.cstm_cd = km.cstm_cd
group by
	sales_month

order by
	count(uf.cstm_cd) desc
;

-- 運行フラット件数が多い月を特定するSQL
SELECT
    sales_month,
    cstm_cd,
    kokyaku_nm,
    eigyosyo_cd,
    COUNT(*) AS record_count
FROM
    taxicloud.unko_flat
WHERE
    -- ご指定の7つの組み合わせ
    (cstm_cd, eigyosyo_cd) IN (
        -- ●多い顧客営業所
        ('02000018', '00000001'),
        ('02000012', '00000001'),
        ('02000026', '00000002'),
        -- ●中規模の顧客営業所
        ('02000026', '00000004'),
        ('02000046', '00000006'),
        -- ●小規模の顧客営業所
        ('02000076', '00000001'),
        ('02000088', '00000001')
    )
GROUP BY
    sales_month,
    cstm_cd,
    eigyosyo_cd
ORDER BY
    record_count DESC
LIMIT 10; -- 上位10件を表示



WITH 
-- ステップ1: まず、月ごとの組み合わせ別の件数を集計する
MonthlyCounts AS (
    SELECT
        sales_month,
        cstm_cd,
        kokyaku_nm,
        eigyosyo_cd,
        eigyosyo_nm,  
        COUNT(*) AS record_count
    FROM
        taxicloud.unko_flat
    WHERE
        (cstm_cd, eigyosyo_cd) IN (
            ('02000018', '00000001'),
            ('02000012', '00000001'),
            ('02000026', '00000002'),
            ('02000026', '00000004'),
            ('02000046', '00000006'),
            ('02000076', '00000001'),
            ('02000088', '00000001')
        )
    GROUP BY
        sales_month,
        cstm_cd,
        eigyosyo_cd
),
-- ステップ2: 顧客と営業所の組み合わせの中で、件数が多い順に順位を付ける
RankedMonths AS (
    SELECT
        sales_month,
        cstm_cd,
        kokyaku_nm,
        eigyosyo_cd,
        eigyosyo_nm,
        record_count,
        ROW_NUMBER() OVER(PARTITION BY cstm_cd, eigyosyo_cd ORDER BY record_count DESC) AS rn
    FROM
        MonthlyCounts
)
-- ステップ3: 順位が1位のレコードのみを抽出する
SELECT
    sales_month,
    cstm_cd,
    kokyaku_nm,
    eigyosyo_cd,
    eigyosyo_nm,
    record_count
FROM
    RankedMonths
WHERE
    rn = 1;


