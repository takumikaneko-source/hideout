# ナレッジ外だし — 3ファイルの定義と作り方

取得済みログの「影響度」と「対応要否」をAIに判定させるための知識を、3ファイルに外だしする。
本フォルダは Phase2（判定）用。ログ収集ツール（Phase2本体・AI不使用）とは別物。

## 3ファイルの役割

| ファイル | 役割 | 使われ方 |
|----------|------|----------|
| `rules.yaml` | 機械判定ルール | **AI不使用**。既知パターンをコードで照合し即断。最優先で適用 |
| `cases.jsonl` | 過去事例集 | 類似事例を検索で数件取り出し、AI判定の材料として渡す |
| `guidelines.md` | 判定基準 | 影響度・対応要否の定義。AI判定時にプロンプトへ渡す |

判定の流れ:
```
ログ → rules.yaml で機械照合
  ├─ 一致    → その場で結論（AIコストゼロ）
  └─ 不一致  → cases.jsonl から類似事例を検索
             → guidelines.md と併せてAIが判定
最終確認は運用チームの目視（従来どおり）
```

この流れを実装した判定ツール本体は `../判定ツール/` にある（judge_logs.py）。

## データ源

| 元データ | 場所 | 使いどころ |
|----------|------|------------|
| Backlog履歴 | `../Backlog集計/抽出結果ファイル/*.csv` | cases.jsonl の主材料（description=アラームJSON、comments=判定理由） |
| 日次監視手順 | `../資料/運用作業手順.xlsx`「暫定 日次監視内容・手順」 | 監視フロー・エスカレーション条件（guidelines.md 補強） |
| ERROR対応例 | 同上「備忘：ERROR対応例、lambdaの設定確認方法」 | guidelines.md / rules.yaml の主材料 |

## cases.jsonl の作られ方（2段パイプライン）

Backlogの生CSVは同じアラームの重複が大半（1,907件中ユニークなアラームは86種）。
そのまま検索対象にすると重複が多く、検索が重く精度も落ちるため、2段で作る。

```
Backlog CSV
  └ build_cases.py       → cases_raw.jsonl（全件・約1,900件・個人名除去済み）
       └ consolidate_cases.py → cases.jsonl（判定用・約190件・集約済み）
```

- **build_cases.py**: エラーログ種別のみを機械抽出。個人名は氏名辞書で除去、URL・画像参照・挨拶・スケジュール調整文も除去。出力は `cases_raw.jsonl`。
- **consolidate_cases.py**: (アラーム名 × 対応要否) のパターンごとに、中身のある理由を持つ代表例を最大3件残す。発生回数 `count` を付与するので「このアラームは過去N回出た」という頻度情報は保つ。出力は `cases.jsonl`（判定ツールが読む）。

再生成手順:
```
python build_cases.py        # Backlog CSV → cases_raw.jsonl
python consolidate_cases.py  # cases_raw.jsonl → cases.jsonl
```

### cases.jsonl のフィールド

| フィールド | 内容 |
|------------|------|
| alarm_name / summary | アラーム名・件名 |
| service / env / source_type | アラーム名から抽出（aegis〜strike / prd等 / lambda・stepfunctions・ecs） |
| error_summary | 代表事例の [ERROR] 行（200字まで） |
| action_hint | 対応要否の**暫定ラベル**（不要/静観/要/要確認）。キーワード推定なので目安 |
| reason | 判定理由の文（実質の判定信号はこちら） |
| needs_review | 断定材料が弱く目視確認が要るもの true |
| **count** | このパターン（アラーム×対応要否）の過去発生回数。頻出＝よくあるパターンの手掛かり |
| first_seen / last_seen | このパターンの発生期間 |
| issue_key | 代表事例のBacklog課題キー |

**action_hint の注意**: 「クローズ」等の弱い語しかない事例は断定せず needs_review=true になる。
運用チームの目視結果との突合で確定させ、確定したパターンは rules.yaml へ昇格させる。

## 作り方（大量データでも溢れない手順）

生データは全部読まず、機械抽出と集計・サンプル確認に分ける。

1. **機械抽出**: スクリプトで Backlog CSV / xlsx を構造化し、cases.jsonl の下書きを生成。個人名はこの段で機械的に落とす。
2. **集計・サンプル確認**: 「アラーム名ごとの件数」「頻出する判定理由」「代表例数件」だけを見て、guidelines.md と rules.yaml の方針を組み立てる。
3. **ルール化**: 何度も出る答えの決まったパターンを rules.yaml へ。曖昧なものは cases.jsonl と guidelines.md に委ねる。
4. **突合・改善**: 運用チームの目視結果とAI判定のズレを記録し、rules.yaml / guidelines.md に反映（ルールが増えるほどAIの出番が減る）。

## 注意

- **個人名を含めない**（担当者名・起票者名は cases.jsonl に入れない）
- 生データそのもの（backlog_issues.csv 等の未加工・個人名入り）はリポジトリにコミットしない
- `cases_raw.jsonl`（全件・集約前）はサニタイズ済みだがサイズが大きいため、コミットするのは集約後の `cases.jsonl` のみ（raw は build_cases.py でいつでも再生成できる）
- 判定に使うログ本文はすでに抽出済み（Phase2ツールの成果物）である前提
