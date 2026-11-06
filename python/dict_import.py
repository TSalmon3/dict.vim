#!/usr/bin/env python3
"""dict.vim 数据导入器: 中文 JSON + ECDICT CSV → SQLite.

中英文数据均为必需。

用法: dict_import.py <源目录> <db路径> [--force]

表结构:
  char    (char PK, base, detail, related)  -- character/ 三文件按字合并
  word    (word PK, pinyin, abbr, explanation, entry)  -- word/word.json + idiom.json 补缺
  variant (trad PK, simp)                   -- 繁体→简体映射
  word_en (word PK, phonetic, definition, translation, pos, collins, oxford, tag,
           bnc, frq, exchange)              -- ECDICT word_en/stardict.csv
  meta    (key, value)
"""
import csv
import json
import os
import sqlite3
import sys
import time


def die(msg):
    print('[dict-import] 错误: ' + msg)
    sys.exit(1)


def load(path):
    """兼容两种格式: 标准 JSON 数组 / 一行一个对象的宽松格式(char_base、char_detail)."""
    with open(path, encoding='utf-8') as f:
        text = f.read()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    rows, bad = [], 0
    for line in text.splitlines():
        line = line.strip().rstrip(',')
        if not line or line in ('[', ']'):
            continue
        try:
            rows.append(json.loads(line))
        except json.JSONDecodeError:
            bad += 1
    print('[dict-import] 警告: %s 有 %d 行解析失败(已跳过)' % (os.path.basename(path), bad), flush=True)
    return rows


def compact(obj):
    return json.dumps(obj, ensure_ascii=False, separators=(',', ':'))


def s(v):
    return v if isinstance(v, str) else ('' if v is None else str(v))


def unescape_text(v):
    """ECDICT 字段里的字面 \\n / \\r\\n 还原为换行, 并清理行尾空白."""
    v = s(v)
    if v == '':
        return ''
    v = v.replace('\r\n', '\n').replace('\r', '\n')
    v = v.replace('\\r\\n', '\n').replace('\\n', '\n').replace('\\r', '\n')
    return '\n'.join(line.rstrip() for line in v.split('\n')).strip()


def main():
    args = sys.argv[1:]
    force = '--force' in args
    args = [a for a in args if a != '--force']
    if len(args) < 2:
        die('用法: dict_import.py <源目录> <db路径> [--force]')
    src, db = args[0].rstrip('/'), args[1]

    for f in ['character/char_base.json', 'character/char_detail.json',
              'character/related.json', 'word/word.json',
              'word_en/stardict.csv']:
        if not os.path.isfile(os.path.join(src, f)):
            die('缺少 ' + f)

    if os.path.exists(db):
        if not force:
            print('[dict-import] %s 已存在, 跳过 (用 :DictInit! 重建)' % db)
            return
        os.remove(db)
    os.makedirs(os.path.dirname(db) or '.', exist_ok=True)

    con = sqlite3.connect(db)
    con.executescript("""
    PRAGMA journal_mode = OFF;
    PRAGMA synchronous  = OFF;
    PRAGMA temp_store   = MEMORY;
    CREATE TABLE meta    (key TEXT PRIMARY KEY, value TEXT) WITHOUT ROWID;
    CREATE TABLE char    (char TEXT PRIMARY KEY, base TEXT, detail TEXT, related TEXT) WITHOUT ROWID;
    CREATE TABLE word    (word TEXT PRIMARY KEY, pinyin TEXT, abbr TEXT, explanation TEXT, entry TEXT) WITHOUT ROWID;
    CREATE TABLE variant (trad TEXT PRIMARY KEY, simp TEXT) WITHOUT ROWID;
    CREATE TABLE word_en (
      word        TEXT PRIMARY KEY COLLATE NOCASE,
      phonetic    TEXT,
      definition  TEXT,
      translation TEXT,
      pos         TEXT,
      collins     TEXT,
      oxford      TEXT,
      tag         TEXT,
      bnc         TEXT,
      frq         TEXT,
      exchange    TEXT
    ) WITHOUT ROWID;
    """)

    # ---- char: base + detail + related 按字合并 ----
    t0 = time.time()
    base_rows = load(os.path.join(src, 'character/char_base.json'))
    detail_rows = load(os.path.join(src, 'character/char_detail.json'))
    related_rows = load(os.path.join(src, 'character/related.json'))
    details = {d['char']: d for d in detail_rows if isinstance(d.get('char'), str) and len(d['char']) == 1}
    relateds = {r['char']: r for r in related_rows if isinstance(r.get('char'), str) and len(r['char']) == 1}
    char_rows, bad = [], 0
    for b in base_rows:
        c = b.get('char', '')
        if not isinstance(c, str) or len(c) != 1:
            bad += 1
            continue
        char_rows.append((c, compact(b),
                          compact(details[c]) if c in details else '',
                          compact(relateds[c]) if c in relateds else ''))
    con.executemany('INSERT INTO char VALUES (?,?,?,?)', char_rows)
    print('[dict-import] char: %d 行 (异常跳过 %d) %.1fs' % (len(char_rows), bad, time.time() - t0), flush=True)

    # ---- word: word.json 全量 ----
    t0 = time.time()
    words = load(os.path.join(src, 'word/word.json'))
    word_rows, seen = [], set()
    wbad = 0
    for w in words:
        word = w.get('word')
        if not isinstance(word, str) or word == '' or word in seen:
            wbad += 1
            continue
        seen.add(word)
        word_rows.append((word, s(w.get('pinyin')), s(w.get('abbr')).lower(),
                          s(w.get('explanation')), compact(w)))
    con.executemany('INSERT INTO word VALUES (?,?,?,?,?)', word_rows)
    print('[dict-import] word: %d 行 (异常跳过 %d) %.1fs' % (len(word_rows), wbad, time.time() - t0), flush=True)

    # ---- idiom.json 仅补 word.json 缺失的成语 ----
    idiom_path = os.path.join(src, 'idiom/idiom.json')
    if os.path.isfile(idiom_path):
        t0 = time.time()
        idioms = load(idiom_path)
        extra = []
        for w in idioms:
            word = w.get('word')
            if isinstance(word, str) and word and word not in seen:
                seen.add(word)
                extra.append((word, s(w.get('pinyin')), s(w.get('abbr')).lower(),
                              s(w.get('explanation')), compact(w)))
        con.executemany('INSERT INTO word VALUES (?,?,?,?,?)', extra)
        print('[dict-import] idiom 补缺: %d 行 %.1fs' % (len(extra), time.time() - t0), flush=True)

    # ---- variant: 繁体 → 简体 ----
    t0 = time.time()
    var_map = {}
    for c, base_json, _d, _r in char_rows:
        b = json.loads(base_json)
        for t in s(b.get('traditional')):
            if len(t) == 1 and t != c:
                var_map[t] = c
    for d in detail_rows:
        c = d.get('char')
        if not isinstance(c, str) or len(c) != 1:
            continue
        for pron in d.get('pronunciations') or []:
            for ex in pron.get('explanations') or []:
                simp = ex.get('simplified')
                if isinstance(simp, str) and len(simp) == 1 and simp != c:
                    var_map[c] = simp
    con.executemany('INSERT OR REPLACE INTO variant VALUES (?,?)', sorted(var_map.items()))
    print('[dict-import] variant(繁→简): %d 行 %.1fs' % (len(var_map), time.time() - t0), flush=True)

    # ---- word_en: ECDICT stardict.csv ----
    en_path = os.path.join(src, 'word_en/stardict.csv')
    en_count = 0
    t0 = time.time()
    csv.field_size_limit(10**9)
    batch, read, bad = [], 0, 0
    en_sql = 'INSERT OR IGNORE INTO word_en VALUES (?,?,?,?,?,?,?,?,?,?,?)'
    with open(en_path, encoding='utf-8', errors='replace', newline='') as f:
        for row in csv.reader(f):
            read += 1
            if len(row) != 13:
                bad += 1
                continue
            word = row[0].strip()
            if not word:
                bad += 1
                continue
            batch.append((
                word,
                row[1].strip(),
                unescape_text(row[2]),
                unescape_text(row[3]),
                row[4].strip(),
                row[5].strip(),
                row[6].strip(),
                row[7].strip(),
                row[8].strip(),
                row[9].strip(),
                row[10].strip(),
            ))
            if len(batch) >= 50000:
                before = con.total_changes
                con.executemany(en_sql, batch)
                en_count += con.total_changes - before
                batch.clear()
                if read % 500000 == 0:
                    print('[dict-import] word_en: 已处理 %d 行 %.1fs' % (read, time.time() - t0), flush=True)
    if batch:
        before = con.total_changes
        con.executemany(en_sql, batch)
        en_count += con.total_changes - before
    print('[dict-import] word_en: %d 行 (跳过 %d) %.1fs' % (en_count, bad, time.time() - t0), flush=True)

    con.executemany('INSERT INTO meta VALUES (?,?)', [
        ('source', 'mapull/chinese-dictionary'),
        ('data_version', 'main snapshot 2025-02-04'),
        ('word_en_source', 'ECDICT stardict.csv'),
        ('word_en_count', str(en_count)),
        ('imported_at', time.strftime('%Y-%m-%d %H:%M:%S')),
    ])
    con.commit()
    con.close()
    print('[dict-import] 完成 → %s (%.1f MB)' % (db, os.path.getsize(db) / 1048576), flush=True)


if __name__ == '__main__':
    main()
