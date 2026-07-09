---
name: hideout-repository
description: hideout クロスプロジェクト知識庫の構成・運用方針・メモリ管理ガイド
metadata:
  type: project
---

# hideout リポジトリ

**hideout** = クロスプロジェクト型の知識庫・資料アーカイブ（`C:\source\hideout`、2026-07-09 初期化）。

## 用途・スコープ

- taxi-cloud および他プロジェクトの設計・実装・運用ナレッジを一元管理
- 参考資料・手順書・設計説明の保管
- チーム間・プロジェクト間の知識共有
- 過去実績の検索・再利用

## リポジトリ構成

```
hideout/
├── 作業履歴/                    # プロジェクト実施履歴（日付フォルダ）
│   ├── YYYYMMDD_プロジェクト名/
│   │   ├── README.md            # 作業内容記録（必須）
│   │   ├── 設計資料/
│   │   └── 成果物/
│   ├── 20260709_hideout初期化/
│   ├── 20260629_人間AWS自動化/
│   └── ...
│
├── 参考資料/                    # 設計資料・仕様書
├── テンプレート/                # 共通資産・テンプレート（アイコン、メモ等）
├── 知識ベース/                  # 横断的ナレッジ（sql等）
│
├── CLAUDE.md                    # Claude 利用ガイド（本ファイルの姉妹）
├── README.md
└── .claude/
    └── memory/
        ├── MEMORY.md            # メモリインデックス
        └── hideout-repository.md # このファイル
```

## 運用方針

### 新規作業開始時
1. `作業履歴/YYYYMMDD_プロジェクト名/` フォルダを作成
2. 設計・実装・テスト結果を格納
3. README.md に作業内容・背景・結果を記録
4. 完了時に `git add & git commit & git push`

### 資料配置ルール
- **参照資料・設計書・仕様** → `参考資料/`
- **テンプレート・共通部品・アイコン** → `テンプレート/`
- **実装履歴・成果物・試行錯誤記録** → `作業履歴/YYYYMMDD_*/`
- **共有ナレッジ・教訓・パターン集** → `知識ベース/`

## Git 管理

- **リモート**: https://github.com/takumikaneko-source/hideout.git
- **デフォルトブランチ**: master
- **コミットメッセージ形式**: 日本語、`【プロジェクト】内容` 形式推奨
  例: `【taxi-cloud】CloudWatchログ収集ツール配布版作成`

## セキュリティ・機密情報管理

- **.gitignore で継続的に除外**:
  - AWS 認証情報（`~/.aws/*`）
  - パスワード・秘密鍵（`PW/`, `*.key`, `*.pem`）
  - Google Sheets（`.gsheet` バイナリ）
  - 一時ファイル（`tmp/`, `99_tmp/`, `*.bak`）

- **作成時の注意**:
  - 資料に機密情報を含めない
  - 個人名・役職名をぼかす（「運用チーム」等）
  - AWS認証情報は絶対に含めない

## 関連メモリ

[[taxi-cloud-aws-cloudwatch-tool]] — ログ収集ツール進行中（hideout での作業履歴も格納）
[[no-read-aws-google-credentials]] — AWS認証情報読み込み禁止
[[avoid-ai-cliche-wording]] — AI臭い言い回し避ける
[[blur-individual-names-in-docs]] — 個人名ぼかし
[[default-deliverable-format-html]] — HTML資料形式

## 初期状態（2026-07-09）

**初期コミット:**
- `8badbf5` 【再構成】hideout ディレクトリ構造を標準化
- `01354b2` 【初期化】hideout リポジトリ作成・Google Drive 資料フォルダを移行

**移行元**: Google Drive `G:\マイドライブ`
- 00_共通 → テンプレート
- 02_資料 → 参考資料
- 04_作業履歴 → 作業履歴
- 08_knowledges → 知識ベース
- 総175ファイル（機密情報・認証情報除外）

## 今後の拡張

- 他プロジェクトの資料・ナレッジ追加
- テンプレート・ツール類の共通化
- チーム間での知識共有
