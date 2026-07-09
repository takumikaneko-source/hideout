
select
*
from
rescuenow_file_info rfi 

where
info_num = '00000016536980'



UPDATE 
rescuenow_file_info rfi 
set
title = '大井川鉄道大井川本線 長期運転見合わせ'

where
info_num = '00000016536980'




INSERT INTO rescuenow_file_info  (
    data_kubun, info_num, category_cd_0, category_nm_0, category_cd_1, category_nm_1,
    category_cd_2, category_nm_2, publish_time, follow_up_num, limit_time, `level`,
    area_kubun, area_level_nm, info_kubun, title, short_statement, long_statement,
    area_level, area_cd_0, area_nm_0, area_cd_1, area_nm_1, area_cd_2, area_nm_2,
    area_cd_3, area_nm_3, area_cd_4, area_nm_4, area_cd_5, area_nm_5, attribute_1,
    attribute_2, reserve1, reserve2, reserve3, reserve4, reserve5, delete_flg,
    insert_datetime, insert_user_id, insert_business_id, update_datetime,
    update_user_id, update_business_id, update_count
) VALUES (
    'data', '00020250813001', '0002', '交通', '00020001', '鉄道情報',
    '01', '運転見合わせ', '2025-08-12 05:00:00', '00000017173511', NULL, 2,
    '04', NULL, 'N', '大井川鉄道大井川本線 長期運転見合わせ', '2022年台風15号災害の影響で、川根温泉笹間渡～千頭駅間の運転を見合わせています。', '2022年台風15号災害の影響で、川根温泉笹間渡～千頭駅間の運転を見合わせています。',
    2, 1, '日本', '05', '中部', '0247', '大井川鐵道',
    '0247', '大井川鉄道大井川本線', 0, NULL, 0, NULL, NULL,
    NULL, NULL, NULL, NULL, NULL, NULL, 0,
    '2025-08-12 16:53:56', 'RTM512', 'RTM512', '2025-08-12 17:03:14',
    'RTM512', 'RTM512', 1
);


INSERT INTO rescuenow_file_info (data_kubun, info_num, category_cd_0, category_nm_0, category_cd_1, category_nm_1, category_cd_2, category_nm_2, publish_time, follow_up_num, limit_time, `level`, area_kubun, area_level_nm, info_kubun, title, short_statement, long_statement, area_level, area_cd_0, area_nm_0, area_cd_1, area_nm_1, area_cd_2, area_nm_2, area_cd_3, area_nm_3, area_cd_4, area_nm_4, area_cd_5, area_nm_5, attribute_1, attribute_2, reserve1, reserve2, reserve3, reserve4, reserve5, delete_flg, insert_datetime, insert_user_id, insert_business_id, update_datetime, update_user_id, update_business_id, update_count) VALUES ('data', '16536980', '2', '交通', '20001', '鉄道情報', 'nan', 'nan', '2025-08-12 05:00:00', '17173511', 'nan', '2', '4', 'nan', 'N', '大井川鉄道大井川本線 長期運転見合わせ', '2022年台風15号災害の影響で、川根温泉笹間渡～千頭駅間の運転を見合わせています。', '2022年台風15号災害の影響で、川根温泉笹間渡～千頭駅間の運転を見合わせています。', '2', '1', '日本', '5', '中部', '247', '大井川鐵道', '247', '大井川鉄道大井川本線', '0', 'nan', '0', 'nan', 'nan', 'nan', '20250812050105', 'nan', 'nan', 'nan', 'nan', '0', '2025-08-12 16:53:56', 'RTM512', 'RTM512', '2025-08-12 17:03:14', 'RTM512', 'RTM512', '7');




