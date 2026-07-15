# Dutch 5K — project context

A single-file Dutch vocabulary trainer. Mondrian-inspired design (black rules, red/blue/yellow blocks).
Owner is Adi: B1 Dutch learner in Almere, studying toward conversational fluency.

> **Convention (Adi's standing request):** whenever you change the app, update this `CLAUDE.md`
> in the same commit — document new features, gotchas, and cache bumps here. Sessions get cleared
> to save tokens, so this file is the project's memory. If it isn't written here, the next session
> won't know it.

## Architecture — read this first

**The entire app is one file: `public/index.html`** (~800 KB). No build step, no framework, no dependencies.
HTML + CSS + vanilla JS + four large baked-in JSON data blobs. Deployed as a static asset by Cloudflare
Workers (`wrangler.jsonc`), auto-deploying from `main` via Workers Builds. Push to `main` = live in ~60s.

### The four data blobs (inside the `<script>` tag)

| Const | Size | What it is |
|---|---|---|
| `FREQ` | 5,000 | Dutch words by corpus frequency (from Python `wordfreq`), rank order |
| `SEED` | 115 | Hand-curated entries: labeled forms, synonyms, antonyms, 2 example sentences |
| `TRANS` | 3,887 | Offline English meanings (FreeDict NL-EN + lemmatisation + manual). `word -> {m, t?}` |
| `BOOKS` | 2,233 | Textbook vocab: 1,236 Nederlands in Actie + 997 Nederlands in Gang |

There is also a small **fifth blob, `BOOKEX`** (defined just above `buildDeck`): hand-written example
sentences for textbook words that shipped without them. Keyed by `"<src>:<word-lowercase>"` (the same
key the `BOOKS` merge uses), value `[[dutch, english], …]`. `buildDeck()` applies it as an overlay —
sets `ex`, `rich`, `hasMeaning` on the matching deck entry — so we never edit the giant `BOOKS` line.
**This is the place to add examples going forward** for *book* words: append to `BOOKEX`, don't touch `BOOKS`.
It only fills words that have no examples yet, so it's safe to append to.

There is a **sixth blob, `GENEX`** (just below `BOOKEX`): the same idea for *general* (non-book) 5K
frequency words. Keyed by the **bare lowercase word** (= the frequency-stub id), value `[[dutch,english],…]`
(example only) or `{m, ex}` when the word also needs a meaning — and the object `m` *overrides* FreeDict's
wrong homograph gloss (e.g. `kan`→"jug" should be "can", `moet`→"blot" should be "must", `mee`→"mead").
`buildDeck()` applies it after `BOOKEX`. **Corpus junk is deliberately NOT given fake content** (see Open work).

`buildDeck()` merges all four into `deck[]`. Every entry has a stable `id`:
- curated/enriched: `"word|type"` (homographs like `eten` verb vs noun must not collide)
- frequency stubs: `"word"`
- book-only words: `"book:<src>:<word>"`

Progress and enrichment are keyed on `id`. **Never change the id scheme without writing a migration** —
`migrate()` already handles two older schemes; breaking ids silently destroys the user's progress.

### Entry flags
- `rich: true` — has meaning + forms + examples + synonyms (full card)
- `hasMeaning: true` — has an English meaning only
- neither — shows "tap to open"

## Data provenance

- **Nederlands in Actie** (11 chapters, 1,236 entries incl. 201 idioms): extracted from the PDF's
  text layer (`Vocabulaire hoofdstuk N` glossary pages). 823 fully enriched via the Anthropic API.
  The rest (meanings and/or examples) were **hand-written into `BOOKEX`** — Actie now has examples for
  every real word (and meanings for the ~257 that lacked one), except 23 extraction artifacts.
- **Nederlands in Gang** (18 chapters, 997 words): the book PDF is a *scan* with no text layer.
  Do NOT try to OCR it — the vocab came from the publisher's official Dutch→German word list
  (klett-sprachen.de), translated to English. All have meanings, and **all 825 now have a hand-written
  example sentence** (in `BOOKEX`). Gang words still have no forms/synonyms.

Both books are Adi's own copies. Only vocabulary lists were extracted — no book sentences reproduced.

## Storage (all client-side, no backend)

`Store` adapter wraps `window.storage` (Claude artifacts) with a `localStorage` fallback.
Keys: `dutch5k-progress`, `dutch5k-enriched`, `dutch5k-plan`, `dutch5k-streak`, `dutch5k-remind`, `dutch5k-theme`.
Export/Import JSON backup lives in the Progress tab. There is no server; losing localStorage loses progress.

## Features

Three tabs: **Learn** (flashcards, flip, Again/Learning/Know-it, Skip), **Words** (search, list, detail cards),
**Progress** (stats, daily goal, streak, 14-day history, POS breakdown, backup, **theme picker**).

**Themes (v47 — three genuinely different LAYOUTS, not just palettes):** chosen from the **Theme** box at the
bottom of Progress. Content and progress are identical across all three; the DOM is untouched — each theme is
pure CSS scoped to `html[data-theme="<id>"]`, so a theme re-skins *structure* (nav placement, type, spacing,
card language), not only colour. The three:
- **Minimalistic** (default, *no* `data-theme` attribute) — the original Mondrian: black rules, red/blue/yellow
  blocks, Archivo/Inter, sharp corners, tab bar on top.
- **Midnight** — a modern dark mobile app: ambient gradient background, big rounded glowing cards, Inter, and a
  **floating pill nav fixed at the bottom** (`nav{position:fixed;bottom}`, `main` gets `padding-bottom:98px` to
  clear it). Active tab is a blue→violet gradient pill.
- **Sepia** — a printed book: serif Georgia, a **narrow centred cream page** (`main{max-width:520px}`) with a
  faint paper-grain background, a centred title-page header, and a **running-head text nav** (underline for the
  active tab, no filled buttons). Cards become ruled entries (top/bottom rules, no box); the headword is large
  italic serif; the Words list reads like a dictionary.

How it works:
- Palette/structure is driven by tokens in `:root` — `--ink`/`--line`/`--paper`/`--grey`/`--card-bg`,
  `--red/--blue/--yellow`, `--muted`/`--muted2`/`--faint`, `--radius`, `--shadow`, `--font-head`/`--font-body`,
  `--accent`. A theme overrides those tokens **and** adds scoped structural rules (nav/header/card/main). All
  text colours are tokenised so nothing stays black on a dark ground; where a coloured block needs dark text
  (e.g. yellow `.chip.ant`/`.btn-learning` in Midnight) there's an explicit override.
- **To add a theme:** add a `html[data-theme="<id>"]{…}` block near the bottom of the `<style>` (token overrides
  + any structural rules) and an entry in the `THEMES` array in JS (`{id,name,desc,sw:[3 swatch colours]}`). The
  picker renders itself from that array; `setTheme(id)` → `applyTheme(id)` (sets/removes `data-theme`, updates
  the `theme-color` meta), persists `dutch5k-theme`, re-renders.
- **Nav-bar-vanishing bug (fixed for good in v47):** on Android Chrome the whole tab bar disappeared after a tab
  tap and only a page refresh brought it back — re-rendering `#main` dropped the nav's paint. JS repaint nudges
  (display/visibility toggles in v45/v46) did **not** cure it and a stuck toggle could leave nav hidden. The
  real fix is pure CSS: the base `nav{}` rule is now `position:sticky; top:0; -webkit-transform:translateZ(0);
  transform:translateZ(0)` (+ `z-index:20; background:var(--paper)`), which promotes nav to its **own GPU
  compositing layer** so its pixels are cached independently and survive `#main` re-renders. `render()` does no
  repaint hack at all now (paintFix removed). `nav` was also taken out of the `overflow:hidden` rule. Midnight's
  nav overrides this with `position:fixed; top:auto; bottom:14px` (a floating bottom pill — still its own layer).
- **Buttons need an explicit text colour:** `<button>` does not inherit `color`, so unstyled buttons fall back to
  UA black — invisible on Midnight. A base `button{ color:var(--ink); }` rule (just under `body`) tokenises it;
  coloured/active buttons (`.btn-know`, `.filters button.active`, `.genbtn`, …) set their own colour and win on
  specificity. If you add a new button, you usually don't need a colour — it inherits the theme ink now.
- **Anti-flash:** a tiny synchronous `<script>` at the end of `<head>` reads `dutch5k-theme` from localStorage
  (JSON-encoded, e.g. `"midnight"`) and sets `data-theme` before first paint; `init()` re-applies it
  authoritatively. Keep the paper hexes in that script and in `applyTheme()`'s `theme-color` line in sync with
  each theme's `--paper` (Midnight `#0d0e15`, Sepia `#f3ead6`).

Filters in both Learn and Words: **status** (new/learning/learned), **POS** (verb/noun/adjective/...),
**source** (All / General 5K / Nederlands in Gang / Nederlands in Actie). Book words show A/G badges
and chapter tags ("Actie H3").

The POS and source filters are **identical and in the same order across both tabs** — they render from
shared helpers `posFilterButtons()` / `srcFilterButtons()` (built on `POS_FILTER` and `srcFilterOpts()`).
Canonical source order is **All, General, Gang, Actie**. Edit the shared helpers, not the per-tab markup,
or the two tabs will drift apart again. (Learn uses `setLearnPos`/`setLearnSrc` → full `render()`; Words
uses `setPosFilter`/`setSrcFilter` → partial `renderWordList()` with a scoped `button[data-p]` update so
the POS refresh doesn't clobber the source bar.)

Synonyms/antonyms render as tappable rows; if the word exists in the deck it links to its card, with
a back-stack (`wordViewStack`) so you can walk back.

**Pronunciation:** a speaker icon (`spkBtn(idx)`, `.spk` class) sits next to every word in the Learn
flashcard, Words list rows, and Words detail card. Tapping calls `speak(idx, event)`, which uses the
browser's built-in Web Speech API (`SpeechSynthesisUtterance`, `lang='nl-NL'`) — offline, no deps, no
API key. Picks a Dutch voice via `_loadNlVoice()`; icon turns red (`.spk.speaking`) while speaking.
Works for all words, not just enriched ones. The `event` arg is for `stopPropagation` so tapping the
icon doesn't flip the card or open the row. Caveat: voice quality depends on the device's installed
TTS voices; a device with no Dutch voice may fall back to a wrong-accent voice.

Offline-first: a service worker (cache `dutch5k-vN`) caches the shell. **Bump the cache version on every
deploy** or returning users get a stale app.

## Gotchas learned the hard way

- **Never re-render the whole `#main` on search keystrokes.** It destroys the input and dismisses the
  mobile keyboard. `renderWordList()` updates only `#wlist`; the search input is never rebuilt.
- **CSS specificity**: `.actions button` overrode `.btn-know`'s background, making white-on-white
  invisible buttons. Button colour rules must be `.actions button.btn-know`.
- `event.stopPropagation()` is guarded as `event&&event.stopPropagation()` — synthetic clicks pass no event.
- No `localStorage` in Claude artifacts — that's why the `Store` adapter exists.
- Haptics via `navigator.vibrate` (`hap()`); silently no-ops on iOS.

## Testing

No test framework. Tests were ad-hoc jsdom scripts driving the real DOM (click tabs, type in search,
open cards) rather than reaching into internals — top-level `let` bindings are NOT on `window` under
jsdom's `runScripts:'dangerously'`, so assert via DOM state.

Before any deploy: check JS syntax, load in jsdom, verify all three tabs render, search keeps focus,
filters work, and a known enriched word (e.g. `bereiken`) shows Forms + Examples + Synonyms.

## Deploying

Push `public/index.html` to `main`. Cloudflare Workers Builds runs `npx wrangler deploy` and the site
updates in ~60s. The worker name in `wrangler.jsonc` (`drop-a757014e-97c`) must not change — it's the URL.

> **Deploy verification (learned the hard way — do this every time):** Cloudflare deploys **only from
> `main`**. Pushing to the feature branch (`claude/new-session-dk52ob`) does **nothing** for the live site.
> A commit can sit on the feature branch for sessions and never go live — that's exactly what happened to
> the theme switcher (built + pushed to the feature branch, but `main` lagged behind, so users saw no
> theme option). **After every push, confirm the change is actually on `main`**, don't trust that the push
> landed where it deploys from:
> ```
> git fetch origin main -q
> git show origin/main:public/index.html | grep -c "<a token unique to your change>"   # e.g. dutch5k-theme, the new cache vNN
> git log --oneline origin/main -1                                                       # should be your commit
> ```
> If `origin/main` isn't at your commit, push it: `git push origin claude/new-session-dk52ob:main`
> (fast-forwards when `main` is an ancestor). Always push to **both** the feature branch **and** `main`.

## Open work

1. **Example sentences for textbook words — DONE** (hand-written into `BOOKEX`, no API used). All 1,234
   book words that shipped without examples now have one, and `BOOKEX` also filled meanings for the ~257
   Actie words that lacked one. **Only 23 extraction artifacts are intentionally skipped:** `taptap`,
   `Eigen vocabulaire`, and words with a stray `` bell char, plus the `verb ‒ past ‒ perfect` principal-part
   table lines and glossary-malformed lemmas (headwords containing `‒`, `/`, or `(...)`). Those headword
   strings are broken data — to cover them, repair the headword in `BOOKS` first, then add to `BOOKEX`.
2. **Meanings + examples for GENERAL 5K words — DONE** (hand-written into `GENEX`, no API). Every general
   (non-book) 5K frequency word that survives the junk filter now has both an English meaning and a
   hand-written B1 example sentence. Completed in 24 rank-ordered batches; **`node rework.js` now reports
   `0 remaining` and deck-with-examples ≈ 5,570** (cache v43). The only entries left without content are
   the ~23 book extraction artifacts noted in item 1 (broken headwords, intentionally skipped). The
   method below is preserved so any future top-ups are reproducible. Method per batch (~150 words):
   `node rework.js` to regenerate the
   rank-sorted `gen_all.json` worklist from the current deck (drops done + junk), read the next slice,
   author `scratchpad/genex_batch.json` = `[{w,m?,nl,en,junk?}]` (object `m` overrides FreeDict's wrong
   inflected-form glosses; omit `m` if the gloss is fine), then `node genex_build.js` (maps to exact keys,
   apostrophe-safe) → `node genex_insert.js` (inserts at the `--GENEX-APPEND--` anchor + syntax-checks) →
   `node verify.js`, bump the `dutch5k-vNN` cache, commit+push both branches. Corpus junk (names, brands,
   places, abbreviations, English tokens) is **not** given fake content — mark `junk:true` AND, for
   stragglers that keep resurfacing, add them to the `JUNK-EXTRA` / `JUNK-EXTRA2` `.forEach(w=>JUNK.add(w))`
   lines just above `buildDeck` (see item 5). All scratchpad scripts are regenerable from this description.
3. Gang words (and the hand-added Actie words) have only meaning + one example — no forms/synonyms.
4. Adi mentioned wanting a premium gate for the API key rather than pasting one in.
5. Frequency-list junk filter — **DONE (first pass)**. A curated `JUNK` set (defined just above
   `buildDeck`, ~354 words) drops corpus noise from the deck: proper names, brands, foreign places,
   standalone abbreviations, and English tokens that duplicate a Dutch word. `buildDeck()` skips them in
   the `FREQ` loop (`if(JUNK.has(w)) return;`), so they never enter `deck`/counts. Conservative by design:
   anything with a real meaning/example or textbook membership was kept (units like `km`, loanwords like
   `app`/`tv`, countries, Dutch place names all stay). To extend, add words to `JUNK` — but first run the
   validator idea in `scratchpad` (flag any candidate that has a meaning/example/book tag before removing).
   Deck dropped 6,100 → 5,754. A CEFR/spoken-Dutch level tag is still unbuilt.
