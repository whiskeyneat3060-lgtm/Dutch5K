# Dutch To Go (formerly Dutch 5K) — project context

Single-file Dutch vocab trainer. Mondrian design (black rules, red/blue/yellow blocks).
Owner Adi: B1 Dutch learner in Almere, toward conversational fluency.

> **Name (v59):** the app is called **"Dutch To Go"** (Adi: "same as AH to go, for familiarity").
> The rename is *user-visible only* — title, header wordmark, PWA/OG/Twitter metas,
> manifest name/short_name, reminder-notification title, backup filename. Everything internal keeps
> the old `dutch5k` name **on purpose**: storage keys (`dutch5k-*` — renaming wipes progress), SW
> cache prefix (`dutch5k-vNN`), worker name (= URL), repo name, and this file's scripts/anchors.
>
> **v60 (Adi request):** title/og:title/twitter:title/og:image:alt + manifest `name` now carry the
> CEFR range — "Dutch To Go — Vocab Trainer **(A0 → B2)**" (`short_name` stays plain "Dutch To Go";
> the painted tagline in `og-image.png` was NOT regenerated). Header wordmark restyled AH-to-go
> style: `DUTCH <span>to go</span>` — caps + lowercase italic `to go` via `.logo span` (red;
> Sepia's accent override still applies). The old `DUTCH·TO·GO` dot form is gone.

> **Convention (Adi):** this `CLAUDE.md` is the project's only memory (sessions get cleared), so it
> should track features, gotchas, and cache bumps — but **never edit it automatically.** After each
> feature, **ask Adi** whether to update this file. Likewise **never push to `main` automatically**
> (that deploys live) — after each feature, **ask** whether to push to `main`. Develop + push on the
> feature branch freely; `main` and md edits are opt-in per change.
>
> **After any app change, always send Adi an offline copy of the built `public/index.html`** (as a
> file attachment, e.g. `dutch5k-vNN-<feature>.html`) so it can be tested in a browser before any
> `main` push. Caveats to mention: i18n packs (`/i18n/*.json`) can't load from a local file (FR/IT/ES
> meanings stay English), and progress is stored under the file's own origin, separate from the live site.

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
| `NIVEAU` | 501 | Nederlands op Niveau vocab (499 words, 2 cross-chapter tag dups) — separate blob, pushed into `BOOKS` at load |
| `PERFECTIE` | 371 | Nederlands naar Perfectie vocab (all 8 chapters since v88) — separate blob, pushed into `BOOKS` at load |

**`NIVEAU`** (right after the `BOOKS` line, v58): third book as its own readable blob so the giant
`BOOKS` line never needs editing — `NIVEAU.forEach(b=>BOOKS.push(b))` merges it before `buildDeck()`
runs, so all downstream code (merge, filters, badges) needed zero changes. Entries carry full
enrichment inline (`m`/`ex`/`syn`/`ant`/`f`) unlike Actie/Gang which overlay via `BOOKEX`; words in two
chapters appear once rich + once as a minimal `{w,src,ch,t}` tag entry. **Top-ups: append before the
`--NIVEAU-APPEND--` anchor** (scratchpad build script `niveau_build.js` regenerable from session).

> **`PERFECTIE` — fourth book, v86 (Adi: "add the words from nederlands-naar-perfectie.pdf, similar to
> ingang/actie etc.; change the app name from a0 to c1"):** *Nederlands naar Perfectie* (Coutinho, Palmer &
> van 't Wout, **B2 → C1**) is the fourth book in the same NT2 series as Gang/Actie/Niveau. Added as its own
> readable blob **right after the `NIVEAU.forEach(...)` merge** (`const PERFECTIE = [...]; PERFECTIE.forEach(b=>
> BOOKS.push(b))`), same self-contained pattern as `NIVEAU` — every entry carries full inline enrichment
> (`m`/`ex`/`syn`/`ant`/`f`), `src:"perfectie"`, so all downstream code needed zero changes. **Top-ups: append
> before the `--PERFECTIE-APPEND--` anchor.**
> - **ALL 8 chapters, 371 entries (since v88).** The v86 blob held only a 47-word "Chapter 1" placeholder
>   sourced from Coutinho's public preview PDF (`nt2.nl/media/65/inkijk_nederlands_naar_perfectie_hd.pdf`).
>   That preview turned out to be a **different edition** — only `fors` + `maar liefst` matched this book's
>   real Ch1 — so v88 **replaced** the placeholder wholesale (see the v88 note below). The 8 real chapters
>   are: **1 Taal en cultuur, 2 Onderwijs, 3 Economie en bedrijfsleven, 4 Gezondheid en voeding, 5 Filosofie
>   en ethiek, 6 Psychologie, 7 Rechten, 8 Mens en techniek.**
> - **New 5th source `perfectie` wired everywhere** (mirrors Niveau): `SRC_ORDER`/`SRC_SHORT`/`SRC_COLORVAR`
>   (new **`--green`** palette token added to all three theme blocks + `.sb-perfectie` badge), `FREE_LIMITS`
>   (`perfectie:0` — locks in Free like Actie/Niveau), `primarySource`, `srcFilterOpts` ("Nederlands naar
>   Perfectie"), the Words-row badge map (`perfectie:'P'`), `bookTag` label ("Perfectie H1"), and the About box
>   (📚 **Nederlands naar Perfectie** (B2 → C1) line). The About total-count string was re-keyed **four → five
>   sources** and retranslated in all 10 non-English dicts (**note:** Ukrainian "п'яти" contains an apostrophe —
>   its single-quoted `UI['uk']` value must escape it as `п\'яти`, or the whole script breaks).
> - **App renamed A0 → B2 ⟶ A0 → C1** (v60's range label bumped): `<title>`, `og:title`, `twitter:title`,
>   `og:image:alt`, and `site.webmanifest` `name`. `short_name` stays plain "Dutch To Go". The painted
>   `og-image.png` tagline was **not** regenerated. SW cache **v85 → v86**.
> - **FREQ collisions:** several Perfectie words are also frequency words (e.g. `nauw`, `scherp`, `duurzaam`,
>   `gericht`, `citaat`, `fraude`, `nuance`, `tak`, `kern`) → they become the freq stub tagged `perfectie`
>   (id = bare word). The book merge upgrades them (`b.rich && !target.rich`); a later `GENEX` overlay may still
>   override the *meaning* of a few (curated glosses), examples stay mine. Fine — no contradiction.
>
> **v88 (Adi: "this is the entire book to enrich the vocab for naar perfectie, do it" — uploaded the full
> scanned book as 7 PDFs):** replaced the v86 47-word Chapter-1 placeholder with the **complete 8-chapter
> vocabulary, 371 `PERFECTIE` entries.** The uploaded PDFs are **scans with no text layer**, so — like Niveau —
> each chapter's two `Vocabulaire tekst` list pages were **rendered to page images (`pymupdf`, ~108 dpi) and
> read visually**; only Dutch headwords / de-het articles / verb principal parts were taken, **all meanings +
> examples hand-written** (no book sentences reproduced). PDF page offsets **drift ~1 per split file** (full-page
> images), so calibrate each file empirically by the printed page number, not a fixed formula. **The old 47
> placeholder entries were dropped** — they came from a *different edition's* preview (only `fors` + `maar liefst`
> matched this book's real Ch1), so keeping them tagged this book's Ch1 would misrepresent it; both survivors are
> re-authored in the real Ch1. **Cross-chapter duplicates** (`afzonderlijk` H2+H8, `verschuiven` H2+H8,
> `beheersen` H2+H4) follow the Niveau pattern: rich entry in the first chapter + a minimal `{w,src,ch,t}` tag
> entry in the later one, which the book-merge (`deck.find` fallback) folds into the same deck entry so the card
> shows **both** tags (`bookTag` joins them with ` · `). **Zero downstream code changes** — `bookTag` already
> emits "Perfectie HN" for any N and the About box counts `perfectie` words dynamically. A couple of suffix
> headwords (`-bestendig`, `-besparing`) carry `t:"other"` (not in the POS filter; shows raw). SW cache
> **v87 → v88**. Rebuild the blob from the scratchpad flow: render vocab pages → read → author compact JSON
> objects → splice between `const PERFECTIE = [` and `];` (append top-ups before the `--PERFECTIE-APPEND--`
> anchor). i18n packs still show English for the new meanings until regenerated (`ct()` falls back safely).

**`BOOKEX`** (just above `buildDeck`): hand-written examples for textbook words lacking them. Key
`"<src>:<word-lowercase>"` (same as `BOOKS` merge), value `[[dutch,english],…]`. `buildDeck()` applies
as overlay — sets `ex`/`rich`/`hasMeaning` on the entry — so we never edit the giant `BOOKS` line. Only
fills words with no examples yet; safe to append. **Add book-word examples here, not to `BOOKS`.**

**`GENEX`** (just below `BOOKEX`): same for *general* (non-book) 5K words. Key = bare lowercase word
(= freq-stub id), value `[[dutch,english],…]` (example only) or `{m, ex}` when a meaning is also needed
— object `m` *overrides* FreeDict's wrong homograph gloss (e.g. `kan`→"can" not "jug", `moet`→"must" not
"blot", `mee`→"mead"). Applied after `BOOKEX`. **Corpus junk deliberately gets NO fake content** (Open work).

> **v71–v72 meaning sweep (Adi spotted `tel`→"esteem; regard; instant" while its own example said "count"):**
> a heuristic audit found GENEX **example-only** entries (array form, no `m` override) sitting on top of a
> **wrong FreeDict TRANS gloss** — FreeDict had picked the wrong homograph or dropped the real sense, and the
> example-only form doesn't override the meaning, so the card contradicted its own example. Signature used:
> gloss shares no word-stem with the entry's example English (648 candidates → reviewed by hand). **155 words
> fixed** by converting those entries to `{m, ex}` with a corrected concise gloss (each verified against its own
> example): plain-wrong homographs (`tel`→count, `weken`→weeks, `mars`→march, `wenen`→weep, `pers`→press,
> `stem`→voice, `bocht`→bend, `winnen`→win, `sterven`→die, `zonen`→sons, `helden`→heroes), an offensive gloss
> (`zwarte`→black), and glosses missing the real sense (`vuur`→fire, `baan`→job, `rol`→role, `file`→traffic jam,
> `speler`→player). `gebruiken` (absent from GENEX) got a new `{m, ex}` entry. **Object `{m}` with no `ex` is
> valid** (buildDeck line ~6708 guards it), so a meaning-only override needs no example. **i18n packs still show
> the old English** for these until regenerated (`ct()` falls back to English — safe, just stale in FR/IT/ES/etc.).
> This was a *mechanical* pass over the no-overlap set; subtler mistranslations that share a word with their
> example remain. Reproducible: extract GENEX+TRANS, flag array-form entries whose gloss stems don't intersect
> the example-English stems, review, rewrite in place at each entry's line.

> **v77 meaning sweep — TRANS glosses overriding correct book meanings (Adi spotted `waar`→"authentic; genuine;
> deserving" while its example "Waar woon je?" means "where"):** a *book* word that's also a frequency word takes
> its meaning from FreeDict `TRANS` in `buildDeck` — `TRANS` sets `m`+`hasMeaning` first, and the book-merge guard
> (`else if(!target.rich && !target.hasMeaning …)`) then **won't apply the curated book meaning**. So when FreeDict
> picked the wrong homograph, the card showed FreeDict's gloss and contradicted its own (book-sourced) example.
> Audited **every book word whose displayed `TRANS` gloss shares no word-stem with its book meaning** (201
> candidates, hand-reviewed) and fixed **109** genuinely wrong/misleading ones via `GENEX {m}` overrides — **9
> existing example-only entries converted to `{m, ex}` in place, 100 new `{m}` entries** appended before the
> `--GENEX-APPEND--` anchor (all tagged `v77 meaning fixes`). Sample: `waar`→where, `weer`→again/weather,
> `leven`→to live, `soms`→sometimes, `slim`→clever, `spiegel`→mirror, `verdriet`→grief, `eventueel`→possibly
> (false friend, NOT "eventually"), `tas`→bag, `bericht`→message. **False positives deliberately left alone**:
> synonyms/spellings (`foto`→"photograph"≈"photo", `niemand`→"no one"≈"nobody"), and words where the book meaning
> is a chapter-specific *inflected* form so FreeDict's infinitive is actually better (`spelen`→"play" kept over
> book "played"). `GENEX` overrides book words because `byId[bareword]` resolves the freq-stub entry (same as
> `kan`/`moet`/`mee`). **i18n packs still show old English** for these 109 until a delta-regen (`ct()` falls back
> safely). Reproducible: `scratchpad/audit.js` (extract FREQ/SEED/TRANS/BOOKS/GENEX, simulate the meaning merge,
> flag no-stem-overlap book words) → hand-curate `scratchpad/fixes.json` (`word→gloss`, each based on the book
> meaning + Dutch) → in-place-convert array entries + append the rest. SW cache bumped v76→v77.

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

- **Nederlands op Niveau** (6 ch, 499 words, v58): PDF is a *scan* too (no text layer, no OCR run) —
  the six chapter-end `Vocabulairelijst` spreads (book pp. 52-53, 93-94, 134-135, 187-188, 226-227,
  262-263) were rendered to images (`pypdfium2`) and read visually. Words + de/het articles only; **all
  meanings, examples, syn/ant and irregular-verb forms hand-written** (498 of 499 fully rich; the one
  non-rich card is a cross-referenced tag). Includes each chapter's verb+preposition collocations,
  conjunctions and irregular-verb lists as their own cards.

- **Nederlands naar Perfectie** (8 ch, B2 → C1, all chapters since v88; 371 entries): the scanned book (7
  uploaded PDFs, no text layer) was read by **rendering each chapter's `Vocabulaire tekst 1`+`2` list pages
  to page images and reading them visually** (same method as Niveau). Only Dutch headwords + de/het articles
  + verb principal parts taken; **all meanings + example sentences hand-written** (no book sentences
  reproduced). The old v86 47-word "Chapter 1" placeholder came from a different edition's preview and was
  replaced (see the `PERFECTIE` blob note above).

All books are Adi's copies; only vocab word lists extracted, no book sentences reproduced.

## App icons & link-share branding (v48, art replaced v59)

The app previously had **no icons/manifest** → phones showed a "W" letter tile on the home screen and
link shares showed no image. Fixed by adding real asset files to `public/` (NOT data URIs — `wrangler.jsonc`
uses `not_found_handling:"single-page-application"`, so any *referenced* file that doesn't exist returns
`index.html` with the wrong content-type = broken icon; every icon must be a real file). Social scrapers
also need a real image URL for `og:image`, not a data URI.

**Logo = "Dutch To Go" bike badge** (Adi-supplied art, v59; replaced the v48 tulip-book badge): a circular
badge — Dutch-flag ring, arc text "DUTCH TO GO" top / "Vocab Trainer" bottom, orange bike with basket,
speech bubbles (HALLO!/LEER!/DOORGAAN), windmills + canal houses. Used **only** for the browser tab /
home-screen icon / link-share card — **never inside the app UI** (the app stays Mondrian).
The source PNG is a wide banner (1408×768); `scratchpad/make_icons.py` (pure Pillow; `pip install Pillow
numpy`) crops just the **circular part** (v59 art: centre ≈ (704,384), radius ≈ 296 — detect via bbox of
non-near-white pixels), circle-masks it
anti-aliased, and composites it onto **white** so every tile is a clean white square with the ringed badge
centred. Files it writes to `public/`: `favicon.ico` (16/32/48), `favicon-32.png`,
`apple-touch-icon.png` (180, iOS home screen), `icon-192.png`, `icon-512.png`,
`icon-maskable-512.png` (badge shrunk to ~78% so Android's circular mask never clips ring/text),
`og-image.png` (1200×630 share card: badge left + "Dutch To Go / Vocab Trainer" tagline right, drawn with
DejaVu fonts, headline auto-shrinks to fit), and `favicon.svg` (the 180 tile embedded
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
`dutch5k-progress`, `-enriched`, `-srs` (v82 spaced-repetition schedule), `-plan`, `-streak`, `-remind`,
`-remindtime` (v82), `-theme`, `-shuffle`, `-newonly` (v83 new-words-only toggle), `-mode` (v82 study mode), `-pro`,
`-wordgoal` (v84 custom learning-goal target), `-goalmode`/`-goalsources` (v90 learning-goal type: count vs
source-completion). No server;
losing localStorage loses progress. (The Export/Import JSON backup box was **removed from the drawer in
v68** — see the Settings drawer note; `exportData()`/`importData()` still exist in the JS but are no
longer wired to any UI.)

## Features

Three tabs: **Learn** (six study modes — see v82; flip/Again/Learning/Know-it/Skip on the recognition
ones), **Words** (search, list, detail), **Progress** (stats, review-due, daily goal, streak, 14-day
history, hardest words, POS breakdown, source breakdown) — plus a **settings drawer** (hamburger in the
header) holding Theme, App language, Contact and the About box.

**Spaced repetition + study modes (v82, Adi request "add all these features"):** the app went from a
"have I seen this word" tracker to a real retention engine. Everything hangs off a new **SM-2-lite
scheduler**: `srs[id] = {due:'YYYY-MM-DD', iv:intervalDays, ef:easeFactor, reps, lapses, last}`, persisted
as `dutch5k-srs`. **`progress[id]` stays the source of truth for learned/learning *status*** (so every
count, filter, donut, streak and Pro gate is byte-for-byte unchanged) — `srs` only adds *when* a word is
due again. Section `/* ============ SPACED REPETITION ============ */` right above the QUEUE section holds
`addDays`, `scheduleSrs(id,grade)` (grade 0=Again lapse → reset iv + due today + ef−0.2; 1=Learning/hard,
2=Know-it/good, 3=easy → grow iv by ef), `isDue(id)` (**legacy words graded before v82 have no srs record
→ treated as due** so they enter review the first time; new/never-started words are never due),
`dueCount()`, `leeches()` (ids with ≥2 lapses, hardest first) and `leechSet()`.
- **`buildQueue()` rewritten:** partitions the filtered+mode-eligible pool into `due`/`notDue`/`fresh`;
  queue = **due reviews (soonest due date first) → new words**; not-yet-due words are *held back* (the
  whole point of SRS) but fall back in if nothing is due and nothing is fresh so the deck is never
  needlessly empty. `mark()` and `setWordStatus()` both call `scheduleSrs` and persist `dutch5k-srs`.
- **Six study modes**, `learnMode` persisted as `dutch5k-mode`, picked from a **mode bar** (`.modebar`,
  `LEARN_MODES` array) at the top of Learn; `setMode()` rebuilds the queue. `modeEligible(e)` gates the
  pool per mode. Two grading philosophies:
  - **Recognition modes** (`cards` NL→meaning, `reverse` meaning→NL, `listen` audio→meaning): flip +
    **self-grade** (Again/Learning/Know-it). Rendered by `recogCardHtml()`; `listen` shows a big play
    button (`.bigplay`, taps `speak()`), reveal shows word + `meaningBlock()`.
    > **Flip animation (v89, Adi: "give some animation to the flashcard while changing… like a page flip,
    > quick"):** the flip was an instant `render()` swap; now it's a **two-phase ~350ms page-flip**. `flip()`
    > (only wired to recognition cards) grabs the live `.card`, adds **`.card-flip-out`** (CSS
    > `transition:transform .15s`, `rotateY(90deg)` so the face turns edge-on and hides the content change),
    > then after **150ms** `setTimeout` does `flipped=!flipped; flipAnimateIn=true; render()`. `recogCardHtml()`
    > consumes the module-level **`flipAnimateIn`** flag (set → clears it) to add **`.card-flip-in`** to the
    > fresh card, whose `@keyframes cardFlipIn` rotates the new face in from `rotateY(-90deg)`→`0` over 200ms.
    > Both use `perspective(1400px)` for the 3D feel. A **`flipping`** guard (module `let`) blocks double-taps
    > mid-animation. **Respects reduced-motion twice**: a `matchMedia('(prefers-reduced-motion: reduce)')`
    > check in `flip()` falls back to the old instant swap, and a CSS `@media (prefers-reduced-motion: reduce)`
    > rule neutralises both classes. **Objective modes untouched** (`.card.no-flip` never calls `flip()`). CSS
    > sits right after the `.card.no-flip` rule; state vars (`flipAnimateIn`, `flipping`) next to `flipped`.
    > SW cache bumped **v88 → v89**.
  - **Objective modes** (`type` typed recall, `cloze` fill-the-blank, `dehet` gender drill):
    **auto-graded** from correctness, stored in `objResult` state, then Continue / "Review again" + "I
    knew it" / Next advance via `mark()`. `typeCardHtml()` (type+cloze) + `deHetCardHtml()`.
    `checkAnswer()` compares `normalizeAns()` (case/accent-insensitive, ignores leading de/het/een +
    trailing punctuation); `clozePick(e)` finds an example that literally contains the headword and blanks
    it (why cloze pool is smaller — conjugated verbs often don't contain the infinitive);
    `answerDeHet(choice)` checks `e.a`. de/het correct grades as **`learning`** not `learned` (you only
    proved the gender), wrong = `again`.
  - `renderLearn(main,c)` is the dispatcher (was the inline `tab==='learn'` block in `render()`); it
    builds the bars via `learnBars()`, handles empty/locked, picks the per-mode renderer, and focuses the
    `#typeInput` (Enter = Check) for typing modes. Locked (Free) cards keep the same blurred + `proOverlay`
    treatment in every mode.
- **Progress additions:** a **Review box** (`.review-box`) shows `dueCount()` + a **Start review** button
  (`startReview()` → Learn, due auto-front); a **Hardest words box** lists `leeches()` (≤8, word + meaning
  + lapse count) with **Drill hardest words** (`drillLeeches()` sets `leechOnly=true` → `buildQueue()`
  restricts the pool to leeches, never introduces fresh words; a `.drill-banner` with ✕ / `exitDrill()`
  shows in Learn while active). Both boxes are **ungated** (core learning, unlike the Pro-gated analytics).
- **Example-sentence audio:** `examplesHtml()` now appends a `.spk-ex` speaker to each Dutch sentence.
  `speak()` was generalised — `_speakDutch(text,btn)` speaks any Dutch string; `speakText(text,ev)` is the
  sentence/arbitrary-text entry point (`speak(idx,ev)` still does the headword).
- **Reminders upgraded:** `remindTime` (persisted `dutch5k-remindtime`, default `19:00`) with a
  `<input type=time>` in the plan box (`setRemindTime`). `scheduleReminder()` now sets a real `setTimeout`
  to the next occurrence of that time and fires `_fireReminder()` (via `navigator.serviceWorker.ready`
  `reg.showNotification`, falling back to the page `Notification`) if you haven't studied that day; also
  re-checks on `visibilitychange`. **Honest ceiling for a static PWA** — no push server, so it only fires
  while the tab is open; the UI says so.
- **i18n:** unlike the English-only Pro/Contact features, **all 41 new UI strings are translated into all
  10 non-English languages.** They live in one `UI_V82 = JSON.parse(\`{…}\`)` block right after the `UI`
  object (values use curly quotes/guillemets, **never ASCII `"`**, so no escaping is needed inside the JSON
  template literal), merged via `Object.assign` into each `UI[lang]`. `de / het` is a Dutch label, not
  translated. **Content packs are unaffected** (word meanings/examples are the same strings). SW cache
  bumped **v81 → v82**.

> **"New words only" toggle (v83, Adi: "what if I want to learn new words and not review — there's no
> option"):** the v82 queue always leads with due reviews, so there was no way to study *only* fresh words.
> Added `newOnly` (module-level `let`, persisted `dutch5k-newonly`, default **false**) + a **`🔴 New words
> only` toggle** in the Learn shuffle-bar next to Shuffle (reuses `.shuffle-btn`, `aria-pressed`, active =
> blue). When on, `buildQueue()` sets `queue = [...fresh]` — **every due review is held back and there is no
> `notDue` fallback** (an empty deck = "no new words left", the honest intended state; a dedicated empty-state
> message says so and points back at the toggle). `toggleNewOnly()` mirrors `toggleShuffle()` (persist +
> rebuild + render + toast) and **exits any hardest-words drill** (`if(newOnly) leechOnly=false`) since the
> two are mutually exclusive; conversely `startReview()` and `drillLeeches()` now set `newOnly=false` (+
> persist) because those entry points are explicitly about reviewing. Only the *fresh* partition is affected
> — mode/POS/source filters and free-first ordering still apply inside it, and a word marked during a
> new-only session leaves the fresh pool on the next `buildQueue()` exactly like normal. **5 new UI strings
> translated in all 10 non-English languages** via a `UI_V83 = JSON.parse(\`{…}\`)` block right after
> `UI_V82` (same curly-quote/guillemet convention, `Object.assign` merge). SW cache bumped **v82 → v83**.

> **Learning goal — real word count + settable target (v84, Adi: "the goal 5000 isn't the actual count;
> let me set how many words I want to learn"):** the progress goal was a hardcoded `const GOAL = 5000`,
> but the deck actually holds **~5,959** words, so the header (`x / 5000`), the "Of 5,000 goal" stat %, and
> the daily-plan ETA were all measured against the wrong denominator. Replaced `GOAL` with **`goalTotal()`**
> (just above `POS_LABELS`): returns `wordGoal` when the user set a custom target (capped at `deck.length`),
> else the real `deck.length`; `goalStr()` is its `toLocaleString(langLocale())` form. All four call sites
> now use it (header count, `pct` — **capped at 100%**, `remainingWords`, and the endDate `goalN` fallback).
> - **New `wordGoal`** (module-level `let`, persisted `dutch5k-wordgoal`, default **null** = whole deck),
>   loaded in `init()` right after `plan`. `setWordGoal(n)` (parses/floors, caps at `deck.length`, persists,
>   re-renders, toasts), `clearWordGoal()` (resets to null = all words), `saveWordGoalFromInput()` (reads
>   `#goalInput`) sit just below `editPlan()`.
> - **"Learning goal" box** (`.goal-box`, `renderProgress()`): preset `.planchip`s [100,250,500,1000,2000,3000]
>   (filtered `< deck.length`) + an **All** chip (`clearWordGoal`), an exact-number `<input type=number
>   id="goalInput">` (Enter submits), a **Set goal** button, and a "Learn all {n} words" reset shown only
>   when a custom goal is set. Active chip highlighted via new `.planchip.active{background:var(--blue)}`.
>   **Rendered LAST on the Progress tab — after the "By source" donut** (Adi asked it be moved to the bottom
>   after the charts). Ungated (core config, like the plan box).
> - **i18n:** the four goal strings that embedded a literal "5,000" (`Of {goal} goal`, the two ETA lines,
>   `Or reach {goal} by a date`) were **re-keyed to a `{goal}` placeholder** and the number swapped for
>   `{goal}` in **all 10 non-English values** (locale-formatted via `goalStr()` — fr/ru space, de/tr dot, pl
>   none, en comma). The **new box's own strings are English-only** via `T()` (fall back like Pro/Contact —
>   not yet in the 10 packs). **Marketing copy left alone on purpose:** the `<meta>` descriptions / FREQ
>   comment still say "5,000 most common words" — that's the real FREQ corpus size, not the goal. SW cache
>   bumped **v83 → v84**.

> **Learning goal — two goal types + i18n + chip polish (v90–v94, Adi: "give option to learn either a
> number of words, or a word source — general/actie/ingang, can select multiple"):** the v84 box could
> only target a *number* of words. It now offers **two mutually-exclusive goal types** via a mode toggle at
> the top of the box: **By word count** (the v84 behaviour) or **By source** (finish one or more chosen
> sources). State: **`goalMode`** (`'count'`|`'source'`, persisted `dutch5k-goalmode`) + **`goalSources`**
> (array of source ids, persisted `dutch5k-goalsources`), loaded in `init()` right after `wordGoal`.
> - **Coherent counts in both modes.** New helpers just above `POS_LABELS`: `goalSourceList()` (selected
>   sources present in the deck), `goalSourceCounts()` (one `.some(inSource)` pass → distinct `{total,learned}`
>   so a word shared between two chosen sources counts **once**), `goalTotal()` (source mode → source total,
>   else `wordGoal||deck.length`), **`goalLearned(c)`** (source mode → in-source learned, else `c.learned`),
>   and `goalSrcLabel(s)` = `SRC_SHORT[s]` (short chip label). The header count, `pct`, `remainingWords`, the
>   daily-plan `goalN`, and the box's own learned/total readout all switched from `c.learned` → `goalLearned(c)`
>   so source mode is byte-coherent (numerator **and** denominator scoped to the chosen sources). No source
>   selected → `goalTotal()` gracefully falls back to `deck.length`. Actions `setGoalMode(m)` /
>   `toggleGoalSource(s)` sit below `saveWordGoalFromInput()`.
> - **Chip look (Adi iterated on this).** Word-count presets are now **`[500,1000,3000,5000]` + All**, rendered
>   **compact + uppercase** via `compactNum()` (1000→`1K`, 2500→`2.5K`) so they fit **one row** — the chiprow
>   gets `.onerow` (`flex-wrap:nowrap` + `text-transform:uppercase`, so `All`→`ALL`). The source-goal chips and
>   the mode toggle use **`.srcchip`** (content-sized `flex:0 1 auto`, padding, wraps) because long text labels
>   overflow the default `flex:1` number-chip. Base `.planchip` gained horizontal padding (`12px 10px`).
> - **i18n (Adi: "not fixed english — translatable like the other charts").** The whole goal box (v84's
>   English-only strings **and** the new v90 ones — 14 keys: `Learning goal`, `By word count`, `Words to learn`,
>   `Or enter an exact number`, `Set goal`, `All`, `Learn all {n} words`, the intro, `Learn every word from the
>   sources you choose`, `Goal: learn all {n} words in the selected {c} source(s).`, `Pick one or more sources
>   above to set your goal.`, and the three set/clear toasts) is now translated in **all 10 non-English
>   languages** via a **`UI_V93 = JSON.parse(\`…\`)`** block right after `UI_V83` (`Object.assign` merge, same
>   pattern; key parity verified 14/lang). `By source` reused the existing v67 key. Source **names** stay
>   untranslated (proper nouns: Gang/Actie/Niveau/Perfectie; General via `SRC_SHORT`). The **"By word type"
>   chart was already fully translated** (`T(POS_LABELS[p])` + dict entries) — no change needed there.
> - Rebuilt from `scratchpad/build_v93.js` (emits the block, round-trip `JSON.parse` checked). SW cache bumped
>   across the iterations, ending **v89 → v94**.

**Progress "By source" donut (v67, Adi request):** below the "By word type" breakdown, an interactive
donut chart of words *learned per source* (General / Gang / Actie / Niveau). `countsBySource()` (right
after `countsByPos()`) mirrors it, using `inSource()` so a word shared between two books counts under
**each** source (matches how the source filter presents them — slice sums can exceed distinct-learned;
the donut centre shows the summed learned total, which is fine given overlaps are rare). Built inline in
`renderProgress()` just before `main.innerHTML`: an SVG donut (`.srcdonut`, `<circle>` arcs via
`stroke-dasharray`/`-dashoffset`, `rotate(-90)` group, 2px gap per slice) + a `.srclegend` of `.srcrow`s
(swatch + short name + `.posbar` progress fill + learned/total). Slice/row colours reuse the canonical
source-badge palette via `SRC_COLORVAR` = general `--muted` (grey), gang `--blue`, actie `--red`, niveau
`--yellow` — the 2px slice gaps + labelled legend keep identity from being colour-alone. Present sources
only (`SRC_ORDER` filtered by `bookChapters`). Tapping a slice **or** legend row runs
`srcFilter='<s>';posFilter='all';setTab('words')` (jumps to the source-filtered Words list, exactly like
a POS row jumps to a type-filtered list). **Empty state:** 0 learned → a single faint full ring + centre
`0`. Same **Pro/Free gate** as the POS breakdown (`.genbox.pro-lock` + `.srcbreak.locked-blur` +
`proOverlay()`). New UI keys `By source` / `Tap a source to study or browse just those words.` in all 10
non-English dicts; short legend labels (`SRC_SHORT`: General/Gang/Actie/Niveau) are literals, not `T()`ed.
CSS (`.srcbreak`/`.srcdonut`/`.donut-seg`/`.donut-num`/`.donut-lbl`/`.srclegend`/`.srcrow`/`.srcdot`/
`.srcname`) sits right after the `.posbreak` block; colours use theme tokens so it adapts per theme.

**Progress "By word type" bars coloured by source (v78, Adi request):** each type row's learned bar is
no longer a single blue fill — it's now **stacked source-coloured segments** (General grey / Gang blue /
Actie red / Niveau yellow), reusing the same `SRC_COLORVAR` palette as the "By source" chart below it, so
the bar shows *what kind of words* make up that type's learned count. `countsByPos()` now also tallies a
per-row `bySrc{}` map, attributing each learned word to **one** source via `primarySource(e)` (defined
just after `countsByPos`): a book word → its book (`gang`→`actie`→`niveau` order, matching `inSource`'s
taxonomy), a non-book word → `general`. Single-source attribution (unlike the donut's overlap-counting
`inSource`) means the segment counts **sum to exactly the row's learned total** — the whole point per Adi
("total will be 100, but the bar will be of different colours based on sources"). In `renderProgress()`
each row renders one `.posbar-fill` span per present source in `SRC_ORDER`, width = `bySrc[s]/total*100`
(unrounded; segment widths sum to the old `pc%`), `background:var(${SRC_COLORVAR[s]})`, `title` = short
name + count on hover. CSS: `.posbar` gained `display:flex` and `.posbar-fill` gained `flex:0 0 auto` so
the segments lay out horizontally (the single-fill `.srcrow .posbar` legend bars still work — one flex
child at `pc%`). No new UI-dict keys (segment titles use the literal `SRC_SHORT`). SW cache bumped
v77→v78.

**Pro / Free plan (v65, Adi request):** the app ships as a **freemium** gate. `isPro` (persisted
`dutch5k-pro`, default **false** = Free) is flipped on by the **"Pro to go"** box — a prominent
(non-accordion) `genbox.probox` rendered **first** in the drawer via `proBox()` in `renderMenu()`.
`unlockPro()` sets it (auto-unlocks for now — **payment/entitlement is still to be wired in**, this is
the placeholder); `lockPro()` (test-only "Switch back to Free" button, shown only when Pro) flips back so
both states are checkable offline. Both persist, `buildQueue()`+`render()`, and re-run `renderMenu()` when
the drawer is open.
- **Free limits** = `FREE_LIMITS = {general:500, gang:200, actie:0, niveau:0}`. `computeFree()` (called at
  the end of `buildDeck()`, fills module-level `freeIds`) takes the **lowest-rank N** entries of each
  source (rank 0/missing → back via `||99999`, so real frequency words fill the quota). A word is free if
  it falls under the cap of **any** of its sources — so a word shared between Gang (capped 200) and Actie
  (capped 0) stays reachable via Gang. **Source precedence = the app's own taxonomy** (`inSource`):
  `general` means *no book*, so a common frequency word that's **also** a textbook word counts as that
  book's word, not general — e.g. `terug` is filed under Actie and therefore locks in Free even though its
  rank is low. (If Adi ever wants top-frequency free regardless of book membership, change `computeFree`.)
- `isLocked(e)` = `!isPro && !freeIds.has(e.id)` — the single gate used by all three tabs.
- **Free-first ordering (v66, Adi request):** in Free mode `freeFirst(order)` (just below `isLocked`) pulls
  **all unlocked words to the front** of a deck-index list and puts every locked word after, so a Free user
  scrolls through *every* readable word in one run before hitting a clean wall of Pro-locks — a clear
  "here's what you get / here's what's behind Pro" boundary. Order **within** each group stays frequency-
  sorted (a plain rank sort isn't enough — a low-rank *locked* general word could otherwise jump ahead of a
  free *book* word, so the explicit partition is needed). No-op for Pro / all-free / all-locked views.
  **Shared by both the Learn queue and the Words list:** `buildQueue()` runs `fresh = freeFirst(fresh)` in
  the **shuffle-off** branch only (shuffle-on keeps its strategic mix); `renderWordList()` runs
  `freeFirst(list)` before the `listLimit` slice. (This *replaced* the earlier "queue leads with
  top-frequency free words" behaviour — free words were partly front-loaded by rank but not guaranteed all
  before every lock.)
- **Learn:** locked card renders blurred (`.card-body.locked-blur`) behind `proOverlay()` inside a
  `.card.pro-lock`; **no flip onclick**, only a **Skip** button.
- **Words:** locked list rows → `.wrow.locked-row` (blurred content + `.pro-mini` 🔒), tap → `openPro()`.
  Locked word-**detail** (reachable via synonym/antonym links) shows the same overlay card.
- **Progress:** the "By word type" `genbox` gets `.pro-lock` + `.posbreak.locked-blur` + `proOverlay()`
  when Free; the top stat tiles stay visible (only the POS breakdown is gated).
- `proOverlay()` = reusable absolute overlay (🔒 + "Unlock Pro version for full access" + CTA), all CTAs
  call `openPro(ev)` which `openMenu()`s and flashes the `.probox`. CSS: `.pro-lock`/`.locked-blur`/
  `.pro-overlay` (theme-aware bg overrides for Midnight/Sepia)/`.pro-cta`/`.probox` near the `.card` rules.
  Pro-specific strings go through `T()` (English-only for now — fall back to English in other langs).

> **Naming (v50→v53):** the third tab was displayed as "Overview" in v50 (it held settings then); v53 moved
> the settings out into the drawer and the visible label went **back to "Progress"**. The **internal id has
> always stayed `progress`**: `setTab('progress')`, `tab==='progress'`, `id="tabProgress"`, and all
> `dutch5k-progress*` storage keys are unchanged (renaming them would break saved progress). Only the nav
> button label + `T('Progress')` in `applyNavLang()` changed.

**Settings drawer (v53):** three-bar hamburger button (`#menuBtn`, in `.hdr-left` next to the logo) slides
`aside#drawer` in from the left over a `#scrim`; close via ✕, scrim tap, or Escape. Holds the
one-time-setup boxes that used to bloat the third tab, in order (v55, Adi request): **About the app**,
**App language**, **Theme** — plus, until v68, a **Backup** (Export/Import) box.

> **v68 (Adi request):** the **Backup box was removed** from the drawer (`backupInner` + its
> `menuBox('backup',…)` line dropped from `renderMenu()`, and the `backup:false` flag dropped from
> `menuSections`). The drawer now holds three boxes: About, App language, Theme. The `exportData()`/
> `importData()` functions and the `Backup`/`Export`/`Import`/`Your progress lives in this browser…`/
> `Import failed…` UI-dict keys are left in place (dead but harmless). The v64 accordion note below now
> describes **three** boxes, not four.

> **v79 (Adi request):** a fourth drawer box, **Contact us**, was added below Theme (`contact:false` added
> to `menuSections`; `menuBox('contact', T('Contact us'), contactInner)` appended in `renderMenu()`). It holds
> a **subject dropdown** (generic categories from the module-level `CONTACT_SUBJECTS` array — General feedback /
> Report a problem / Word or translation error / Feature request / Question / Other, each `T()`ed) and a
> **mandatory free-text message** `<textarea>` + a **Send** button. `sendContact()` validates the message is
> non-empty (empty → red `.cf-err` field + `.cf-hint` "Please enter a message before sending.", no send), then
> POSTs `{_subject,_template,_captcha,Category,Message}` as JSON to **FormSubmit's AJAX endpoint**
> (`https://formsubmit.co/ajax/<owner-email>`) — no backend, the app is static. **The owner email is never in
> the UI:** it's assembled at send time (`['whiskeyneat3060','gmail.com'].join('@')`) inside `sendContact()`
> only (verified: address appears nowhere in the rendered drawer HTML). On success the field clears, a thank-you
> toast shows, and the section collapses; on network error a retry hint + toast. **FormSubmit needs a one-time
> activation** — the first live submission emails the owner a confirmation link; click it once and all later
> messages arrive silently. **Sending won't work from an offline `file://` copy** (no page origin) — the form
> UI/validation is testable offline, delivery only on the deployed domain. UI strings are **English-only** (via
> `T()`, fall back to English in the 10 packs, same as the Pro feature — not yet translated). CSS: `.contact-form`
> /`.cf-label`/`.cf-input`/`.cf-err`/`.cf-hint`/`.cf-send` right after the `.lang-note` rule. `clearContactErr()`
> resets the field on input. SW cache bumped v78→v79.

> **v80 (Adi request):** the Contact-us form gained an **optional "Your email" field** (above the message)
> so Adi can reply if needed. It's a real `<input type="email">` (`id="cfEmail"`, email inputmode/autocomplete)
> with a muted helper note (`.cf-note`, "Only if you would like a reply…"). **Validation only runs when the
> field is non-empty** (blank sends exactly as before). `contactEmailError(raw)` (just below `clearContactErr`)
> returns `''` when ok or a human error string: it requires a **single** syntactically-valid address (rejects
> whitespace/comma/`;`/`<>()` → lists & display names), a proper local part (≤64, no leading/trailing/double
> dot, RFC-ish charset) and a real domain (labels of a-z0-9/hyphen, ≥1 dot, TLD ≥2 letters, no leading/trailing
> hyphen), **and** rejects **disposable/throwaway providers** via the module-level `CONTACT_DISPOSABLE` Set
> (~40 hand-picked domains — mailinator/yopmail/guerrillamail/10minutemail/tempmail/maildrop/getnada/… — "no
> fake ids"; offline app so no live DNS/MX check). On a bad value the email field goes red and `sendContact()`
> returns early with the error shown in `#cfEmailHint` (reuses `.cf-err-msg` red override on the note); on a good
> or empty value it sends. When provided, the address is added to the FormSubmit JSON as **`_replyto`** (so
> reply-to works) plus an **`Email`** field; when omitted, `Email:'(not provided)'` and no `_replyto` (delivery
> unchanged). `clearContactErr()` now also clears the email field/hint and restores the helper note;
> `sendContact()` clears `cfEmail` on success. New CSS: `input.cf-input` added to the `select/textarea.cf-input`
> selector, `.cf-note`/`.cf-note.cf-err-msg` after `.cf-hint`. UI strings **English-only** via `T()` (fall back
> in the 10 packs, same as the rest of the form). Owner email still assembled only in `sendContact()`, never in
> the rendered drawer (re-verified in jsdom). SW cache bumped v79→v80.

> **v81 (Adi request):** the Contact-us form's **message field + Send button are now Pro-gated** like the
> other locked features — sending is a Pro-only feature. In `contactInner`, the `<label>Message` + `<textarea>`
> + `#cfHint` + `#cfSend` are wrapped in a `.cf-locktarget` div (gets `pro-lock` when Free) around a
> `.cf-lockwrap` (gets `locked-blur` when Free), with `proOverlay()` appended when `!isPro` — the standard 🔒
> overlay + "Unlock Pro to go" CTA, identical to the Learn card / Progress breakdown gate. The **Subject
> dropdown and optional email field stay visible/usable** in Free mode; only the free-text message + Send are
> locked. `sendContact()` gained a defensive first-line guard `if(!isPro){ openPro(); return; }` so it can't
> fire in Free mode even if the button were somehow reached. Two new CSS rules after `.cf-send:disabled`:
> `.contact-form .cf-locktarget{display:flex;flex-direction:column;}` and `.cf-lockwrap{display:flex;
> flex-direction:column;gap:10px;}` preserve the form's column layout inside the wrapper. No new UI-dict keys
> (overlay reuses existing Pro strings). Verified in jsdom: Free → locktarget has `pro-lock`, overlay present,
> lockwrap blurred, `sendContact()` opens the upsell instead of sending; Pro → no lock, Send button live. SW
> cache bumped v80→v81.

> **v64 (Adi request):** the boxes are now **collapsible accordions** — each shows only its title
> plus a `›` chevron; tapping the header expands the details and rotates the arrow, tapping again
> collapses. All start collapsed. `renderMenu()`
> builds each box via `menuBox(id,title,inner)`; `toggleSection(id)` flips a per-section flag in the
> module-level `menuSections` object. That object lives **outside** `renderMenu()` on purpose so open
> state survives the `renderMenu()` re-runs fired by `setTheme`/`setLang` while the drawer is open.
> CSS: `.accbox`/`.acc-h` (header button, real `<button>` + `aria-expanded`)/`.acc-arrow` (rotates
> 90° when `.accbox.open`)/`.acc-body` (`max-height` reveal, `1200px` cap when open). The old
> `.genbox h3` heading rule is now unused by the drawer (still used by the Progress-tab `.genbox`es).
>
> **v87 (Adi: "when one menu is open and another is clicked both remain open… minimize the previous
> menu and then open the new one, otherwise there's no space left"):** the drawer accordions are now
> **single-open** (was v64 "toggle independently, several can be open"). `toggleSection(id)` collapses
> **every** section in `menuSections` before opening the tapped one — so at most one body is expanded at
> a time and the drawer never runs out of room. Tapping an already-open header still just closes it
> (nothing left open). One-line logic change only (`willOpen` captured, all flags zeroed, then the tapped
> flag set); markup/CSS untouched. SW cache bumped **v86 → v87**.

How it works / gotchas:
- **About box rewritten (v55–v56, Adi request — keep this framing):** intro = "build Dutch vocabulary in a
  structured way / one-stop app with all word details for practical learning"; **no offline claims** (the
  old "all available offline" phrase and "works with no internet" note were removed on purpose). Then
  sources in canonical order: ⭐ General 5K ("{n} popular Dutch words…"), 📚 Nederlands in
  Gang **(A0 → A2)**, 📚 Nederlands in Actie **(A2 → B1)**, 📚 Nederlands op Niveau **(B1 → B2)** (v58;
  reuses the existing `{n} words` key — no new UI-dict keys). CEFR ranges sit outside the `T()` strings
  (language-neutral). New UI-dict keys (fr/it/es): the intro sentence, `{n} popular
  Dutch words…`; the old offline-flavoured keys were deleted. **v57 (Adi request):** the deck-counts line
  ("{d} words in total…") between intro and sources was removed, along with its UI-dict keys.
  **v60 (Adi request):** the Actie line dropped "across {c} chapters — filter by source…" and now
  reuses the `{n} words` key like Gang/Niveau (all three book lines identical in form); the unused
  `{n} words across {c} chapters…` UI-dict keys (fr/it/es) were deleted.
  **v63 (Adi request):** the General line was relabelled **"General Words"** (bold literal, not
  `T()`ed — the source-filter chip still reads "General 5K") and its ⭐ icon swapped to 📚 so **all
  four source lines share the book icon**. A total-count sentence — `The app has {n} Dutch words in
  total, gathered from four sources:` (n=`deck.length`) — was **re-added above** the General line
  (this is the v57-removed "words in total" line, back by request, now with a full UI-dict key in all
  10 languages). The General description was shortened from the long "ordered by how often…" sentence
  to `{n} popular everyday Dutch words.` so it sits on one line like the book lines; the old long
  `{n} popular Dutch words…` key was **replaced** (key + value) in all 10 dicts.
- **Compact pickers (v54, Adi request — keep them this way):** Theme = three **swatch-only chips in one
  row** (no name/desc text; theme name kept as `aria-label`/`title`); App language = **code chips**
  (four EN/FR/IT/ES then, **eleven since v61**; full name in `aria-label`/`title`). Both wrap via `.themepick{flex-wrap}`, share
  `.themebtn` (language adds `.langbtn`); active = accent inset box-shadow (the old `.tcheck` ✓,
  `.tdesc`, `.tmeta` are gone). Intro `<p>` above each picker removed too. The `desc` fields in the
  `THEMES`/`LANGS` arrays are now **unused by the drawer** (kept as documentation); their UI-dict
  translations linger harmlessly.
- Drawer + scrim are **direct body children, outside `.topbar` and `#main`** — deliberate: the drawer's
  slide `transform` would trap Midnight's `position:fixed` bottom nav if it were an ancestor, and `render()`
  re-writing `#main` must never touch the drawer.
- Content is built by `renderMenu()` **on every open** and re-built by `setTheme`/`setLang` when
  `menuOpen` — that's how active-state highlights and translations stay current (drawer stays open across
  a theme/language switch). State: `let menuOpen` + `toggleMenu()/openMenu()/closeMenu()`; aria-expanded /
  aria-hidden kept in sync; `applyNavLang()` re-translates the Menu/Close aria-labels.
- z-index order: drawer 60 > scrim 58 > Midnight nav 50 > topbar/nav 20 (scrim must cover the pill nav).
- Per-theme skins at the end of each theme's CSS block: Midnight = solid `#12141f` panel (NOT the ambient
  gradient — it must read as a layer) + darker scrim; Sepia = paper-grain background, italic serif title,
  and the hamburger `position:absolute` in the corner of the centred title-page header
  (`.hdr-left{justify-content:center}` keeps the logo centred).
- New UI-dict keys (fr/it/es): `Progress`, `About the app`, `Menu`, `Close`; the old
  `Overview` key was replaced.
- **Drawer title = "Menu" since v57 (Adi request):** `renderMenu()` sets `T('Menu')` (shared with the
  hamburger aria-label); `.drawer-title` CSS uppercases it, so it displays **MENU** (Sepia keeps its
  italic no-uppercase skin). The old `Settings` UI-dict keys were deleted with it.

**Sticky top bar (v52):** `<header>` + `<nav>` are wrapped in `<div class="topbar">` —
`position:sticky; top:0; z-index:20`, opaque theme background — so logo *and* tabs stay frozen while
`#main` scrolls (before, only nav was sticky; the logo scrolled off). Per-theme bg overrides: Midnight
replicates the body's ambient gradient with `background-attachment:fixed` (bar blends invisibly; its nav
stays the fixed bottom pill, unaffected), Sepia replicates the paper grain. **Never put a `transform` on
`.topbar`** — a transformed ancestor becomes the containing block for `position:fixed`, which would trap
Midnight's bottom nav inside the top bar. The v47 nav compositing-layer rules (sticky + translateZ on
`nav` itself) are untouched — leave them, they fix the Android vanishing-tab-bar bug. In Sepia the whole
title-page header freezes (tallish block) — flagged to Adi as acceptable for now.

**Themes (v47 — three different LAYOUTS, not just palettes):** picked from the Theme box in the settings
drawer (was the Progress tab before v53). Content
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

**Shuffle (v49, opt-in):** `🔀 Shuffle Off/On` toggle button above the Learn filters (`toggleShuffle()`,
`.shuffle-btn`, persisted `dutch5k-shuffle`, default **off**). Off = unchanged behaviour: fresh words in
corpus-frequency order (most common first). On = *strategic* shuffle, not uniform — frequency-weighted
randomisation (Efraimidis–Spirakis: key `random^log2(rank+2)`, sort desc) inside `buildQueue()`, so common
words still tend to surface first but every session/rebuild draws a different varied set; rank-4000 rarities
don't flood the front. Only affects the *fresh* segment (learning/learned were already shuffled). Composes
with POS/source filters automatically — filters narrow the pool first, ordering happens after (verified:
shuffled verb-only rounds work). Toggling rebuilds the queue and clears session skips.

**App language (v51, expanded v61):** settings drawer → "App language" box (below Theme; lived on the
third tab until v53): **EN / FR / IT / ES**, plus since v61 (Adi request) **DE / PT / PL / TR / UK / RU /
BG** — 11 total. The v61 seven have full hand-written `UI` dicts (138 keys each, key/placeholder parity
with FR/IT/ES verified) but **stub `{}` content packs** — see Open work item 6. The app
*teaches* Dutch; this switches everything else — menus, word meanings, example translations. Dutch words,
forms and synonyms are never translated. `LANGS` array + `setLang(id)`; persisted `dutch5k-lang`, default `en`.

> **v75 (Adi request):** a short muted note sits **below the language chips** in the drawer's App-language
> box — "Some languages may not be fully translated. English is used where a translation is missing." Added
> in `langInner` as `<p class="lang-note">${T('…')}</p>`; new `.lang-note` CSS (12px, `--muted`, theme-aware,
> after the `.langbtn` rule). The note is a **UI string** (baked into the file, translated via `T()` in all
> 10 non-English dicts) so it switches with the language even offline — unlike the *content* packs it warns
> about. SW cache bumped v74→v75.

Two layers:
- **UI strings** — hand-written `UI` dicts in the JS (one per language, keyed by the **exact English
  string**), looked up via `T(s, vars)`. `{x}` placeholders substituted *after* lookup so translations can
  reorder them. Missing key → English. Nav + header live outside `#main`, so `applyNavLang()` re-labels
  them explicitly on switch/init. Date formatting follows `langLocale()`.
- **Content** (meanings, example EN sides, related-word meanings) — per-language packs
  `public/i18n/<id>.json`, a flat `{english → translated}` map (~11.5k entries, ~860 KB raw; Cloudflare
  gzips). Fetched on demand by `loadLangDict()`, runtime-cached by the SW (offline after first pick),
  applied at render via `ct(s)`. Missing key falls back to English — so fresh API enrichments simply show
  English until packs are regenerated.

Packs are machine-translated offline (Argos CTranslate2 models, all 10 pairs since v62; no
argostranslate/stanza — `i18n_translate.py` drives ctranslate2+sentencepiece directly). **Regenerate**
(after adding BOOKEX/GENEX content, or for a new language): `node scratchpad/i18n_extract.js`
(jsdom-dumps every meaning + example string from the *built* deck — keys must match render-time strings
exactly, so always extract post-overlay) → `python3 scratchpad/i18n_translate.py` (`pip install
ctranslate2 sentencepiece sacremoses subword-nmt`; download the `.argosmodel` zips from the argospm
index, extract into `~/.local/share/argos-translate/packages/`, and sync `PKGDIR` to the actual dir
names) → `python3 scratchpad/i18n_check.py` (corruption gate — must exit 0 before shipping). Gotchas
learned in the v62 run: **`intra_threads` MUST be 1** — ctranslate2 4.8.1 nondeterministically splices
foreign tokens into batch output at 2+ threads (re-verified; the old "≤2 is safe" note was wrong).
**v74 correction: do NOT parallelise per-process either** — running 4 ct2 processes at once on a 4-core
box oversubscribes the CPU and re-triggers the *same* nondeterministic corruption even at
`intra_threads=1` (bg came out with 3,523 glued-script drops → pack halved; re-ran clean sequentially).
**Regenerate languages one at a time, sequentially** (~5 min each, ~40 min for all 10; Turkish ~25 min).
The `i18n_check.py` glued-script gate catches this — a spiking glued/rejected count = contention
corruption, re-run that language alone. The **en_pl package has no sentencepiece.model**
— it ships Moses+subword-nmt BPE (`bpe.model`, `@@` joiners, `&apos;`/`@-@` escapes); the script
auto-detects and handles both layouts. Glosses are translated part-by-part on commas/semicolons +
deduped (MT mangles bare comma lists); `(form of X)` suffixes — **both** curly-quoted and bare (629 +
457 in the deck) — are stripped pre-MT and re-attached with a localized label so the Dutch lemma never
reaches the model (Cyrillic models transliterate-mangle it otherwise, e.g. "гаанrd"). Cyrillic packs
(bg/uk/ru) additionally drop any entry with Latin glued onto Cyrillic (residual model garbage → English
fallback). Turkish is the weakest model (~440 strings rejected for length blowups → stay English).

> **v70 corruption sweep (Adi request "review every word in every language"):** a post-hoc audit of all
> ~123k pack strings pulled **2,247 mechanically-corrupt entries** (deletions only — `ct()` falls back to
> the hand-written English, always better than garbage). Two verified classes: (1) **token/phrase loops**
> — `≥3` consecutive identical tokens ("It it it it it it", "coraggio coraggio coraggio coraggio") + a
> curated garbage-marker regex (`. kgm`, `@ action: inmenu`, `unit description in lists`, EU-reg
> boilerplate, brand ad-copy); (2) **genitive self-loops** ("storia della storia", "forza di forza",
> "milioni di milioni") + Turkish phrase-loops ("would like would like would like"). Per-pack drops: tr
> 1844, it 316, bg 36, es 20, pl 12, de 7, uk 5, pt 3, ru 3, fr 1. **False-positive guards that MUST stay
> if this is re-run:** skip source keys containing ` / ` (synonym lists legitimately mirror-repeat, e.g.
> "for example / for instance" → "zum Beispiel / zum Beispiel"); the genitive rule excludes `in`/`da`/`do`
> preps ("etwas in etwas anderes" = correct German; "od czasu do czasu" = correct Polish idiom) and
> full-sentence entries (French "le son de son stylo" — son/son homographs). Length-*only* blowups were
> **kept** — many are valid-but-longer translations, not corruption. This is a *mechanical* pass; subtler
> mistranslations that pass all checks remain. No source strings were regenerated, so a future pack
> regeneration reintroduces these unless the audit is re-run.
>
> **v73 incremental pack update (after the v71–v72 meaning sweep):** the 155 corrected general-word glosses
> changed the deck's English meaning *keys*, so the packs had no translation for them (`ct()` fell back to
> English in all 10 langs). **Do NOT full-regen to fix this** — a full `i18n_translate.py` run reintroduces
> the v70 corruption deletions above. Instead translate **only the delta** and merge: extract the changed
> `word→meaning` pairs (`git diff <fix-commits> | grep '"w": {"m":'`), split each gloss on `,`/`;` into
> units, translate units per language with the same Argos ct2 flow (`intra_threads=1`, one model at a time —
> download/extract/translate/`rmtree` to fit the disk allowance; **model dir names vary**: `it`/`es` are
> `en_it-1_0`/`en_es-1_0` extracting to bare `en_it`/`en_es`, `uk` is `en_uk-1_4`, so locate the extracted
> dir by finding the child containing a `model/` subdir, not by name), rebuild each changed meaning's pack
> value (translate parts, dedupe, rejoin `, `), and `pack.update(add)` into the existing `public/i18n/<lang>.json`
> — existing keys untouched. **Clean the new keys** (ct2 loops recur in the fresh output): collapse consecutive
> repeated tokens (case/punctuation-normalized, keep the later token so trailing commas survive), then **drop**
> any value whose normalized alphabetic token still repeats 2+ times → English fallback (safe; correct meaning).
> Guard kept: distinct comma-separated senses sharing a prefix (pl "głos, głosowanie" = voice, vote) survive
> because whole tokens differ. Turkish took the most drops (~40, weakest model); Cyrillic glued-script check
> stayed 0. Per-lang delta coverage 142–153/153; the rest fall back to English. Bumped SW cache (v72→v73).
>
> **v74 full regeneration — leak fix (Adi spotted bg `tel` = "Брой, tally", English `tally` beside a Bulgarian
> word):** the root cause was one line in `i18n_translate.py` — `parts = [out.get(p, p) for …]`. When a
> multi-sense gloss (`count; tally`) had one sense the model dropped, `out.get(p, p)` kept the **raw English
> word** and joined it with the translated siblings → a half-English mix. **Fixed:** keep a gloss only if
> **every** sense genuinely translated (present in `out` AND different from its English source); otherwise
> drop the whole gloss so `ct()` falls back to full English — never a script-mix. A Cyrillic-only residual
> filter also drops multi-sense glosses whose value still carries a lowercase-Latin head word outside any
> paren/quote (`you (informal); your` → "you …"), while single-sense glosses are spared so genuine
> loanwords/proper nouns (website, Groningen, brie, IT/DJ/PC) keep their translated annotations.
> **The whole v70 corruption audit is now baked into `i18n_translate.py`** (`is_corrupt`: 1/2/3-gram loops
> repeated 3×, genitive self-loops `X di/della/du/von X` gated to short glosses, curated garbage markers;
> same false-positive guards — skip ` / ` synonym sources, exclude in/da/do/de preps, spare full sentences) —
> **so a full regen no longer reintroduces the v70 deletions, and the old "do NOT full-regen" warning is
> superseded.** Result: English-sense leaks in Cyrillic packs bg 142→9, uk 20→3, ru 8→6 (the bg residue is
> all legit loanwords/proper nouns); corruption gate 0 glued across all 10; coverage 11.4k–12.2k/12.36k
> except tr 9.2k (model weakness, not corruption). **Remaining `tel` second senses in other langs
> (uk "пердят", it "tal", pl "tall") are model mistranslations, NOT leaks — a separate pre-existing quality
> issue the fix doesn't address.** Pipeline unchanged otherwise (extract → translate → check). Bumped SW
> cache (v73→v74). See also the **v74 sequential-only** correction in the App-language regenerate note above.
>
> **Add a language:** entry in `LANGS`, a full `UI` dict, add its id to the two scripts, regenerate, bump SW
cache. Gotcha: a *missing* pack file doesn't 404 — the SPA fallback returns index.html with HTTP 200, so
`r.json()` throws and `setLang` toasts the connection error; ship the pack file with the `LANGS` entry.

Filters in Learn + Words: **status** (new/learning/learned), **POS** (verb/noun/adj/...), **source**
(All / General 5K / Gang / Actie / Niveau). Book words show A/G/N badges + chapter tags ("Actie H3",
"Niveau H5"). Badge letters come from the map in the Words-row template (`{actie:'A',gang:'G',niveau:'N'}`);
badge colours `.sb-actie` red, `.sb-gang` blue, `.sb-niveau` yellow with dark text (yellow bg needs it).

POS + source filters are **identical & same order across both tabs** — render from shared helpers
`posFilterButtons()`/`srcFilterButtons()` (on `POS_FILTER` + `srcFilterOpts()`). Canonical source order:
**All, General, Gang, Actie, Niveau** (by CEFR level). Edit the shared helpers, not per-tab markup, or tabs drift. (Learn:
`setLearnPos`/`setLearnSrc`→full `render()`. Words: `setPosFilter`/`setSrcFilter`→partial `renderWordList()`
with scoped `button[data-p]` update so POS refresh doesn't clobber the source bar.) **Bar order (v63):
source bar sits *above* the POS bar on both tabs** — Words already did this; the Learn tab was flipped to
match (`shuffleBar + srcBar + posBar` in the two `main.innerHTML` spots; the shuffle toggle stays on top).

> **Filter/mode bar scroll preserved on Learn (v85, Adi: "when scrolling thru filters and then something is
> selected, the filter goes back to original state… keep the filters there itself"):** the Learn handlers
> `setLearnPos`/`setLearnSrc`/`setMode` called a **full `render()`**, which rebuilds all of `#main` — so the
> horizontally-scrollable mode/filter bars (`.posscroll`) were recreated scrolled to the left. Scrolling to a
> filter near the end and tapping it snapped the bar back to the start, putting the next pick out of reach.
> New helper **`renderKeepBars()`** (just above `setLearnPos`) captures each scrollable bar's `scrollLeft` by a
> stable selector (`.modebar`, `.srcfilters.learn-pos`, `.posscroll.learn-pos:not(.srcfilters)` — the last
> excludes the non-scrolling `.shuffle-bar`), runs `render()`, then restores the saved offsets on the freshly
> built bars. Wired into all three Learn handlers. **Words tab needed no change** — `setPosFilter`/`setSrcFilter`
> already do partial updates (className swap + `renderWordList()`) and never rebuild the bars. SW cache bumped
> v84→v85.

**Search result ordering (v76, Adi request):** the Words search matches the query as a substring of the
Dutch word **or** the (English/translated) meaning, but results were left in corpus-frequency order — so an
exact hit (searching "tell" → the word `tell`) sat far below words that merely contain it (`teller`,
`vertellen`). `renderWordList()` now sorts matches by `searchScore(e, q)` (helper just above `bookChapters`)
**before** `freeFirst()`; a stable sort keeps frequency order within each relevance tier, so every matching
word still appears — only the sequence changes. Score tiers (lower = better): `0` exact match (field === q),
`1` starts-with-query-as-whole-word, `2` whole-word match inside a field, `3` prefix of a longer word,
`4` mid-word substring. "Whole word" via a Latin+diacritic boundary regex `(^|[^a-zÀ-ɏ])q($|…)`;
best (lowest) score across the three fields (`w`, `m`, `ct(m)`) wins. Only kicks in when `q` is non-empty.

Synonyms/antonyms render as tappable rows; if the word is in deck it links to its card, with back-stack
(`wordViewStack`).

**Word-detail Back behaviour (v69, Adi request):** `openWord`/`backFromWord` now remember where a
detail chain was entered so **Back returns you to that exact place**, not the top of the Words list:
- `wordListScrollY` — captured (`window.scrollY`) when a word is opened **from the Words list**;
  `backFromWord` restores it (`scrollTo(0, wordListScrollY)`) so the list keeps your scroll position
  instead of snapping to the top. `listLimit` isn't reset on Back, so the restored height matches
  even after "Show more".
- `wordOrigin` (`'words'` | `'learn'`) — captured on the **first** open of a chain (`wordView===null`).
  Following a synonym/antonym **from a Learn flashcard** opens the detail in the Words tab; on Back
  with an empty `wordViewStack`, `wordOrigin==='learn'` sends you back to the **Learn card**
  (`tab='learn'`) rather than dumping you on the Words list. From the Words list it stays in Words and
  restores scroll. Stepping back through a synonym→synonym chain (non-empty stack) still lands on the
  parent card, top-aligned. The Back button label reads **"Back"** (not "Back to list") whenever the
  stack is non-empty **or** `wordOrigin==='learn'` (reuses existing `Back`/`Back to list` UI keys — no
  new translations).

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
4. **Pro/Free gate — DONE (v65, gate only).** Freemium plan shipped (see the Pro/Free section under
   Features): Free unlocks General 500 / Gang 200 / Actie 0 / Niveau 0, the rest locks behind a Pro
   overlay; the "Pro to go" drawer box unlocks. **Still open: the actual payment/entitlement** —
   `unlockPro()` auto-unlocks as a placeholder; wire a real purchase/restore flow when ready. (Adi also
   wanted a premium gate for the API key rather than pasting one in — could fold into the same Pro tier.)
5. **Junk filter — DONE (first pass).** Curated `JUNK` set (above `buildDeck`, ~354 words) drops corpus noise:
   proper names, brands, foreign places, standalone abbrevs, English tokens duplicating a Dutch word.
   `buildDeck()` skips them in the `FREQ` loop (`if(JUNK.has(w)) return;`) so they never enter deck/counts.
   Conservative: anything with a real meaning/example or book membership kept (units `km`, loanwords `app`/`tv`,
   countries, Dutch places all stay). To extend, add to `JUNK` — but first validate the candidate has no
   meaning/example/book tag. Deck dropped 6,100 → 5,754. CEFR/spoken-level tag still unbuilt.
6. **i18n packs — DONE (v62).** All 10 languages now ship real content packs (~12k entries each,
   ~0.9–1.2 MB raw): the seven v61 stubs (DE/PT/PL/TR/UK/RU/BG) got full packs, and FR/IT/ES were
   regenerated to cover the 499 Niveau words they were missing. Regenerated in a remote session (the
   old "Argos too heavy" blocker is gone — the script needs only ctranslate2+sentencepiece, no
   argostranslate/stanza/torch; models downloaded per-pair from argos-net.com, ~1 GB total for all 10).
   Pipeline + gotchas documented in the App-language section above; `i18n_check.py` gates corruption.
   Missing keys still fall back to English by design (Turkish has the most, ~440).
