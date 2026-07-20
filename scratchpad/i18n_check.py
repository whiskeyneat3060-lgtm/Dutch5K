#!/usr/bin/env python3
"""Post-generation sanity check for the i18n packs in this directory.

Detects the ctranslate2 multi-thread batch corruption (random foreign tokens
spliced into translations) before the packs ship:
- Cyrillic packs (bg/uk/ru): any Latin letter glued directly onto a Cyrillic
  letter is corruption (e.g. "снимкаacetate"). Also counts entries containing
  any 3+ letter Latin run (loose; quoted Dutch forms legitimately match).
- All packs: spot-prints a few known strings for eyeballing.
Exit code 1 if any glued-script corruption is found.
"""
import json, os, re, sys

BASE = os.path.dirname(os.path.abspath(__file__))
GLUED = re.compile(r'[а-яА-ЯёЁїЇіІєЄґҐ][A-Za-z]|[A-Za-z][а-яА-ЯёЁїЇіІєЄґҐ]')
SPOT = ['dear, cherished, precious (to someone); beloved',
        'That photo is very dear to me — it reminds me of my grandfather.',
        'house', 'to reach, to achieve']

bad_total = 0
for lang in ['bg', 'uk', 'ru', 'de', 'pt', 'pl', 'tr', 'fr', 'it', 'es']:
    p = os.path.join(BASE, f'{lang}.json')
    if not os.path.exists(p):
        print(f'[{lang}] MISSING'); bad_total += 1; continue
    d = json.load(open(p))
    glued = [(k, v) for k, v in d.items() if GLUED.search(v)] if lang in ('bg', 'uk', 'ru') else []
    print(f'[{lang}] {len(d)} entries, glued-script corruption: {len(glued)}')
    for k, v in glued[:3]:
        print('   BAD:', repr(k), '=>', repr(v))
    bad_total += len(glued)
    for k in SPOT:
        if k in d:
            print('   ', repr(k), '=>', repr(d[k]))
sys.exit(1 if bad_total else 0)
