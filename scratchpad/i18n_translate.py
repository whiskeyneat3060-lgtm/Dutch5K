#!/usr/bin/env python3
"""Batch-translate the extracted deck strings with the Argos CTranslate2 models directly.

- Meanings are FreeDict-style comma/semicolon glosses: translate each part separately
  (MT mangles bare comma lists) and dedupe, then rejoin with ', '.
- The 629 "(form of “X”)" gloss suffixes are stripped pre-MT and re-attached with a
  localized label so the quoted Dutch word is never touched by the model.
- Examples are full sentences: translated whole.
- intra_threads MUST be 1: ctranslate2 4.8.1 nondeterministically corrupts batch
  output on this container at higher thread counts (verified at 4, and re-verified
  at 2 in the v62 run — random foreign tokens spliced into translations). Only
  single-thread output is stable. Parallelism is safe at the *process* level
  (one language per process).

Output: {english: translated} JSON per language, keeping only entries that differ
from the source (ct() falls back to English for missing keys).
"""
import json, os, re, sys, time
import ctranslate2, sentencepiece as spm

BASE = os.path.dirname(os.path.abspath(__file__))
PKG = os.path.expanduser('~/.local/share/argos-translate/packages')
PKGDIR = {'fr': 'translate-en_fr-1_9', 'it': 'en_it', 'es': 'en_es',
          # v61 additions — dir names follow the installed Argos package (check ~/.local/share/argos-translate/packages)
          'de': 'translate-en_de-1_3', 'pt': 'translate-en_pt-1_9', 'pl': 'translate-en_pl-1_9',
          'tr': 'translate-en_tr-1_5', 'uk': 'en_uk', 'ru': 'translate-en_ru-1_9',
          'bg': 'translate-en_bg-1_9'}
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
    # Two tokenizer generations in the Argos packages: most ship a sentencepiece.model;
    # en_pl (1.9) instead ships Moses+subword-nmt BPE (bpe.model, '@@ ' joiners,
    # Moses-escaped entities like &apos; and @-@ hyphen splits in its vocabulary).
    bpe_path = os.path.join(d, 'bpe.model')
    if os.path.exists(bpe_path):
        from sacremoses import MosesTokenizer, MosesDetokenizer
        from subword_nmt.apply_bpe import BPE
        mtok = MosesTokenizer(lang='en')
        mdetok = MosesDetokenizer(lang=lang)
        bpe = BPE(open(bpe_path, encoding='utf-8'))
        def encode(u):
            return bpe.process_line(
                mtok.tokenize(u, return_str=True, escape=True, aggressive_dash_splits=True)).split()
        def decode(hyp_tokens):
            t = ' '.join(hyp_tokens).replace('@@ ', '')
            if t.endswith('@@'): t = t[:-2]
            t = t.replace(' @-@ ', '-')
            return mdetok.detokenize(t.split()).strip()
        leftover = '@@'
    else:
        sp = spm.SentencePieceProcessor(model_file=os.path.join(d, 'sentencepiece.model'))
        def encode(u):
            return sp.encode(u, out_type=str)
        def decode(hyp_tokens):
            return ''.join(hyp_tokens).replace('▁', ' ').strip()
        leftover = '▁'
    tr = ctranslate2.Translator(os.path.join(d, 'model'), device='cpu', intra_threads=1)

    units = set()
    for m in meanings:
        core = FORM_RE.sub('', m)
        units.update(split_gloss(core))
    units.update(examples)
    units = sorted(u for u in units if u)
    print(f'[{lang}] {len(units)} units', flush=True)

    t0 = time.time()
    toks = [encode(u) for u in units]
    res = tr.translate_batch(toks, beam_size=4, max_batch_size=1024,
                             batch_type='tokens', max_decoding_length=256)
    out = {}
    bad = 0
    for u, r in zip(units, res):
        t = decode(r.hypotheses[0])
        # sanity: drop leftovers/blowups so ct() falls back to English instead
        if not t or leftover in t or len(t) > max(40, 3 * len(u)):
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
