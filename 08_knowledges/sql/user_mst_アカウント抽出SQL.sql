■アカウント抽出SQL（よしなに変更してください）
select
  um.user_id AS ユーザーID,
  CASE
    WHEN um.user_pswd = '$2b$10$bqzbo1msGM3XP0edsGbatO7k.BKIhZrpsB5zwFdE6oDFr8jQWvuMS' THEN 'abcdefgh'
    ELSE um.user_pswd
  END AS パスワード ,
  um.user_nm  AS ユーザー名,
  CASE
    WHEN um.authority = 1 THEN CONCAT(um.authority, ' : サービス管理者権限')
    WHEN um.authority = 2 THEN CONCAT(um.authority, ' : システム管理者権限')
    WHEN um.authority = 3 THEN CONCAT(um.authority, ' : 製造事業者権限')
    WHEN um.authority = 4 THEN CONCAT(um.authority, ' : 販売店権限')
    WHEN um.authority = 5 THEN CONCAT(um.authority, ' : 営業所権限')
    WHEN um.authority = 6 THEN CONCAT(um.authority, ' : 会社権限')
    ELSE um.authority
  END AS 権限 ,
  CONCAT(um.cstm_cd, ' : ', km.kokyaku_nm) AS 顧客名 ,
  CONCAT(um.eigyosyo_cd, ' : ', em.eigyosyo_nm) AS 営業所名
from taxicloud.user_mst um
inner join taxicloud.kokyaku_mst km
  ON um.cstm_cd = km.cstm_cd
inner join taxicloud.eigyosyo_mst em
  ON um.cstm_cd = em.cstm_cd
  and um.eigyosyo_cd = em.eigyosyo_cd
where um.authority in ('5', '6')
  and um.delete_flg = 0
  and km.delete_flg = 0
  and em.delete_flg = 0
  and um.user_pswd = '$2b$10$bqzbo1msGM3XP0edsGbatO7k.BKIhZrpsB5zwFdE6oDFr8jQWvuMS'
limit 200





https://cloudpack.slack.com/archives/C098Z6YLKEC/p1756955584981289?thread_ts=1754042632.662909&cid=C098Z6YLKEC