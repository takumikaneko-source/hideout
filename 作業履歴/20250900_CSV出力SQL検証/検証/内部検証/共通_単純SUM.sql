
-- ①テストデータの確認
-- 集計しない場合の元の数値

SET @cstm_cd = '19951115';
SET @eigyosyo_cd = '00000001';
SET @month = '2027/01';

SELECT
	uf.cstm_cd 
	,uf.eigyosyo_cd 
	,uf.jomuin_cd 
	,uf.sales_date 
	,uf.soeisyu
FROM
	taxicloud.unko_flat uf
WHERE
	uf.sales_month = @month;


-- 日別の結合条件でsoeisyuをSUM--------------------------------------------------------------------------------------------------------------------

SET @cstm_cd = '19951115';
SET @eigyosyo_cd = '00000001';
SET @month = '2027/01';

WITH
eft AS (
    SELECT
        ef.cstm_cd,
        ef.eigyosyo_cd
        ,ef.geisya_cnt
        ,ef.sales_date 
    FROM
        taxicloud.eigyo_flat ef
    WHERE
        ef.cstm_cd = @cstm_cd
    Group by
    	ef.sales_date
)

SELECT

uf.sales_date
,SUM(soeisyu)

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
    uf.sales_date

ORDER BY
    uf.sales_date;


-- 乗務員別の結合条件でSUM--------------------------------------------------------------------------------------------------------------------------
SET @cstm_cd = '19951115';
SET @eigyosyo_cd = '00000001';
SET @month = '2027/01';
SET @jomuin_cd = 'JM000001';



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
        cstm_cd
        ,eigyosyo_cd
        ,jomuin_cd
        ,ROUND((SUM(soeisyu) / NULLIF(MAX(jomuin_target_month), 0)) * 100, 2) AS prev_achievement_rate
    FROM
        taxicloud.unko_flat
    WHERE
        -- 条件1: 締日売上年月 = 対象年月 - 1ヵ月
        sales_month = DATE_FORMAT(DATE_SUB(STR_TO_DATE(CONCAT(@month, '/01'), '%Y/%m/%d'), INTERVAL 1 MONTH), '%Y/%m')
        
        -- 条件2: 同一顧客
        AND cstm_cd = @cstm_cd
        
        -- 条件3: 同一営業所
        AND eigyosyo_cd = @eigyosyo_cd

    GROUP BY
        -- 条件5: 乗務員コードごと
        jomuin_cd
)

SELECT

uf.jomuin_cd
,SUM(soeisyu)

FROM
    unko_flat_filtered uf
LEFT OUTER JOIN
    eigyo_flat_filtered efg
		ON  
			uf.cstm_cd = efg.cstm_cd
		AND 
			uf.eigyosyo_cd = efg.eigyosyo_cd
        AND 
        	uf.jomuin_cd = efg.jomuin_cd
        AND 
        	uf.sales_date = efg.sales_date

LEFT OUTER JOIN
	taxicloud.jomuin_mst jm
		ON  
			uf.cstm_cd = jm.cstm_cd
		AND 
			uf.eigyosyo_cd = jm.eigyosyo_cd
		AND 
			uf.jomuin_cd = jm.jomuin_cd

LEFT OUTER JOIN
	taxicloud.kubun_mst km
		ON	
			jm.kbn_cd = km.kbn_cd
		AND 
			jm.cstm_cd = km.cstm_cd 
		AND 
			jm.eigyosyo_cd = km.eigyosyo_cd

LEFT OUTER JOIN
    previous_month_rates pmr 
    	ON 
    		uf.cstm_cd = pmr.cstm_cd
		AND
			uf.eigyosyo_cd = pmr.eigyosyo_cd
    	AND
    		uf.jomuin_cd = pmr.jomuin_cd

GROUP BY
	uf.jomuin_cd,
    jm.jomuin_nm,
    km.kbn_cd, km.kbn_nm
ORDER BY
	uf.jomuin_cd;