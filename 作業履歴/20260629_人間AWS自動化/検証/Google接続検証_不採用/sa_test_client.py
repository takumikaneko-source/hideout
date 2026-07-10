# -*- coding: utf-8 -*-
"""
サービスアカウント(SA) 接続テスト

目的: SA鍵で スプレッドシートを読み書きできるか（＝SA方式が組織で使えるか）を検証する。
前提: 事前に SA を作成し、SA鍵(JSON)をダウンロードし、
      対象シートを SA のメールアドレス(client_email)に「編集者」で共有しておくこと。
詳しい手順は「sa_test_手順.html」を参照。

※ このスクリプトは AWS の資格情報を扱いません（Googleのみ）。
"""

import os
import sys
import json

# ===== ここだけ編集してください ============================================
KEY_FILE   = "sa_key.json"     # ダウンロードしたSA鍵JSON（スクリプトと同じフォルダ）
SHEET_ID   = "対象シートのID"  # URLの /d/<ID>/ の部分。推奨: テスト用ダミーシート
ALLOW_WRITE = True             # 書き込みも試す（ダミーシート推奨）

# 社内ネットワークがSSL検査(プロキシ)をしている場合の対策:
CA_BUNDLE  = ""    # 会社配布のCA証明書(.pem)があればパスを設定。空なら truststore(OS証明書ストア)を使用
# ==========================================================================


def main():
    # --- 社内SSL検査対策 ---
    if CA_BUNDLE:
        os.environ["REQUESTS_CA_BUNDLE"] = CA_BUNDLE
        os.environ["SSL_CERT_FILE"] = CA_BUNDLE
        print("（CA_BUNDLE を使用:", CA_BUNDLE, "）")
    else:
        try:
            import truststore
            truststore.inject_into_ssl()
            print("（truststore: OSの証明書ストアを使用）")
        except ImportError:
            print("（ヒント: SSLで失敗する場合は `pip install truststore`、"
                  "または CA_BUNDLE に社内CA(.pem)を指定）")

    # --- パッケージ確認 ---
    try:
        import gspread
        from google.oauth2.service_account import Credentials
    except ImportError:
        print("[NG] パッケージ未導入: pip install gspread google-auth truststore")
        sys.exit(1)

    if not os.path.exists(KEY_FILE):
        print(f"[NG] SA鍵が見つかりません: {KEY_FILE}")
        print("    GCPで サービスアカウント → キー → 鍵を追加(JSON) を作成し、この名前で配置してください。")
        sys.exit(1)
    if SHEET_ID.startswith("対象") or not SHEET_ID.strip():
        print("[NG] SHEET_ID を設定してください（URLの /d/<ID>/ の部分）。")
        sys.exit(1)

    # --- SAのメール（共有先）を表示 ---
    try:
        with open(KEY_FILE, encoding="utf-8") as f:
            sa_email = json.load(f).get("client_email", "(不明)")
        print("使用するSAのメール:", sa_email)
        print("  -> このメールに対象シート(または共有ドライブ)を『編集者』で共有しておくこと")
    except Exception as e:
        print("（鍵JSONの読取に注意:", repr(e), "）")

    SCOPES = [
        "https://www.googleapis.com/auth/spreadsheets",
        "https://www.googleapis.com/auth/drive",
    ]
    try:
        creds = Credentials.from_service_account_file(KEY_FILE, scopes=SCOPES)
        gc = gspread.authorize(creds)
    except Exception as e:
        print("[NG] 認証情報の作成に失敗:", repr(e))
        sys.exit(1)

    # --- 読み取りテスト ---
    print("[1] シートを開いて読み取り ...")
    try:
        sh = gc.open_by_key(SHEET_ID)
    except Exception as e:
        print("[NG] シートを開けません:", repr(e))
        print("    よくある原因: SAにシートが共有されていない / Sheets API未有効 / IDの誤り")
        sys.exit(1)
    print("    読み取り成功 ファイル名:", repr(sh.title))
    print("    シート一覧:", [w.title for w in sh.worksheets()])

    if not ALLOW_WRITE:
        print("[2] 書き込みテストはスキップ（ALLOW_WRITE=False）")
        print("\n[OK] 読み取り成功。SAでのアクセスが可能です。")
        return

    # --- 書き込みテスト（一時シートで実施。既存データに触れません） ---
    print("[2] 書き込みテスト（一時シート作成→書込→読戻→削除） ...")
    tmp = None
    try:
        tmp = sh.add_worksheet(title="_sa_test_tmp", rows=2, cols=2)
        tmp.update_acell("A1", "sa_write_ok")
        back = tmp.acell("A1").value
        print("    書き込み結果:", back, "（一致すれば成功）")
    except Exception as e:
        print("[NG] 書き込み失敗（閲覧のみ権限の可能性）:", repr(e))
        if tmp is None:
            sys.exit(1)
    finally:
        if tmp is not None:
            try:
                sh.del_worksheet(tmp)
                print("    後片付け: 一時シートを削除しました")
            except Exception as e:
                print("    一時シート削除に失敗（'_sa_test_tmp' を手動削除）:", repr(e))

    print("\n[OK] 読み書きとも成功。SA方式で本実装に進めます。")


if __name__ == "__main__":
    main()
