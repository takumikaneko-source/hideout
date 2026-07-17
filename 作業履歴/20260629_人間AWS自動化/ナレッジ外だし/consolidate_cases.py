# -*- coding: utf-8 -*-
"""
cases_raw.jsonl（Backlogから機械抽出した全事例）を、判定検索用にスリム化する。

同じアラーム・同じ対応要否の事例は数百件あっても情報としては重複するため、
「判定パターン（アラーム名 × 対応要否）ごとに、中身のある理由を持つ代表例を数件」
に集約する。発生回数(count)を残すので「このアラームは過去N回出た」という頻度情報は保つ。

  入力: cases_raw.jsonl（build_cases.py の出力・全件）
  出力: cases.jsonl（判定ツールが読む集約版）

AIは使わない。個人名は build_cases.py の段階で除去済み。
"""

import io
import json
import os
import collections

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(BASE_DIR, "cases_raw.jsonl")
OUT = os.path.join(BASE_DIR, "cases.jsonl")

# 1つの判定パターンあたり残す代表例の最大数（増やすと事例が増える／精度と件数のトレードオフ）
MAX_PER_PATTERN = 3

DISPO_KW = ["不要", "静観", "要", "対応", "再処理", "正常", "影響", "調査",
            "修正", "起票", "照会", "復旧", "クローズ", "問題", "仕様", "リトライ"]


def useful_reason(reason):
    """判定材料になる理由か（挨拶だけ・短すぎ・判定語なしを除く）"""
    r = (reason or "").strip()
    if len(r) < 8:
        return False
    return any(k in r for k in DISPO_KW)


def quality(c):
    """代表例として良い順に並べるためのスコア（大きいほど良い）"""
    r = c.get("reason") or ""
    s = 0
    if useful_reason(r):
        s += 100
    if not c.get("needs_review"):
        s += 20
    s += sum(3 for k in DISPO_KW if k in r)   # 判定語を多く含むほど良い
    s += min(len(r), 300) / 50                 # ある程度の長さを加点（上限あり）
    if c.get("error_summary"):
        s += 5
    return s


def main():
    if not os.path.exists(SRC):
        raise SystemExit(
            f"[エラー] 入力が見つかりません: {SRC}\n"
            "  build_cases.py を先に実行して cases_raw.jsonl を作成してください"
        )

    cases = []
    for line in io.open(SRC, encoding="utf-8"):
        line = line.strip()
        if line:
            cases.append(json.loads(line))

    # (アラーム名, 対応要否) でグループ化
    groups = collections.defaultdict(list)
    for c in cases:
        key = (c.get("alarm_name") or "", c.get("action_hint") or "")
        groups[key].append(c)

    out_records = []
    for (alarm, action), group in groups.items():
        count = len(group)
        dates = sorted(d for d in (c.get("created") for c in group) if d)
        first_seen = dates[0] if dates else ""
        last_seen = dates[-1] if dates else ""

        # 良い順に並べ、理由の重複（先頭60字が同じ）を除いて代表を選ぶ
        ranked = sorted(group, key=quality, reverse=True)
        reps, seen_reason = [], set()
        for c in ranked:
            rkey = (c.get("reason") or "")[:60]
            if rkey in seen_reason:
                continue
            seen_reason.add(rkey)
            reps.append(c)
            if len(reps) >= MAX_PER_PATTERN:
                break

        # このパターンに有用な理由が1つも無ければ、代表1件を「理由なし・要確認」として残す
        # （アラーム名で検索に引っかかるようにするため、完全には捨てない）
        if not any(useful_reason(c.get("reason")) for c in reps):
            reps = reps[:1]
            reps[0] = dict(reps[0])
            reps[0]["reason"] = "（判定理由の記録なし。過去の判断は要確認）"
            reps[0]["needs_review"] = True

        for idx, c in enumerate(reps):
            out_records.append({
                "alarm_name": alarm,
                "service": c.get("service", ""),
                "env": c.get("env", ""),
                "source_type": c.get("source_type", ""),
                "summary": c.get("summary", ""),
                "error_summary": c.get("error_summary", ""),
                "action_hint": action,
                "reason": c.get("reason", ""),
                "needs_review": c.get("needs_review", False),
                # 集約情報
                "count": count,                # このパターンの過去発生回数
                "reps": len(reps),             # うち代表として残した件数
                "first_seen": first_seen,
                "last_seen": last_seen,
                "issue_key": c.get("issue_key", ""),
                "source": "backlog:YAZAKIES_TAXICLOUD_OPS(集約)",
            })

    # 件数の多いパターンを上に（可読性のため）
    out_records.sort(key=lambda r: (-r["count"], r["alarm_name"]))

    with io.open(OUT, "w", encoding="utf-8") as w:
        for r in out_records:
            w.write(json.dumps(r, ensure_ascii=False) + "\n")

    # サマリ
    before = len(cases)
    after = len(out_records)
    patterns = len(groups)
    covered = sum(r["count"] for r in out_records if r["reps"] and True) if False else None
    print(f"入力(raw): {before}件")
    print(f"判定パターン(アラーム×対応要否): {patterns}種")
    print(f"出力(集約): {after}件  （{before//max(after,1)}分の1）")
    print(f"ファイルサイズ: {os.path.getsize(OUT):,} bytes")
    print(f"出力先: {OUT}")


if __name__ == "__main__":
    main()
