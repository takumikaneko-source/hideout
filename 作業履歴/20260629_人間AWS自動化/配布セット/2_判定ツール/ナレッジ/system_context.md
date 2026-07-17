# システム背景（system_context）

AI判定の背景情報。アラームやログの「意味」「重さ」に加え、**エラーの上流に真因があるか・下流に波及するか**を推論するための処理フロー知識を持つ。
判定ごとに変わらない安定情報なので、プロンプトキャッシュに載せて使う想定。

**出典と裏取り（2026-07-10 調査）**
- 処理フロー・アラーム発報条件: taxi-cloud リポジトリの各 template.yml / StateMachine 定義 / 関数コードを直接調査して裏取り済み（backend/strike, duel, aegis）
- サービス構成・連携: `taxi-cloud/.github/copilot-instructions.md`
- 再処理・確認手順: `../資料/運用作業手順.xlsx`「備忘：ERROR対応例、lambdaの設定確認方法」
- 頻出アラーム件数: Backlog実データ（`cases.jsonl`）の集計

**含めないもの**: ARN・アカウントID・シークレット・個人名。推定を含む箇所は（推測）と付記。

---

## 1. サービスの役割と重要度

| サービス | 役割 | 重要度の傾向 |
|----------|------|--------------|
| aegis | 管理系（YWM／Web管理）API・バッチ。マスタ連携の起点 | マスタ連携失敗は duel マートまで波及しうる |
| blitz | タブレット／マスメン系 API（REST＋WebSocket） | 端末・現場影響が出やすい |
| buster | DWH／Redshift 連携の中心 | 集計・分析系。即時業務影響は相対的に低め |
| duel | 動態・売上APIの中核（REST／WebSocket／SFn／Pipes） | 中核。失敗時の影響が大きくなりやすい |
| strike | リアルタイム処理・日報連携・KCPS同期・IoTファイル処理 | 連携の起点。取りこぼしが波及しやすい |

環境: dev / dev2 / dev3 / dev4 / stg / prd（一部 stgtmp）。判定対象は基本 **prd**。

---

## 2. アラーム発報条件の実態（テンプレート裏取り済み）

ほとんどのアラームは「**ログに [ERROR] が1件出たら即発報**」（MetricFilter `"[ERROR]"`・しきい値1・60秒集計）。つまり発報＝重大とは限らない。ただし以下の例外があり、**同じ1回の発報でも意味の重さが違う**。

| アラーム | 発報条件の特記 | 判定への含意 |
|----------|----------------|--------------|
| duel dash-topics-get | しきい値 **10**（60秒に10件） | 鳴った時点で異常多発。単発エラーより重い |
| strike ympf-sync | しきい値 **3／1時間集計** | 鳴った時点で1時間に3回以上失敗している |
| strike kcps-replace-tmp-syaryo | `[ERROR]` **または `[WARNING]`** で発報 | WARNINGでも鳴る。ログ実体がWARNINGなら軽い可能性 |
| strike iot-daily-file-oku | `[ERROR]` または裸の `ERROR` | 検知が広め。誤検知（文言中のERROR）もあり得る |
| aegis disposalday-mst-list-**set** | FilterPattern が **`[INFO]`**（getは`[ERROR]`） | **要確認事項**: INFOログで発報する設定になっており、ノイズの可能性。頻出上位の一因かもしれない |
| 各 `...-failures` 系 | `AWS/States ExecutionsFailed`（SFn実行失敗） | リトライを使い切って実行全体が失敗した状態。ログ1件系より重い |

---

## 3. 処理フローと影響伝播（上流・下流の判定材料）

### 3-1. マスタ連携チェーン（aegis → duel）※裏取り済みの完全チェーン

```
[画面操作] aegis ywm-disposalday-mst-list-set（RDS更新＋SQS送信）
   ↓ SQS: update_history_from_initial_setting_mst
[aegis SFn] target-history-set-by-disposalday（目標履歴の更新）
   ↓ クロスアカウントSQS: duel mart_from_initial_mst（送り手は ywm-disposalday-mst-send のみ）
[duel SFn] update-flat-disposalday（マート更新）
```

- **set が失敗** → 後続3段がすべて不発。目標履歴もマートも更新されない（下流影響: 大きい）
- **duel update-flat-disposalday-failures が発報** → 上流の aegis 側（set／target-history SFn）の成否を先に確認する
- 運用手順の「履歴テーブルのレコード重複確認」はこのチェーンに対応する監視

これとは別系統で、**aegis master-data-exp-to-duel が毎分実行**され、RDS差分→CSV→duel所有S3（link-master）→S3イベント通知→SQS→**duel master-data-registration** がRDS登録する（同様に aegis→blitz も毎分並存）。
- duel 側で **HeadObject 404** 等が出たら、上流のS3配置（エクスポート側の失敗・配置と通知のタイミングずれ・処理済みファイルの削除）を疑う
- 毎分の差分連携なので、**一時エラーは次サイクルで自然回復**しやすい（前回成功日時ベースの差分再送）

### 3-2. 日報・フラット登録チェーン（duel）

```
SQS link_daily_json → [Pipes] → [duel SFn] unko-eigyo-flat-registration
  準備 → 要否判断 → 運行フラット → 営業フラット → 積算 → 平均（直列）
```

- 各ステートに **Retry 3回**（10秒間隔・指数バックオフ）あり、**Catch なし** → failures 発報は「3回リトライしても失敗」の意味
- 上流は日報JSON取込系。**daily-json-load 系のエラーと同時期なら上流起因**を疑う
- 直列実行なので、途中ステート失敗時は**それ以降のフラットが未更新**（どのステートで落ちたかで影響範囲が変わる）

### 3-3. マート再生成（duel recreate-mart）

```
EventBridge（日4回: cron 3,9,18,22時台）→ [SFn]
  Parallel: ECS unko / ECS eigyo（★Retryなし）→ 月次ダッシュ作成 → マート切替(SwapMart) → フラット再作成
```

- **ECSタスクにはRetryがない** → ここで失敗すると自動救済はなく、次回スケジュールまで残る（判定: 静観しても次回で再生成されるが、連続失敗なら要対応）
- SwapMart 前に失敗した場合、切替が行われず**旧マートのまま**（データ欠損よりは「更新遅延」の影響）

### 3-4. IoTファイル処理の並列ファンアウト（strike）※同時多発アラームの説明

link_agent バケットに `.oku` ファイルが置かれると、**同じファイルを3つの処理が並列に拾う**:

```
S3 link_agent (.oku)
 ├→ iot-daily-file-oku（日報PDF/営業CSV化 → daily_data_pdf・link-eigyo-key へ出力）
 ├→ provision-daily-data-worker-from-agent
 └→ insert-gps-data-from-agent（GPS抽出 → クロスアカウントS3 aegis s3-gps-data へ）
```

- **この3系統のアラームが同時期に発報していたら、単一の不正ファイルが共通原因**の可能性が高い（1件の判定で他2件も説明できる）
- iot-daily-file-oku の出力先バケットはさらに `copy-data-to-dwh-and-master`（strike→aegis連携）が監視 → ここで失敗すると**DWH/マスタ側への連携が欠ける**
- insert-gps-data-from-inner は別入力（daily_data バケットの `.fcn`）で同様の構造

### 3-5. KCPS車両マスタ連携チェーン（strike）

```
EventBridge（60分間隔）→ kcps-replace-tmp-syaryo（KCPS外部API → RDS tmp_syaryo_mst 全件洗い替え）
   ↓ SQS insert-car-mst
kcps-sync-syaryo（車両マスタ差分登録）
   ↓ SQS insert-daily-car-count-registration
日次台数登録
```

- 外部API（KCPS）依存 → **外部側のメンテナンス・OS更改等で失敗する**（過去事例: 対応不要判定が多い）。60分間隔なので次回実行で回復しやすい
- 洗い替えが失敗のまま続くと車両マスタ→日次台数の**下流チェーンが止まる**（単発は静観・連続は要確認）
- エラー時はアプリが**Backlogへ自動起票**する（「KCPS車両マスタ連携エラー」）
- 過去の既知事象: 車両マスタの生きレコード重複による `MultipleResultsFound`（guidelines 3-1-C 参照）

### 3-6. YMPF連携（strike ympf-sync）

```
EventBridge（5分間隔）→ SQS → ympf-sync
  DynamoDB RealtimeData（前回成功以降の差分）→ S3 link_ympf へ CSV/.oku 出力
  → provision-daily-data-worker が参照 → （外部YMPF取り込みはリポジトリ外・推測）
```

- 5分間隔＋前回成功日時ベースの差分 → **一時エラーは次サイクルで回復**しやすい
- ただしアラーム条件が「1時間に3回以上」なので、**発報時点で既に繰り返し失敗している** → 単発扱いにしない
- **連続発報は高額請求リスク**として運用手順で緊急扱い（rules.yaml 登録済み）

### 3-7. その他の常時系（duel）

- **railline-operation-info-registration**: **毎分実行**・外部サービス（レスキューナウ）依存 → 外部起因の一時エラーが出やすく、単発なら次の実行で解消する構造。対の削除処理あり
- **dash-topics-get**: 画面からの同期API（読み取りのみ・DynamoDB参照）。リトライ機構なし＝ユーザー再操作で解消する類型（guidelines 全体原則の「静観」に該当しやすい）。ただし発報しきい値10なので鳴ったら多発している
- **daily-json-load-daily-report**: aegis と duel に**同名の別関数**が存在する（aegis側=DWHキュー→S3取込、duel側=DWHキュー→S3、後続に daily-report-data-registration）。アラーム名のサービスプレフィックスでどちらか判別する

---

## 4. 上流・下流を推論するときの一般則

**上流（前処理）起因を疑うサイン**
- S3 の 404／NoSuchKey／HeadObject 失敗 → 前段のファイル配置処理の失敗・遅延・削除を疑う
- 「ファイルが見つからない」「処理済みデータ」→ 前段がすでに処理済み（正常な重複）か、前段の失敗
- 入力データの形式・欠損エラー（必須項目なし・型不正・`MultipleResultsFound`）→ データを作った側（前段・外部連携元・顧客起因）の問題。当該Lambda自体の不具合ではない
- 複数の並列パイプラインが同時発報 → 共通の入力ファイル・共通の上流を疑う（3-4参照）

**下流（後続）への波及を見るポイント**
- そのフローの終端か中間か（3章の各チェーン参照）。中間で落ちると後続が未実行になる
- SFn は Catch の有無と失敗ステート位置で「どこまで済んでいるか」が決まる
- 差分連携（毎分・5分毎・60分毎）は次サイクルで自然回復しうる。**スケジュールが日次以下（マート再生成等）や手動起点（画面操作）のものは自然回復しない**
- クロスアカウント連携（aegis→duel、strike→aegis、duel→blitz）を跨ぐ失敗は、相手サービス側のデータ欠けとして現れる

**自動救済の有無**
- SFnステートのRetry（多くは3回・指数バックオフ）／ECSタスクは**Retryなし**（3-3）
- SQSの可視性タイムアウト・DLQ設定は**リポジトリ外管理のため実環境で要確認**（運用資料の「15分毎・計10回」は一部キューの実測値。全キュー共通とは限らない）
- 一部処理はエラー時に**Backlogへ自動起票**（自動復旧基盤・KCPS連携）→ 起票済みチケットの existence 自体が「検知済み」のサイン

---

## 5. duel → blitz リアルタイム連携（参考）

DynamoDB Stream 起点のクロスアカウントSQS連携が3本（alert_history / realtime_tran / initial_location）。
これらの失敗は**タブレット側（blitz）の表示遅延・欠落**として現れる（端末・現場影響）。

---

## 6. コスト・緊急に直結する挙動

- `strike-prd-ympf-sync-function` 連続発報 → バッチがエラーを出し続け**高額請求の恐れ**。緊急扱い（rules.yaml 登録済み・運用手順記載）
- CloudWatch Logs Insights は課金対象のため、ログ収集ツールでは使用しない方針

---

## 7. 運用チームへの確認事項（調査で見つかった疑問点）

1. aegis disposalday-mst-list-**set** のメトリクスフィルタが `[INFO]`（get は `[ERROR]`）。意図的か誤設定か。頻出上位（181件/32件）の一因の可能性
2. SQSキュー実体（可視性タイムアウト・DLQ・maxReceiveCount）はリポジトリ外管理。主要キューの実値
3. strike ArchiveDLQFunction は現在トリガー未接続（コメントアウト）。DLQ退避運用の現状

---

## 注記

本ファイルの処理フローは template.yml・StateMachine定義・関数コードで裏取り済み（2026-07-10）。（推測）付きの箇所と、リポジトリ外管理（SQS実体・S3通知設定・外部システム側）は実環境での確認を優先する。テンプレート改修があれば随時更新する。
