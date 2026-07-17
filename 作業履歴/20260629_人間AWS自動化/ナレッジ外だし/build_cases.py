# -*- coding: utf-8 -*-
"""
Backlog(YAZAKIES_TAXICLOUD_OPS)の抽出CSVから cases.jsonl を機械生成する。
AIは使わない。個人名・@メンション・URL・画像参照は落とす。
判定理由(comments)から対応要否を暫定推定し、確信が持てないものは needs_review=true を立てる。
最終確認は運用チームの目視。
"""
import csv, io, re, json, os, collections

SRC = r'C:\source\hideout\作業履歴\20260629_人間AWS自動化\Backlog集計\抽出結果ファイル\backlog_issues_赤バックログ.csv'
# 全件の抽出結果。この後 consolidate_cases.py で集約して判定用 cases.jsonl を作る
OUT = r'C:\source\hideout\作業履歴\20260629_人間AWS自動化\ナレッジ外だし\cases_raw.jsonl'
REPORT = r'C:\Users\takumi.kaneko\AppData\Local\Temp\claude\C--source\29ef3d5e-1b65-4bae-9737-e47db23262ca\scratchpad\cases_report.txt'

csv.field_size_limit(10**7)
SERVICES = {'aegis', 'blitz', 'buster', 'duel', 'strike'}
ORG_PREFIX_RE = re.compile(r'^(?:IRET|IRT|iret|irt|株式会社|㈱|KDDI|YZK)\s*')
COMMENT_AUTHOR_CAP_RE = re.compile(r'\[\d{4}-\d{2}-\d{2}T[\d:]+Z\s+([^\]]+)\]')

# アラーム名: service-env-...(-alarm)
ALARM_RE = re.compile(r'([a-z][a-z0-9]*-(?:prd|stg|stgtmp|dev\d?|dev)-[a-z0-9\-]+)')
ENV_RE = re.compile(r'-(prd|stgtmp|stg|dev\d?|dev)-')
ERROR_LINE_RE = re.compile(r'\[ERROR\][^\n\r]*')
# コメント著者プレフィックス [ISO日時 氏名]
AUTHOR_RE = re.compile(r'\[\d{4}-\d{2}-\d{2}T[\d:]+Z[^\]]*\]')
MENTION_RE = re.compile(r'@[^\s@]+(?:[ 　][^\s@]+)?')
URL_RE = re.compile(r'https?://\S+')
IMAGE_RE = re.compile(r'#image\([^)]*\)')
CODE_TAG_RE = re.compile(r'\{/?code\}|\{/?quote\}')

def collect_name_tokens(raw_name, tokens):
    """『IRT君塚 まどか』等から氏名トークンを集める。"""
    if not raw_name:
        return
    name = ORG_PREFIX_RE.sub('', raw_name.strip())
    parts = re.split(r'[ 　]+', name)
    for p in parts:
        p = p.strip()
        if len(p) >= 2 and not re.search(r'[A-Za-z0-9@]', p):
            tokens.add(p)
    joined = ''.join(parts)
    if len(joined) >= 2 and not re.search(r'[A-Za-z0-9@]', joined):
        tokens.add(joined)

NAME_TOKENS = set()          # 全行走査後に確定
NAME_REDACT_RE = None        # build後にコンパイル

def sanitize(text):
    if not text:
        return ''
    t = AUTHOR_RE.sub(' ', text)
    t = MENTION_RE.sub('', t)
    t = URL_RE.sub('', t)
    t = IMAGE_RE.sub('', t)
    t = CODE_TAG_RE.sub(' ', t)
    if NAME_REDACT_RE is not None:
        t = NAME_REDACT_RE.sub('', t)
    t = re.sub(r'KDDI様?|ＫＤＤＩ', 'パートナー', t)
    t = re.sub(r'[ \t　]+', ' ', t)
    t = re.sub(r'\s*\n\s*', ' ', t)
    return t.strip()

# 対応要否の暫定推定に使うキーワード
# strong = その文だけで判定を断定してよい語 / weak = 手掛かりにはなるが断定しない語
STRONG_FUYOU = ['対応不要', '対応は不要', '対応なし', '不要のため', '静観',
                '業務影響なし', '業務影響はなし', '業務影響はありません', '影響なし', '影響はありません',
                '問題なし', '問題ありません', '問題ございません',
                '正常終了', '正常な挙動', '仕様通り', '仕様どおり', '再発しない',
                '取り込み不要', 'リカバリ不要', '復旧済', '解消済', '取り込み成功',
                '再処理され', '自動で復旧']
STRONG_YOU = ['対応が必要', '対応必要', '要対応', '再取り込み', '再連携',
              'エスカレーション', '調査を依頼', '調査依頼',
              '顧客に照会', '顧客へ照会', '顧客へ問い合わせ', '顧客への照会',
              '修正が必要', '修正対応', '改修', 'リカバリ作業', '起票し']
WEAK_FUYOU = ['クローズ']
WEAK_YOU = ['開発側', '開発へ', '開発担当', '照会', '起票']

DISPO_SENTENCE_KW = STRONG_FUYOU + STRONG_YOU + WEAK_FUYOU + WEAK_YOU

def split_sentences(text):
    # コメント区切り(---)も文境界として扱い、会議メモと判定文が混ざらないようにする
    return [s for s in re.split(r'(?<=[。\.])\s*|\n|\s+---\s*|^---\s*', text) if s.strip()]

def infer_action(sents):
    """文リスト（新しいコメント順）から対応要否を推定。
    strong語を含む最初の文＝最新の断定的な判断を採用する。
    戻り値: (action, needs_review)"""
    for s in sents:
        sf = any(k in s for k in STRONG_FUYOU)
        sy = any(k in s for k in STRONG_YOU)
        if sf or sy:
            if '静観' in s:
                return '静観', False
            if sf and sy:
                return '要', True   # 同一文に両方→安全側・要目視
            return ('不要' if sf else '要'), False
    # strongが無い場合はweakで暫定判定（要目視）
    blob = ' '.join(sents)
    if any(k in blob for k in WEAK_YOU):
        return '要確認', True
    if any(k in blob for k in WEAK_FUYOU):
        return '不要', True   # 「クローズお願いします」のみ等
    return '要確認', True

NOISE_KW = ['打ち合わせ', '定例', '期限延長', '期限設定', '棚卸', '再度確認につき', '次回',
            'ありがとうございます', 'ありがとうございました', 'よろしくお願い', 'お願いいたします']

def is_noise(sent):
    # 挨拶・スケジュール系のみで強い判定語を含まない文はノイズとして落とす
    return any(k in sent for k in NOISE_KW) and not any(k in sent for k in (STRONG_FUYOU + STRONG_YOU))

def clean_sentences(comments_clean):
    return [s.strip() for s in split_sentences(comments_clean) if s.strip() and not is_noise(s)]

def pick_reason(sents):
    # 強い判定語を含む文を優先して1〜2文抜き出す
    strong = [s for s in sents if any(k in s for k in (STRONG_FUYOU + STRONG_YOU))]
    if strong:
        return ' '.join(strong[:2])[:300]
    hits = [s for s in sents if any(k in s for k in DISPO_SENTENCE_KW)]
    if hits:
        return ' '.join(hits[:2])[:300]
    return (sents[0][:200] if sents else '')

def extract_alarm(summary, description):
    for src in (summary, description):
        m = ALARM_RE.search(src or '')
        if m:
            return m.group(1)
    return ''

def guess_service(alarm):
    if alarm:
        head = alarm.split('-', 1)[0]
        if head in SERVICES:
            return head
    return ''

def guess_env(alarm, summary):
    m = ENV_RE.search(alarm or '')
    if m:
        return m.group(1)
    m2 = re.search(r'【(PRD|STG|DEV\d?)】', summary or '', re.I)
    return m2.group(1).lower() if m2 else ''

def guess_source_type(alarm, description):
    blob = (alarm + ' ' + (description or '')).lower()
    if any(x in blob for x in ['sfn', 'statemachine', 'states', 'stepfunction', 'ステートマシン']):
        return 'stepfunctions'
    if 'ecs' in blob or 'fargate' in blob:
        return 'ecs'
    return 'lambda'

def first_error(description):
    m = ERROR_LINE_RE.search(description or '')
    if m:
        s = sanitize(m.group(0))
        return s[:200]
    return ''

def to_date(s):
    return (s or '')[:10]

def main():
    global NAME_REDACT_RE
    rows_out = []
    stats = collections.Counter()
    alarm_counter = collections.Counter()
    skipped = collections.Counter()

    # --- 1パス目: 氏名辞書を作る（assignee/createdUser/コメント著者から）---
    with io.open(SRC, 'r', encoding='utf-8-sig', newline='') as f:
        for row in csv.DictReader(f):
            collect_name_tokens(row.get('assignee'), NAME_TOKENS)
            collect_name_tokens(row.get('createdUser'), NAME_TOKENS)
            for m in COMMENT_AUTHOR_CAP_RE.finditer(row.get('comments') or ''):
                collect_name_tokens(m.group(1), NAME_TOKENS)
    if NAME_TOKENS:
        toks = sorted(NAME_TOKENS, key=len, reverse=True)  # 長い語から
        NAME_REDACT_RE = re.compile('|'.join(re.escape(t) for t in toks))

    # --- 2パス目: 本抽出 ---
    with io.open(SRC, 'r', encoding='utf-8-sig', newline='') as f:
        r = csv.DictReader(f)
        for row in r:
            if row.get('issueType') != 'エラーログ':
                skipped[row.get('issueType') or '(空)'] += 1
                continue
            summary = row.get('summary') or ''
            description = row.get('description') or ''
            comments_clean = sanitize(row.get('comments') or '')
            alarm = extract_alarm(summary, description)
            sents = clean_sentences(comments_clean)
            reason = pick_reason(sents)
            action, needs_review = infer_action(sents) if sents else ('要確認', True)
            if not reason:
                needs_review = True
            rec = {
                'issue_key': row.get('issueKey'),
                'created': to_date(row.get('created')),
                'status': row.get('status'),
                'service': guess_service(alarm),
                'env': guess_env(alarm, summary),
                'source_type': guess_source_type(alarm, description),
                'alarm_name': alarm,
                'summary': re.sub(r'^【[^】]*】', '', summary).strip()[:120],
                'error_summary': first_error(description),
                'action_hint': action,
                'reason': reason,
                'needs_review': needs_review,
                'source': 'backlog:YAZAKIES_TAXICLOUD_OPS',
            }
            rows_out.append(rec)
            stats[action] += 1
            if alarm:
                alarm_counter[alarm] += 1

    with io.open(OUT, 'w', encoding='utf-8') as w:
        for rec in rows_out:
            w.write(json.dumps(rec, ensure_ascii=False) + '\n')

    with io.open(REPORT, 'w', encoding='utf-8') as w:
        w.write(f'出力件数(エラーログ種別): {len(rows_out)}\n')
        w.write(f'出力先: {OUT}\n')
        w.write(f'氏名辞書トークン数(除去対象): {len(NAME_TOKENS)}\n\n')
        w.write('=== 対応要否(暫定)内訳 ===\n')
        for k, c in stats.most_common():
            w.write(f'  {k}: {c}\n')
        nr = sum(1 for x in rows_out if x['needs_review'])
        na = sum(1 for x in rows_out if not x['alarm_name'])
        w.write(f'\nneeds_review(要目視): {nr}\n')
        w.write(f'alarm_name抽出できず: {na}\n')
        w.write('\n=== 除外したissueType ===\n')
        for k, c in skipped.most_common():
            w.write(f'  {k}: {c}\n')
        w.write('\n=== 頻出アラーム 上位15 ===\n')
        for k, c in alarm_counter.most_common(15):
            w.write(f'  {c:4d}  {k}\n')
        w.write('\n=== サンプル10件 ===\n')
        for rec in rows_out[:10]:
            w.write(json.dumps(rec, ensure_ascii=False) + '\n')

    print('done:', len(rows_out), 'records ->', OUT)

if __name__ == '__main__':
    main()
