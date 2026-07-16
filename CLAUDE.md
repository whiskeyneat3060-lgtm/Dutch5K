# Dutch 5K — project context

Single-file Dutch vocab trainer. Mondrian design (black rules, red/blue/yellow blocks).
Owner Adi: B1 Dutch learner in Almere, toward conversational fluency.

> **Convention (Adi):** this `CLAUDE.md` is the project's only memory (sessions get cleared), so it
> should track features, gotchas, and cache bumps — but **never edit it automatically.** After each
> feature, **ask Adi** whether to update this file. Likewise **never push to `main` automatically**
> (that deploys live) — after each feature, **ask** whether to push to `main`. Develop + push on the
> feature branch freely; `main` and md edits are opt-in per change.

## Architecture — read first

**Entire app = one file: `public/index.html`** (~800 KB). No build/framework/deps. HTML + CSS +
vanilla JS + baked-in JSON blobs. Deployed as static asset by Cloudflare Workers (`wrangler.jsonc`),
auto-deploy from `main` via Workers Builds. Push to `main` = live in ~60s.

### Data blobs (in the `<script>` tag)

| Const | Size | What |
|---|---|---|
| `FREQ` | 5,000 | Dutch words by corpus frequency (Python `wordfreq`), rank order |
| `SEED` | 115 | Hand-curated: forms, synonyms, antonyms, 2 examples |
| `TRANS` | 3,887 | Offline English meanings (FreeDict NL-EN + lemmatisation + manual). `word -> {m, t?}` |
| `BOOKS` | 2,233 | Textbook vocab: 1,236 Nederlands in Actie + 997 Nederlands in Gang |

**`BOOKEX`** (just above `buildDeck`): hand-written examples for textbook words lacking them. Key
`"<src>:<word-lowercase>"` (same as `BOOKS` merge), value `[[dutch,english],…]`. `buildDeck()` applies
as overlay — sets `ex`/`rich`/`hasMeaning` on the entry — so we never edit the giant `BOOKS` line. Only
fills words with no examples yet; safe to append. **Add book-word examples here, not to `BOOKS`.**

**`GENEX`** (just below `BOOKEX`): same for *general* (non-book) 5K words. Key = bare lowercase word
(= freq-stub id), value `[[dutch,english],…]` (example only) or `{m, ex}` when a meaning is also needed
— object `m` *overrides* FreeDict's wrong homograph gloss (e.g. `kan`→"can" not "jug", `moet`→"must" not
"blot", `mee`→"mead"). Applied after `BOOKEX`. **Corpus junk deliberately gets NO fake content** (Open work).

`buildDeck()` merges all into `deck[]`. Stable `id`:
- curated/enriched: `"word|type"` (homographs like `eten` verb vs noun must not collide)
- frequency stubs: `"word"`
- book-only: `"book:<src>:<word>"`

Progress + enrichment keyed on `id`. **Never change id scheme without a migration** — `migrate()` handles
two older schemes; breaking ids silently destroys progress.

### Entry flags
- `rich` — meaning + forms + examples + synonyms (full card)
- `hasMeaning` — English meaning only
- neither — "tap to open"

## Data provenance

- **Nederlands in Actie** (11 ch, 1,236 entries incl. 201 idioms): extracted from PDF text layer
  (`Vocabulaire hoofdstuk N` pages). 823 enriched via Anthropic API; rest hand-written into `BOOKEX`.
  Now has examples for every real word (+ meanings for ~257 that lacked one), except 23 extraction artifacts.
- **Nederlands in Gang** (18 ch, 997 words): PDF is a *scan*, no text layer — do NOT OCR it. Vocab from
  publisher's official Dutch→German list (klett-sprachen.de), translated to English. All have meanings;
  all 825 now have a hand-written example (`BOOKEX`). No forms/synonyms.

Both books are Adi's copies; only vocab lists extracted, no book sentences reproduced.

## App icons & link-share branding (v48)

The app previously had **no icons/manifest** → phones showed a "W" letter tile on the home screen and
link shares showed no image. Fixed by adding real asset files to `public/` (NOT data URIs — `wrangler.jsonc`
uses `not_found_handling:"single-page-application"`, so any *referenced* file that doesn't exist returns
`index.html` with the wrong content-type = broken icon; every icon must be a real file). Social scrapers
also need a real image URL for `og:image`, not a data URI.

**Logo = tulip-book badge** (Adi-supplied art): a circular badge — black ring, red/white/blue tulip whose
petals are an open book, arc text "DUTCH / VOCAB TRAINER / 5000 WORDS", two stars. Used **only** for the
browser tab / home-screen icon / link-share card — **never inside the app UI** (the app stays Mondrian).
The source PNG is a wide banner; `scratchpad/make_icons.py` (pure Pillow; `pip install Pillow numpy`) crops
just the **circular part** (detected centre ≈ (511,284), outer ring radius ≈ 207), circle-masks it
anti-aliased, and composites it onto **white** so every tile is a clean white square with the ringed badge
centred. Files it writes to `public/`: `favicon.ico` (16/32/48), `favicon-32.png`,
`apple-touch-icon.png` (180, iOS home screen), `icon-192.png`, `icon-512.png`,
`icon-maskable-512.png` (badge shrunk to ~78% so Android's circular mask never clips ring/text),
`og-image.png` (1200×630 share card: badge left + tagline right), and `favicon.svg` (the 180 tile embedded
as a data-URI `<image>`). `public/site.webmanifest` (name/short_name/icons/`display:standalone`) is
committed directly. **To change the logo:** drop the new art path into `make_icons.py`'s `SRC`, adjust
`CX/CY/R` to the new circle, rerun, bump the SW cache, redeploy.

Wired in `<head>` (after `<title>`): `<link>` icon/apple-touch-icon/manifest + PWA meta
(`theme-color`, `apple-mobile-web-app-*`, `application-name`) + Open Graph/Twitter tags pointing at
`/og-image.png`. The **static `<meta name="theme-color">`** is now what `applyTheme()` finds & updates per
theme (before v48 the JS created it on the fly). og:image uses a **relative** URL (resolves against page URL
on modern unfurlers); swap to an absolute URL if a platform needs one.

## Storage (client-side, no backend)

`Store` adapter wraps `window.storage` (Claude artifacts) with `localStorage` fallback. Keys:
`dutch5k-progress`, `-enriched`, `-plan`, `-streak`, `-remind`, `-theme`. Export/Import JSON backup in
Progress tab. No server; losing localStorage loses progress.

## Features

Three tabs: **Learn** (flashcards, flip, Again/Learning/Know-it, Skip), **Words** (search, list, detail),
**Progress** (stats, daily goal, streak, 14-day history, POS breakdown, backup, theme picker).

**Themes (v47 — three different LAYOUTS, not just palettes):** picked from Theme box in Progress. Content
identical across all three; DOM untouched — each theme is pure CSS scoped to `html[data-theme="<id>"]`,
re-skinning structure (nav, type, spacing), not only colour.
- **Minimalistic** (default, *no* `data-theme`) — original Mondrian: black rules, red/blue/yellow, Archivo/Inter, sharp corners, top tab bar.
- **Midnight** — dark mobile app: ambient gradient bg, big rounded glowing cards, Inter, floating pill nav (`nav{position:fixed;bottom}`, `main` gets `padding-bottom:98px`). Active tab = blue→violet gradient pill.
- **Sepia** — printed book: serif Georgia, narrow centred cream page (`main{max-width:520px}`), paper-grain bg, centred title header, running-head text nav (underline active, no buttons). Cards = ruled entries; headword large italic serif; Words list reads like a dictionary.

How it works:
- Palette/structure from `:root` tokens: `--ink`/`--line`/`--paper`/`--grey`/`--card-bg`, `--red/--blue/--yellow`,
  `--muted`/`--muted2`/`--faint`, `--radius`, `--shadow`, `--font-head`/`--font-body`, `--accent`. A theme
  overrides tokens + adds scoped structural rules. All text colours tokenised (nothing black on dark ground);
  where a coloured block needs dark text (yellow `.chip.ant`/`.btn-learning` in Midnight) there's an override.
- **Add a theme:** add `html[data-theme="<id>"]{…}` block near bottom of `<style>` + an entry in JS `THEMES`
  array (`{id,name,desc,sw:[3 swatches]}`). Picker renders from that array; `setTheme(id)`→`applyTheme(id)`
  (sets/removes `data-theme`, updates `theme-color` meta), persists `dutch5k-theme`, re-renders.
- **Nav-bar-vanishing bug (fixed for good v47):** Android Chrome dropped whole tab bar after a tab tap until
  refresh — re-rendering `#main` dropped nav's paint. JS repaint nudges (v45/v46) did NOT fix it. Real fix is
  pure CSS: base `nav{}` is now `position:sticky; top:0; transform:translateZ(0)` (+`-webkit-`; `z-index:20;
  background:var(--paper)`) → own GPU compositing layer, pixels cached independently, survive `#main` re-renders.
  `render()` does no repaint hack now (paintFix removed). `nav` taken out of `overflow:hidden` rule. Midnight
  overrides: `position:fixed; top:auto; bottom:14px` (floating pill, still own layer).
- **Buttons need explicit text colour:** `<button>` doesn't inherit `color` → UA black, invisible on Midnight.
  Base `button{color:var(--ink)}` (under `body`) tokenises it; coloured/active buttons set their own & win on
  specificity. New buttons usually need no colour — they inherit theme ink.
- **Anti-flash:** tiny sync `<script>` at end of `<head>` reads `dutch5k-theme` from localStorage (JSON, e.g.
  `"midnight"`), sets `data-theme` before first paint; `init()` re-applies authoritatively. Keep paper hexes
  in that script AND in `applyTheme()`'s `theme-color` line synced with each `--paper` (Midnight `#0d0e15`,
  Sepia `#f3ead6`).

Filters in Learn + Words: **status** (new/learning/learned), **POS** (verb/noun/adj/...), **source**
(All / General 5K / Gang / Actie). Book words show A/G badges + chapter tags ("Actie H3").

POS + source filters are **identical & same order across both tabs** — render from shared helpers
`posFilterButtons()`/`srcFilterButtons()` (on `POS_FILTER` + `srcFilterOpts()`). Canonical source order:
**All, General, Gang, Actie**. Edit the shared helpers, not per-tab markup, or tabs drift. (Learn:
`setLearnPos`/`setLearnSrc`→full `render()`. Words: `setPosFilter`/`setSrcFilter`→partial `renderWordList()`
with scoped `button[data-p]` update so POS refresh doesn't clobber the source bar.)

Synonyms/antonyms render as tappable rows; if the word is in deck it links to its card, with back-stack
(`wordViewStack`).

**Pronunciation:** speaker icon (`spkBtn(idx)`, `.spk`) next to every word in Learn card, Words rows, Words
detail. Tap → `speak(idx, event)` uses Web Speech API (`SpeechSynthesisUtterance`, `lang='nl-NL'`) — offline,
no deps/key. Dutch voice via `_loadNlVoice()`; icon red (`.spk.speaking`) while speaking. Works for all words.
`event` arg is for `stopPropagation` (don't flip card / open row). Caveat: quality depends on device TTS voices;
no Dutch voice → wrong-accent fallback.

Offline-first: service worker (cache `dutch5k-vN`) caches shell. **Bump cache version every deploy** or
returning users get stale app.

## Gotchas

- **Never re-render whole `#main` on search keystrokes** — destroys input, dismisses mobile keyboard.
  `renderWordList()` updates only `#wlist`; search input never rebuilt.
- **CSS specificity:** `.actions button` overrode `.btn-know` bg → invisible white-on-white. Button colour
  rules must be `.actions button.btn-know`.
- `event.stopPropagation()` guarded as `event&&event.stopPropagation()` — synthetic clicks pass no event.
- No `localStorage` in Claude artifacts → the `Store` adapter.
- Haptics via `navigator.vibrate` (`hap()`); no-ops on iOS.

## Testing

No framework. Tests = ad-hoc jsdom scripts driving real DOM (click tabs, type search, open cards); top-level
`let` bindings are NOT on `window` under jsdom `runScripts:'dangerously'`, so assert via DOM state. Before
deploy: check JS syntax, load in jsdom, verify all 3 tabs render, search keeps focus, filters work, a known
enriched word (`bereiken`) shows Forms + Examples + Synonyms.

## Deploying

Push `public/index.html` to `main`. Workers Builds runs `npx wrangler deploy`, live ~60s. Worker name in
`wrangler.jsonc` (`drop-a757014e-97c`) must not change — it's the URL.

> **Never push to `main` automatically — ask Adi first** (pushing `main` deploys live). Develop and push
> on the feature branch as normal; only push `main` once Adi says so.
>
> **Deploy verification (only after an approved `main` push):** Cloudflare deploys **only from `main`**.
> Pushing the feature branch alone does nothing for the live site — a commit can sit there unshipped
> (happened to the theme switcher). So once Adi approves and you push `main`, confirm it landed:
> ```
> git fetch origin main -q
> git show origin/main:public/index.html | grep -c "<token unique to your change>"   # e.g. dutch5k-theme, new cache vNN
> git log --oneline origin/main -1                                                     # should be your commit
> ```
> If not there: `git push origin <feature-branch>:main` (fast-forwards when `main` is ancestor).

## Open work

1. **Book-word examples — DONE** (hand-written `BOOKEX`, no API). All 1,234 book words lacking examples now
   have one; `BOOKEX` also filled meanings for ~257 Actie words. **23 extraction artifacts intentionally
   skipped:** `taptap`, `Eigen vocabulaire`, words with stray bell char, `verb ‒ past ‒ perfect` principal-part
   lines, and malformed lemmas (headwords with `‒`, `/`, or `(...)`). To cover them, repair the headword in
   `BOOKS` first, then add to `BOOKEX`.
2. **General 5K meanings + examples — DONE** (`GENEX`, no API). Every general 5K word surviving the junk filter
   has a meaning + hand-written B1 example. 24 rank-ordered batches; `node rework.js` reports `0 remaining`,
   deck-with-examples ≈ 5,570 (cache v43). Only artifacts from item 1 remain uncovered. **Method** (reproducible
   for top-ups, ~150 words/batch): `node rework.js` regenerates rank-sorted `gen_all.json` worklist (drops done
   + junk) → read next slice → author `scratchpad/genex_batch.json` = `[{w,m?,nl,en,junk?}]` (object `m`
   overrides wrong FreeDict inflected glosses; omit if fine) → `node genex_build.js` (maps to exact keys,
   apostrophe-safe) → `node genex_insert.js` (inserts at `--GENEX-APPEND--` anchor + syntax-check) →
   `node verify.js` → bump `dutch5k-vNN` cache → commit+push both branches. Corpus junk (names/brands/places/
   abbrevs/English tokens) gets NO fake content — mark `junk:true`, and for repeat stragglers add to the
   `JUNK-EXTRA`/`JUNK-EXTRA2` `.forEach(w=>JUNK.add(w))` lines above `buildDeck` (item 5). Scratchpad scripts
   regenerable from this description.
3. Gang words (+ hand-added Actie words) have only meaning + one example — no forms/synonyms.
4. Adi wants a premium gate for the API key rather than pasting one in.
5. **Junk filter — DONE (first pass).** Curated `JUNK` set (above `buildDeck`, ~354 words) drops corpus noise:
   proper names, brands, foreign places, standalone abbrevs, English tokens duplicating a Dutch word.
   `buildDeck()` skips them in the `FREQ` loop (`if(JUNK.has(w)) return;`) so they never enter deck/counts.
   Conservative: anything with a real meaning/example or book membership kept (units `km`, loanwords `app`/`tv`,
   countries, Dutch places all stay). To extend, add to `JUNK` — but first validate the candidate has no
   meaning/example/book tag. Deck dropped 6,100 → 5,754. CEFR/spoken-level tag still unbuilt.
