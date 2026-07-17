# -*- coding: utf-8 -*-
"""配布ツール一式 環境チェック（スキャン）

第三者の環境で、ツールを動かすのに必要なものが揃っているかを点検し、
足りないものと対処方法を一覧で表示します。
このスクリプトは AI も AWS も呼ばず、資格情報（アクセスキー等）も読みません。安全です。
"""
import os
import sys
import shutil
import subprocess
import importlib

# 配布セットのルート（1_ログ収集ツール がある場所）を基準にする。
# 本体は program/ 配下にあるが、ツール群はその1つ上（配布セット直下）にある。
_HERE = os.path.dirname(os.path.abspath(__file__))
if os.path.isdir(os.path.join(_HERE, "1_ログ収集ツール")):
    ROOT = _HERE
elif os.path.isdir(os.path.join(os.path.dirname(_HERE), "1_ログ収集ツール")):
    ROOT = os.path.dirname(_HERE)
else:
    ROOT = _HERE
COLLECT = os.path.join(ROOT, "1_ログ収集ツール")
JUDGE = os.path.join(ROOT, "2_判定ツール")

OK, NG, OPT = "[ OK ]", "[要対応]", "[ 任意 ]"
todo = []   # 対処が必要な項目


def head(title):
    print("\n" + "=" * 56)
    print("  " + title)
    print("=" * 56)


def item(mark, name, detail=""):
    print(f"  {mark} {name}" + (f"  … {detail}" if detail else ""))


def need(msg):
    todo.append(msg)


def check_pkg(module, label, required, folder):
    try:
        importlib.import_module(module)
        item(OK, label, "導入済み")
        return True
    except Exception:
        item(NG if required else OPT, label, "未導入")
        if required:
            need(f"{label} が未導入 → 配布セット直下の「セットアップ.bat」を実行"
                 f"（または「{folder}\\program」で pip install -r requirements.txt）")
        return False


def find_claude():
    """claude 実行ファイルを PATH・npm標準location・where から探す。"""
    for n in ("claude", "claude.cmd", "claude.exe"):
        p = shutil.which(n)
        if p:
            return p
    cand = os.path.join(os.environ.get("APPDATA", ""), "npm", "claude.cmd")
    if os.path.exists(cand):
        return cand
    try:
        out = subprocess.run(["cmd", "/c", "where", "claude"],
                             capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=10).stdout
        for line in (out or "").splitlines():
            line = line.strip()
            if line and os.path.exists(line):
                return line
    except Exception:
        pass
    return None


def main():
    print("=" * 56)
    print("  アラート対応ツール 環境チェック")
    print("=" * 56)
    print("  ※ AI も AWS も呼びません。資格情報も読みません。")

    # ---- Python 本体 ----
    head("Python 本体")
    exe = sys.executable or ""
    item(OK, "バージョン", sys.version.split()[0])
    item(OK, "実行ファイル", exe)
    # Microsoft Store 版 Python は AppData がリダイレクトされ、実ファイルが見えず
    # claude.cmd 等を「無い」と誤判定することがある。実地テストで確認する。
    is_store = "windowsapps" in exe.lower()
    can_see_self = os.path.exists(os.path.abspath(__file__)) and os.path.isdir(ROOT)
    if is_store or not can_see_self:
        item(NG, "Python 種別", "Microsoft Store 版の疑い（ファイルが見えないことがある）")
        need("Python は python.org 版 / pyenv 版（実体）を使う。実行batは実体を自動選択します。")
    else:
        item(OK, "Python 種別", "実体（サンドボックスではない）")

    # ---- ① ログ収集ツール ----
    head("① ログ収集ツール")
    check_pkg("boto3", "boto3 (AWS SDK)", True, "1_ログ収集ツール")
    check_pkg("openpyxl", "openpyxl (Excel)", True, "1_ログ収集ツール")
    check_pkg("truststore", "truststore (社内証明書対応)", False, "1_ログ収集ツール")

    aws = shutil.which("aws")
    item(OK if aws else OPT, "AWS CLI", aws or "見つからない（スイッチロール運用に必要）")
    awscfg = os.path.join(os.path.expanduser("~"), ".aws", "config")
    item(OK if os.path.exists(awscfg) else OPT, "AWS 設定(~/.aws/config)",
         "あり（中身は読みません）" if os.path.exists(awscfg) else "無い")

    cin = os.path.join(COLLECT, "INPUT")
    xin = [f for f in (os.listdir(cin) if os.path.isdir(cin) else []) if f.lower().endswith(".xlsx")]
    item(OK if xin else OPT, "入力xlsx (INPUT フォルダ)",
         ", ".join(xin) if xin else "INPUT に .xlsx が未配置")

    # ---- ② 判定ツール ----
    head("② 判定ツール")
    check_pkg("openpyxl", "openpyxl (Excel)", True, "2_判定ツール")
    check_pkg("yaml", "PyYAML", True, "2_判定ツール")
    check_pkg("truststore", "truststore (社内証明書対応)", False, "2_判定ツール")
    check_pkg("anthropic", "anthropic (APIバックエンド利用時のみ)", False, "2_判定ツール")

    for kf in ("rules.yaml", "cases.jsonl", "guidelines.md", "system_context.md"):
        p = os.path.join(JUDGE, "ナレッジ", kf)
        ok = os.path.exists(p)
        item(OK if ok else NG, f"ナレッジ {kf}", "あり" if ok else "無い")
        if not ok:
            need(f"ナレッジ不足: {p}")

    claude = find_claude()
    item(OK if claude else NG, "Claude CLI (サブスク)", claude or "未導入")
    if not claude:
        need("Claude CLI 未導入 → npm install -g @anthropic-ai/claude-code → `claude` でログイン。"
             "社内proxyでSSLエラー時は  npm config set cafile <社内CA.pem>")
    has_key = bool(os.environ.get("ANTHROPIC_API_KEY"))
    item(OK if has_key else OPT, "ANTHROPIC_API_KEY",
         "設定あり" if has_key else "未設定（APIバックエンド利用時のみ必要。サブスクなら不要）")

    jin = os.path.join(COLLECT, "OUTPUT")
    xjin = [f for f in (os.listdir(jin) if os.path.isdir(jin) else []) if f.lower().endswith(".xlsx")]
    item(OK if xjin else OPT, "判定の入力(=①の出力)",
         ", ".join(xjin) if xjin else "まだ①を実行していない")

    # ---- 出力フォルダの書き込み ----
    head("出力フォルダ 書き込み確認")
    for label, d in (("① 収集 OUTPUT", os.path.join(COLLECT, "OUTPUT")),
                     ("② 判定 OUTPUT", os.path.join(JUDGE, "OUTPUT"))):
        try:
            os.makedirs(d, exist_ok=True)
            t = os.path.join(d, "_writetest.tmp")
            with open(t, "w") as f:
                f.write("ok")
            os.remove(t)
            item(OK, label, "書き込み可")
        except Exception as e:
            item(NG, label, f"書き込み不可: {e}")
            need(f"{d} に書き込めません（権限・同期フォルダのロックを確認）")

    # ---- まとめ ----
    head("まとめ")
    if not todo:
        print("  すべて良好です。①「収集実行.bat」→ ②「判定実行.bat」の順に動かせます。")
        print("  （②はまず settings.py の MAX_ROWS を小さくして試すのがおすすめ）")
    else:
        print(f"  対応が必要な項目が {len(todo)} 件あります:")
        for i, m in enumerate(todo, 1):
            print(f"   {i}. {m}")
    print()


if __name__ == "__main__":
    main()
