#!/usr/bin/env python3
"""Batch-translate the extracted deck strings with the Argos CTranslate2 models directly.

- Meanings are FreeDict-style comma/semicolon glosses: translate each part separately
  (MT mangles bare comma lists) and dedupe, then rejoin with ', '.
- The 629 "(form of “X”)" gloss suffixes are stripped pre-MT and re-attached with a
  localized label so the quoted Dutch word is never touched by the model.
- Examples are full sentences: translated whole.
- intra_threads<=2: at 4 threads ctranslate2 4.8.1 nondeterministically corrupts
  batch output on this container (verified). Single-thread output is stable.

Output: {english: translated} JSON per language, keeping only entries that differ
from the source (ct() falls back to English for missing keys).
"""
import json, os, re, sys, time
import ctranslate2, sentencepiece as spm

BASE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.expanduser('~/.local/share/argos-translate/packages')
PKGDIR = {'fr': 'translate-en_fr-1_9', 'it': 'en_it', 'es': 'en_es',
          # v61 additions — dir names follow the installed Argos package (check ~/.local/share/argos-translate/packages)
          'de': 'en_de', 'pt': 'en_pt', 'pl': 'en_pl', 'tr': 'en_tr',
          'uk': 'en_uk', 'ru': 'en_ru', 'bg': 'en_bg'}
FORM_LABEL = {'fr': 'forme de', 'it': 'forma di', 'es': 'forma de',
              'de': 'Form von', 'pt': 'forma de', 'pl': 'forma od', 'tr': 'biçimi:',
              'uk': 'форма від', 'ru': 'форма от', 'bg': 'форма на'}
FORM_RE = re.compile(r'\s*\(form of (“[^”]+”)\)\s*$')

data = json.load(open(os.path.join(BASE, 'strings.json')))
meanings, examples = data['meanings'], data['examples']

def split_gloss(m):
    parts, depth, cur = [], 0, ''
    for ch in m:
        if ch == '(': depth += 1
        elif ch == ')': depth = max(0, depth - 1)
        if ch in ',;' and depth == 0:
            parts.append(cur.strip()); cur = ''
        else:
            cur += ch
    parts.append(cur.strip())
    return [p for p in parts if p]

def run_lang(lang):
    d = os.path.join(PKG, PKGDIR[lang])
    sp = spm.SentencePieceProcessor(model_file=os.path.join(d, 'sentencepiece.model'))
    tr = ctranslate2.Translator(os.path.join(d, 'model'), device='cpu', intra_threads=1)

    units = set()
    for m in meanings:
        core = FORM_RE.sub('', m)
        units.update(split_gloss(core))
    units.update(examples)
    units = sorted(u for u in units if u)
    print(f'[{lang}] {len(units)} units', flush=True)

    t0 = time.time()
    toks = [sp.encode(u, out_type=str) for u in units]
    res = tr.translate_batch(toks, beam_size=4, max_batch_size=1024,
                             batch_type='tokens', max_decoding_length=256)
    out = {}
    bad = 0
    for u, r in zip(units, res):
        t = ''.join(r.hypotheses[0]).replace('▁', ' ').strip()
        # sanity: drop leftovers/blowups so ct() falls back to English instead
        if not t or '▁' in t or len(t) > max(40, 3 * len(u)):
            bad += 1; continue
        out[u] = t
    print(f'[{lang}] translated in {time.time()-t0:.0f}s, {bad} rejected', flush=True)

    pack = {}
    for m in meanings:
        fm = FORM_RE.search(m)
        core = FORM_RE.sub('', m)
        parts = [out.get(p, p) for p in split_gloss(core)]
        seen, ded = set(), []
        for p in parts:
            k = p.lower()
            if k not in seen: seen.add(k); ded.append(p)
        t = ', '.join(ded)
        if fm: t = (t + ' ' if t else '') + f'({FORM_LABEL[lang]} {fm.group(1)})'
        if t and t != m: pack[m] = t
    for e in examples:
        t = out.get(e, '')
        if t and t != e: pack[e] = t
    path = os.path.join(BASE, f'{lang}.json')
    json.dump(pack, open(path, 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(f'[{lang}] pack {len(pack)}/{len(meanings)+len(examples)} entries -> {path} ({os.path.getsize(path)//1024} KB)', flush=True)

for lang in (sys.argv[1:] or ['fr', 'it', 'es', 'de', 'pt', 'pl', 'tr', 'uk', 'ru', 'bg']):
    run_lang(lang)
print('done')
