# -*- coding: utf-8 -*-
"""
OAuthユーザー認証 接続テスト

目的: 「自分（ログインユーザー）として Google に OAuth 認証し、スプレッドシートを
      読み書きできるか」＝ OAuth方式がこの組織で使えるか を検証する。
前提: GCPで OAuthクライアントID（デスクトップ）を発行し、credentials.json として配置。
詳しい手順は「oauth_test_手順.html」を参照。

※ このスクリプトは AWS の資格情報を扱いません（Googleのみ）。
"""

import os
import sys

# ===== ここだけ編集してください ============================================
CREDENTIALS_FILE = "credentials.json"   # OAuthクライアント（デスクトップ）のJSON
TOKEN_FILE       = "token.json"         # 初回認証後に自動生成（再認証を省くため）
SHEET_ID         = "対象シートのID"      # URLの /d/<ID>/。推奨: 自分が見えるテスト用ダミー
ALLOW_WRITE      = True                  # 書き込みも試す（ダミーシート推奨）

# 社内ネットワークがSSL検査(プロキシ)をしている場合の対策:
CA_BUNDLE        = ""    # 会社配布のCA証明書(.pem)があればパスを設定。空なら truststore(OS証明書ストア)を使用
# ==========================================================================

SCOPES = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]


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
        from google.oauth2.credentials import Credentials
        from google.auth.transport.requests import Request
        from google_auth_oauthlib.flow import InstalledAppFlow
    except ImportError:
        print("[NG] パッケージ未導入: pip install gspread google-auth google-auth-oauthlib truststore")
        sys.exit(1)

    if not os.path.exists(CREDENTIALS_FILE):
        print(f"[NG] OAuthクライアントJSONが見つかりません: {CREDENTIALS_FILE}")
        print("    GCPで『OAuthクライアントID(デスクトップ)』を発行し、この名前で配置してください。")
        sys.exit(1)
    if SHEET_ID.startswith("対象") or not SHEET_ID.strip():
        print("[NG] SHEET_ID を設定してください（URLの /d/<ID>/ の部分）。")
        sys.exit(1)

    # --- 認証（初回はブラウザが開く）★関門① ---
    print("[1] OAuth認証を開始（初回はブラウザが開きます）...")
    creds = None
    try:
        if os.path.exists(TOKEN_FILE):
            creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)
        if not creds or not creds.valid:
            if creds and creds.expired and creds.refresh_token:
                creds.refresh(Request())
            else:
                flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_FILE, SCOPES)
                creds = flow.run_local_server(port=0)
            with open(TOKEN_FILE, "w", encoding="utf-8") as f:
                f.write(creds.to_json())
    except Exception as e:
        print("[NG] 認証に失敗しました。ブラウザで『アクセスをブロック』『管理者の承認が必要』と"
              "表示された場合は、組織のOAuthアプリ制限が原因の可能性が高いです。")
        print("    詳細:", repr(e))
        sys.exit(1)
    print("    -> 認証OK（組織のOAuthアプリ接続は許可されています）")

    import gspread
    gc = gspread.authorize(creds)

    # --- 読み取りテスト ★関門② ---
    print("[2] シートを開いて読み取り ...")
    try:
        sh = gc.open_by_key(SHEET_ID)
    except Exception as e:
        print("[NG] シートを開けません:", repr(e))
        print("    よくある原因: シートにアクセス権がない / Sheets API未有効 / IDの誤り")
        sys.exit(1)
    print("    読み取り成功 ファイル名:", repr(sh.title))
    print("    シート一覧:", [w.title for w in sh.worksheets()])

    if not ALLOW_WRITE:
        print("[3] 書き込みテストはスキップ（ALLOW_WRITE=False）")
        print("\n[OK] 読み取りまで成功。OAuthポリシー・読み取りは問題ありません。")
        return

    # --- 書き込みテスト（一時シートで実施。既存データに触れません） ---
    print("[3] 書き込みテスト（一時シート作成→書込→読戻→削除） ...")
    tmp = None
    try:
        tmp = sh.add_worksheet(title="_oauth_test_tmp", rows=2, cols=2)
        tmp.update_acell("A1", "oauth_write_ok")
        print("    書き込み結果:", tmp.acell("A1").value, "（一致すれば成功）")
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
                print("    一時シート削除に失敗（'_oauth_test_tmp' を手動削除）:", repr(e))

    print("\n[OK] 読み書きとも成功。OAuth方式で本実装に進めます。")


if __name__ == "__main__":
    main()
