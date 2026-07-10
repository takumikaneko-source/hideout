# -*- coding: utf-8 -*-
"""
GAS Web App 接続テスト（ローカル → サーバー上のGAS 起動確認）

このスクリプトは Google も AWS も認証しません。HTTPで GAS Web App を叩くだけです。
詳しい手順は「gas_test_手順.html」を参照。
"""

import json
import sys

# ===== ここだけ編集してください ============================================
WEBAPP_URL   = "https://script.google.com/a/macros/uni.iret.co.jp/s/AKfycbyrl4fPjqNfMVN4Ko2q9bqnYZMMGSVpSSJRRrecQVYU8qnFO894fWZ84HpgosiF5-_bGw/exec"  # GAS側のウェブアプリURL（末尾が /exec のもの）
SHARED_TOKEN = "taxi-test-2026"     # GAS側の SHARED_TOKEN と一致させる
SHEET_ID     = ""                     # 任意: シート読取も試すなら対象シートのIDを設定

# 社内ネットワークがSSL検査(プロキシ)をしている場合の対策:
CA_BUNDLE    = ""      # 会社配布のCA証明書(.pem)があればそのパスを設定（最優先・推奨）
VERIFY_SSL   = False    # 一時的な疎通確認のみ False 可（非推奨/MITMを許す）。本番は True
# ==========================================================================


def main():
    try:
        import requests
    except ImportError:
        print("[NG] requests が未導入です。次を実行してください: pip install requests")
        sys.exit(1)

    if WEBAPP_URL.startswith("ここに") or not WEBAPP_URL.endswith("/exec"):
        print("[NG] WEBAPP_URL を設定してください（末尾が /exec のウェブアプリURL）。")
        sys.exit(1)

    # 社内CA対策: OSの証明書ストア(Windows)を使う truststore があれば有効化
    if not CA_BUNDLE and VERIFY_SSL:
        try:
            import truststore
            truststore.inject_into_ssl()
            print("    （truststore: OSの証明書ストアを使用）")
        except ImportError:
            print("    （ヒント: SSLで失敗する場合は `pip install truststore` を推奨）")

    verify_arg = CA_BUNDLE if CA_BUNDLE else VERIFY_SSL
    if verify_arg is False:
        try:
            import urllib3
            urllib3.disable_warnings()
        except Exception:
            pass
        print("    （注意: SSL検証を無効化しています。疎通確認のみで使用してください）")

    # --- ① GET で起動 ---
    print("[1] GET で GAS を起動 ...")
    params = {"token": SHARED_TOKEN}
    if SHEET_ID:
        params["sheetId"] = SHEET_ID
    try:
        r = requests.get(WEBAPP_URL, params=params, timeout=30, verify=verify_arg)
        print("    HTTP", r.status_code)
        _show(r.text)
    except Exception as e:
        print("    [NG] 通信失敗:", repr(e))
        sys.exit(1)

    # --- ② POST で起動 ---
    print("[2] POST で GAS を起動 ...")
    payload = {"token": SHARED_TOKEN, "hello": "from python"}
    if SHEET_ID:
        payload["sheetId"] = SHEET_ID
    try:
        r2 = requests.post(
            WEBAPP_URL,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
            timeout=30,
            verify=verify_arg,
        )
        print("    HTTP", r2.status_code)
        _show(r2.text)
    except Exception as e:
        print("    [NG] 通信失敗:", repr(e))

    print("\n判定: 応答に \"ok\": true と \"message\": \"hello from GAS\" が出ていれば、"
          "ローカルからサーバー上のGAS起動に成功しています。")


def _show(text):
    snippet = text[:1200]
    print("    応答:", snippet)
    # JSONとして読めれば ok 判定を補助表示
    try:
        obj = json.loads(text)
        if obj.get("ok"):
            print("    -> OK（GAS起動成功）", "serverTime=" + str(obj.get("serverTime")))
            if "spreadsheetName" in obj:
                print("       シート読取も成功: ", obj.get("spreadsheetName"),
                      "/ A1 =", obj.get("a1"))
            if "sheetError" in obj:
                print("       （シート読取はエラー: ", obj.get("sheetError"), "）")
        else:
            print("    -> 応答はJSONだが ok=false:", obj.get("error"))
    except Exception:
        print("    -> 応答がJSONではありません（HTMLが返る場合: URLが /exec か, "
              "デプロイ済みか, アクセス=全員か を確認）")


if __name__ == "__main__":
    main()
