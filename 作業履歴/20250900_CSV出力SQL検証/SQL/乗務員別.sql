-- 乗務員別 静鉄タクシー(02000026) 本社営業所(00000002)

SET @cstm_cd = '02000026';
SET @eigyosyo_cd = '00000002';
SET @month = '2023/09';
SET @comparison_month = '2023/08';

WITH
eft AS (
    SELECT
    	ef.cstm_cd
    	,ef.eigyosyo_cd
    	,ef.jomuin_cd
    	,ef.sales_date
    	,SUM(ef.geisya_cnt) AS geisya_cnt
    FROM 
    	taxicloud.eigyo_flat ef
    WHERE
        ef.sales_month = @month
        AND ef.cstm_cd = @cstm_cd
        AND ef.eigyosyo_cd = @eigyosyo_cd
        AND ef.geisya_flg = '1'
    GROUP BY 
    	ef.cstm_cd
    	,ef.eigyosyo_cd
    	,ef.jomuin_cd
    	,ef.sales_date
),
previous_month_rates AS (
    -- 前月の乗務員コードに紐づく売上と目標を取得
        SELECT
        	uf.cstm_cd 
        	,uf.eigyosyo_cd 
            ,uf.jomuin_cd AS jomuin_cd
            ,CASE WHEN uf.jomuin_target_month = 'E' THEN 0 ELSE ROUND(IFNULL(SUM(uf.soeisyu) / MAX(CONVERT(uf.jomuin_target_month,DECIMAL)) * 100, 0), 2) END AS j_mon_emp_sales_target_rate
        FROM
            taxicloud.unko_flat uf
        WHERE
            uf.cstm_cd = @cstm_cd
            AND uf.eigyosyo_cd = @eigyosyo_cd
            AND uf.sales_month = @comparison_month
        GROUP BY
        uf.cstm_cd
        ,uf.eigyosyo_cd
        ,uf.jomuin_cd
)

SELECT
    -- No.1
    IFNULL(CONCAT(uf.kbn_cd, ':', uf.kbn_nm) , '') AS '区分'
    -- No.2
    ,IFNULL(CONCAT(uf.kinmu_cd, ':', uf.kinmu), '') AS '勤務形態'
    -- No.3
    ,uf.jomuin_cd AS '乗務員コード'
    -- No.4 画面表示項目
    ,uf.jomuin_nm AS '氏名'
    -- No.5 画面表示項目
    ,CASE WHEN uf.jomuin_target_month = 'E' THEN 0 ELSE IFNULL(MAX(CONVERT(uf.jomuin_target_month,DECIMAL)),0) END AS '目標[円]'
    -- No.6 画面表示項目
    ,IFNULL(SUM(uf.soeisyu), 0) AS '売上[円]'
    -- No.7
    ,IFNULL(SUM(uf.unko_gensyu), 0) AS '現収[円]'
    -- No.8
    ,IFNULL(SUM(uf.unko_misyu), 0) AS '未収[円]'
    -- No.9
    ,IFNULL(SUM(uf.tax), 0) AS '税金[円]'
    -- No.10 画面表示項目
    ,CASE WHEN uf.jomuin_target_month = 'E' THEN 0 ELSE ROUND(IFNULL(SUM(uf.soeisyu) / MAX(CONVERT(uf.jomuin_target_month,DECIMAL)) * 100, 0), 2) END AS '目標達成率[％]'
	-- No.11 画面表示項目
    ,CASE WHEN uf.jomuin_target_month = 'E' THEN 0 ELSE ROUND(IFNULL(SUM(uf.soeisyu) / MAX(CONVERT(uf.jomuin_target_month,DECIMAL)) * 100, 0), 2) END - IFNULL(pmr.j_mon_emp_sales_target_rate, 0) AS '前月比（目標達成率）[ポイント]'
    -- No.12 画面表示項目
    ,IFNULL(ROUND(SUM(uf.soeisyu) / NULLIF(SUM(ABS(TIMESTAMPDIFF(MINUTE, uf.nyuko_dtm, uf.syukko_dtm))) / 60, 0)), 0) AS '売上/時間[円]'
    -- No.13 画面表示項目
    ,IFNULL(COUNT(DISTINCT uf.sales_date), 0) AS '乗務日数[日]'
    -- No.14 画面表示項目
    ,IFNULL(ROUND(SUM(uf.eigyohyoka_pt) / COUNT(uf.eigyohyoka_pt)),0) AS '営業評価点数[点]'
    -- No.15
    ,IFNULL(SUM(ABS(TIMESTAMPDIFF(MINUTE, uf.nyuko_dtm, uf.syukko_dtm))), 0) AS '乗務時間[分]'
    -- No.16 画面表示項目
    ,IFNULL(ROUND(SUM(CONVERT(uf.sa_eigyosoko_km,DECIMAL(4,1))) / SUM(CONVERT(uf.sa_zensoko_km,DECIMAL(4,1))) * 100, 2),0) AS '実車率[％]'
    -- No.17
    ,IFNULL(SUM(uf.roudou_tm), 0) AS '労働時間[分]'
    -- No.18
    ,IFNULL(SUM(uf.kyukei_tm), 0) AS '休憩時間[分]'
    -- No.19
    ,IFNULL(SUM(uf.kusyateisi_tm), 0) AS '空車停止時間[分]'
    -- No.20
    ,IFNULL(SUM(uf.sa_rui_handle_tm), 0) AS '累計ハンドル時間(差引)[分]'
    -- No.21
    ,IFNULL(SUM(uf.sa_zensoko_tm), 0) AS '全走行時間(差引)[分]'
    -- No.22
    ,IFNULL(SUM(uf.sa_eigyo_soko_tm), 0) AS '営業走行時間(差引)[分]'
    -- No.23
    ,IFNULL(SUM(uf.sa_eigyo_tm), 0) AS '営業時間(差引)[分]'
    -- No.24
    ,IFNULL(SUM(uf.jomu_km), 0) AS '乗務距離[km]'
    -- No.25
    ,IFNULL(SUM(uf.sa_eigyosoko_km), 0) AS '営業走行距離(差引)[km]'
    -- No.26
    ,IFNULL(SUM(uf.sa_zensoko_km), 0) AS '全走行距離(差引)[km]'
    -- No.27
    ,IFNULL(SUM(uf.sa_kuuten_km), 0) AS '空転距離(差引)[km]'
    -- No.28
    ,IFNULL(SUM(uf.sa_geisya_km), 0) AS '迎車距離(差引)[km]'
    -- No.29
    ,IFNULL(SUM(uf.sa_geicancel_kin) * 10, 0) AS '固定迎車ｷｬﾝｾﾙ料金(差引)[円]'
    -- No.30
    ,IFNULL(SUM(uf.unko_etc_ryokin), 0) AS 'ETC料金(合計)[円]'
    -- No.31
    ,IFNULL(SUM(uf.etc_kusya_ryokin), 0) AS 'ETC料金(空車)[円]'
    -- No.32
    ,IFNULL(SUM(uf.etc_zisya_ryokin), 0) AS 'ETC料金(実車)[円]'
    -- No.33
    ,IFNULL(SUM(uf.etc_geisya_ryokin), 0) AS 'ETC料金(迎車)[円]'
    -- No.34
    ,IFNULL(SUM(uf.total_tatekae_kin), 0) AS '立替金合計[円]'
    -- No.35
    ,IFNULL(SUM(uf.total_kihon_kin), 0) AS '基本料金合計[円]'
    -- No.36
    ,IFNULL(SUM(uf.total_zigo_kin), 0) AS '爾後料金合計[円]'
    -- No.37
    ,IFNULL(SUM(uf.total_geisya_kin), 0) AS '迎車料金合計[円]'
    -- No.38
    ,IFNULL(SUM(uf.total_okikae_kin), 0) AS '置換料金合計[円]'
    -- No.39
    ,IFNULL(SUM(uf.total_teigaku_kin), 0) AS '定額料金合計[円]'
    -- No.40
    ,IFNULL(ROUND(SUM(uf.zeinuki_soeisyu) / NULLIF(SUM(CONVERT(uf.sa_zensoko_km , DECIMAL(4,1))), 0), 0), 0) AS 'キロ当たり収入[円]'
    -- No.41
    ,IFNULL(ROUND(SUM(uf.zeinuki_soeisyu) / NULLIF(SUM(CONVERT(uf.sa_eigyosoko_km , DECIMAL(4,1))), 0), 0), 0) AS '実車キロ当たり収入[円]'
    -- No.42
    ,IFNULL(SUM(uf.tatekae_kousoku), 0) AS '立替(高速)合計[円]'
    -- No.43
    ,IFNULL(SUM(uf.tatekae_chusya), 0) AS '立替(駐車)合計[円]'
    -- No.44
    ,IFNULL(SUM(uf.tatekae_sonota), 0) AS '立替(その他)合計[円]'
    -- No.45
    ,IFNULL(SUM(uf.total_kin), 0) AS '立替金以外の合計金額(総営収)[円]'
    -- No.46
    ,IFNULL(SUM(uf.sa_tarifu_a_kin), 0) AS 'Aタリフ金額（差引）[円]'
    -- No.47
    ,IFNULL(SUM(uf.sa_tarifu_b_kin), 0) AS 'Bタリフ金額（差引）[円]'
    -- No.48
    ,IFNULL(SUM(uf.sa_tarifu_c_kin), 0) AS 'Cタリフ金額（差引）[円]'
    -- No.49
    ,IFNULL(SUM(uf.sa_tarifu_d_kin), 0) AS 'Dタリフ金額（差引）[円]'
    -- No.50
    ,IFNULL(SUM(uf.sa_tarifu_e_kin), 0) AS 'Eタリフ金額（差引）[円]'
    -- No.51
    ,IFNULL(SUM(uf.sa_tarifu_f_kin), 0) AS 'Fタリフ金額（差引）[円]'
    -- No.52
    ,IFNULL(SUM(uf.sa_tarifu_g_kin), 0) AS 'Gタリフ金額（差引）[円]'
    -- No.53
    ,IFNULL(SUM(uf.sa_tarifu_h_kin), 0) AS 'Hタリフ金額（差引）[円]'
    -- No.54
    ,IFNULL(SUM(uf.sa_tarifu_i_kin), 0) AS 'Iタリフ金額（差引）[円]'
    -- No.55
    ,IFNULL(SUM(uf.sa_tarifu_x_kin), 0) AS 'Xタリフ金額（差引）[円]'
    -- No.56
    ,IFNULL(SUM(uf.sa_tarifu_y_kin), 0) AS 'Yタリフ金額（差引）[円]'
    -- No.57
    ,IFNULL(SUM(uf.sa_tarifu_j_kin), 0) AS 'Jタリフ金額（差引）[円]'
    -- No.58
    ,IFNULL(SUM(uf.sa_tarifu_k_kin), 0) AS 'Kタリフ金額（差引）[円]'
    -- No.59
    ,IFNULL(SUM(uf.sa_tarifu_l_kin), 0) AS 'Lタリフ金額（差引）[円]'
    -- No.60
    ,IFNULL(SUM(uf.sa_eigyo_cnt), 0) AS '営業回数（差引）[回]'
    -- No.61
    ,IFNULL(SUM(uf.sa_zigo1_cnt), 0) AS '後続回数1（差引）[回]'
    -- No.62
    ,IFNULL(SUM(uf.sa_zigo2_cnt), 0) AS '後続回数2（差引）[回]'
    -- No.63
    ,IFNULL(SUM(uf.sa_zigo3_cnt), 0) AS '後続回数3（差引）[回]'
    -- No.64
    ,IFNULL(SUM(eft.geisya_cnt), 0) AS '迎車回数（差引）[回]'
    -- No.65
    ,IFNULL(SUM(uf.sa_geicancel_cnt), 0) AS '固定迎車ｷｬﾝｾﾙ回数（差引）[回]'
    -- No.66
    ,IFNULL(SUM(uf.sa_back_cnt), 0) AS 'バック回数（差引）[回]'
    -- No.67
    ,IFNULL(SUM(uf.sa_tarifu_a_cnt), 0) AS 'Aタリフ回数（差引）[回]'
    -- No.68
    ,IFNULL(SUM(uf.sa_tarifu_b_cnt), 0) AS 'Bタリフ回数（差引）[回]'
    -- No.69
    ,IFNULL(SUM(uf.sa_tarifu_c_cnt), 0) AS 'Cタリフ回数（差引）[回]'
    -- No.70
    ,IFNULL(SUM(uf.sa_tarifu_d_cnt), 0) AS 'Dタリフ回数（差引）[回]'
    -- No.71
    ,IFNULL(SUM(uf.sa_tarifu_e_cnt), 0) AS 'Eタリフ回数（差引）[回]'
    -- No.72
    ,IFNULL(SUM(uf.sa_tarifu_f_cnt), 0) AS 'Fタリフ回数（差引）[回]'
    -- No.73
    ,IFNULL(SUM(uf.sa_tarifu_g_cnt), 0) AS 'Gタリフ回数（差引）[回]'
    -- No.74
    ,IFNULL(SUM(uf.sa_tarifu_h_cnt), 0) AS 'Hタリフ回数（差引）[回]'
    -- No.75
    ,IFNULL(SUM(uf.sa_tarifu_i_cnt), 0) AS 'Iタリフ回数（差引）[回]'
    -- No.76
    ,IFNULL(SUM(uf.sa_tarifu_x_cnt), 0) AS 'Xタリフ回数（差引）[回]'
    -- No.77
    ,IFNULL(SUM(uf.sa_tarifu_y_cnt), 0) AS 'Yタリフ回数（差引）[回]'
    -- No.78
    ,IFNULL(SUM(uf.unko_man_jinin), 0) AS '男性人員[人]'
    -- No.79
    ,IFNULL(SUM(uf.unko_woman_jinin), 0) AS '女性人員[人]'
    
FROM
    taxicloud.unko_flat uf

LEFT OUTER JOIN
    eft
		ON  
			uf.cstm_cd = eft.cstm_cd
		AND 
			uf.eigyosyo_cd = eft.eigyosyo_cd
        AND 
        	uf.jomuin_cd = eft.jomuin_cd
        AND 
        	uf.sales_date = eft.sales_date

LEFT OUTER JOIN
    previous_month_rates pmr 
    	ON 
    		uf.cstm_cd = pmr.cstm_cd
		AND
			uf.eigyosyo_cd = pmr.eigyosyo_cd
    	AND
    		uf.jomuin_cd = pmr.jomuin_cd

WHERE
        	uf.sales_month = @month
        AND 
        	uf.cstm_cd = @cstm_cd
        AND 
        	uf.eigyosyo_cd = @eigyosyo_cd

GROUP BY
	uf.jomuin_cd,
    uf.kbn_cd,
    uf.kinmu_cd

ORDER BY
	uf.jomuin_cd,
    uf.kbn_cd,
    uf.kinmu_cd