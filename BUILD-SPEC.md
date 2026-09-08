# Dutch To Go — Build Specification

**Version of record:** service-worker cache tag `dutch5k-v110` (`public/sw.js`).
**Source of truth:** a single file, `public/index.html` (1,837,589 bytes), plus 12 static
asset files and 10 i18n content packs.
**Document status:** living document. Every section and subsection is numbered so revisions
can reference a specific clause (e.g. "amend §7.3.2").

**Attached companion files (not inlined here):**

| File | Contents | Records |
|---|---|---|
| `dutch-to-go-deck-v110.json` | The full built vocabulary deck (the output of §7.1 `buildDeck`) | **6,752** |
| `dutch-to-go-ui-strings-v110.json` | All UI translation dictionaries, 10 non-English languages | 214 keys × 10 languages |
| `public/i18n/{fr,it,es,de,pt,pl,tr,uk,ru,bg}.json` | Content packs (word meanings + example translations) | 9,201 – 12,343 entries each |

---

## 1. PRODUCT OVERVIEW

### 1.1 What the app is

Dutch To Go is a single-screen-at-a-time Dutch vocabulary trainer delivered as a static
progressive web app. It ships **6,752 Dutch words** baked into the application file itself —
no server, no database, no login required to study. Every word carries an English meaning;
6,729 of them also carry at least one hand-written Dutch example sentence with an English
translation, and many carry grammar forms, synonyms and antonyms.

The user studies through flashcards in one of six study modes, marks each word Again /
Learning / Know it, and a spaced-repetition scheduler decides when that word comes back.
Progress, streaks and statistics are kept in browser storage.

### 1.2 Who it is for

Adult self-directed learners of Dutch working from roughly A0 to C1. The word stock is
organised into CEFR level bands, so a beginner can restrict study to the A0–A2 band and an
advanced learner to B2–C1. The interface itself can be displayed in 11 languages, so the
learner does not have to know English to use it.

### 1.3 Core user journey

1. Open the app. No sign-up, no onboarding. The **Learn** tab is already showing a
   flashcard for the most frequent Dutch word the user has not yet seen.
2. Tap the card to flip it and reveal the meaning, grammar forms, example sentences and
   related words. Tap a speaker icon anywhere to hear the Dutch spoken.
3. Grade the card: **✗ Again**, **≈ Learning**, or **✓ Know it**. The app schedules when
   that word returns, advances to the next card, and updates the progress strip at the top.
4. Optionally switch study mode (typed recall, fill-the-blank, listening, de/het gender
   drill, reverse) or narrow the deck by word type and CEFR level via the filter dropdowns.
5. Browse or search the whole word list on the **Words** tab; tap any word for its full
   detail card; follow synonym/antonym links to other words.
6. Check the **Progress** tab for the learned/learning/new split, the review queue, the
   hardest words, a 14-day activity calendar, and breakdowns by word type and by source.
7. Optionally open the **Profile** page (avatar in the header) to create a local account,
   set a learning goal, set a daily study plan, and enable a daily reminder notification.

### 1.4 What makes it distinctive

- **1.4.1 Three complete visual themes, not three palettes.** Minimalistic is a Mondrian
  grid (black rules, red/blue/yellow blocks, sharp corners, tabs on top). Midnight is a dark
  mobile app (rounded glowing cards, ambient gradient, floating pill nav at the bottom).
  Sepia is a printed book (serif type, narrow cream column, ruled entries, running-head text
  nav). The DOM is identical in all three; each is pure CSS scoped to `html[data-theme]`.
- **1.4.2 Fully offline.** All word data is inside the HTML file. A service worker caches
  the shell. Nothing about studying requires a network.
- **1.4.3 Level-banded sources.** Words are tagged Essential / General / A0–A2 / A2–B1 /
  B1–B2 / B2–C1, filterable everywhere and visible as coloured badges in the word list.
- **1.4.4 Freemium gate that keeps a coherent free experience.** Free users get the lowest-
  rank 150 Essential + 500 General + 200 A0–A2 words (850 total). Free-plan lists and queues
  put every unlocked word first, so the user reaches a clean wall rather than a scatter of
  locks.
- **1.4.5 Deep 11-language interface.** UI strings, word meanings and example translations
  are all localisable; the Dutch itself never is.

### 1.5 What the app is NOT (current state)

- There is **no backend of any kind**. Accounts, sign-in and the Pro purchase are local
  placeholders that write to browser storage (§9.4).
- There is **no cross-device sync**. Clearing browser storage destroys all progress.
- Reminders are local timers, not push. They only fire while a tab is open (§7.9).

---

## 2. SCREEN INVENTORY

### 2.0 Global chrome (present on every screen except where noted)

The page is a flex column: a sticky `.topbar` (header + nav), then `<main id="main">`, plus
three overlay layers (scrim, drawer, toast) that are direct children of `<body>`.

**2.0.1 `.topbar`** — `position:sticky; top:0; z-index:20;` opaque `var(--paper)` background.
Contains `<header>` and `<nav>`. Must never receive a CSS `transform` (a transformed ancestor
would trap Midnight's `position:fixed` bottom nav inside it).

**2.0.2 `<header>`** — `border-bottom: var(--rule); padding:14px 16px; display:flex;
align-items:center; justify-content:space-between; gap:12px`.

| Slot | Element | Detail |
|---|---|---|
| Left (`.hdr-left`, flex, gap 12px) | `button.menu-btn#menuBtn` | 38×38px, three 3px `var(--ink)` bars, gap 4px, `border:var(--rule)`, `aria-label` = "Menu", `aria-expanded`, `aria-controls="drawer"`. Opens the drawer. |
| Left | `div.logo` | Literal markup `DUTCH <span>to go</span>`. `.logo` = `var(--font-head)`, weight 900, 20px, letter-spacing −0.5px. `.logo span` = `var(--red)`, italic, weight 700, letter-spacing 0. |
| Right (`.hdr-right`, flex, gap 12px) | `div.counter` | Two lines, right-aligned. `<small>` = "Words learned", 10px, weight 400, letter-spacing 1px, uppercase, `var(--muted)`, `display:block`. Below it `<span id="hdrCount">` = `"<goalLearned> / <goalTotal>"`, `var(--font-head)` weight 700 13px. |
| Right | `button.profile-btn#profileBtn` | 36×36px circle, `border:2px solid var(--line)`. Guest: 👤 (U+1F464). Signed in: up-to-2 uppercase initials, `.signed-in` → blue bg / white text. Pro: `.is-pro` → yellow bg / `#111` text / `var(--ink)` border. On the Profile page: `.on-tab` → `box-shadow:0 0 0 2px var(--accent) inset`. |

**2.0.3 `<nav>`** — three equal-flex buttons, `border-bottom:var(--rule)`,
`position:sticky; top:0; z-index:20; background:var(--paper); transform:translateZ(0)`
(the translateZ is load-bearing: it promotes nav to its own compositing layer and fixes an
Android-Chrome bug where the whole tab bar vanished after a tab tap). Buttons:
`padding:12px 4px`, `var(--font-head)` weight 700 13px uppercase letter-spacing 1px,
`border-right:var(--rule)` except the last. Active tab: `background:var(--ink); color:var(--paper)`.

| id | Default label | Localised via |
|---|---|---|
| `tabLearn` | Learn | `T('Learn')` |
| `tabWords` | Words | `T('Words')` |
| `tabProgress` | Progress | `T('Progress')` |

The Profile page is a fourth `#main` view but has **no nav button** — while it is showing,
all three nav buttons render inactive. That is intended behaviour, not a bug.

**2.0.4 `<main id="main">`** — `flex:1; padding:16px; max-width:640px; width:100%;
margin:0 auto; padding-bottom:48px`.

**2.0.5 `div.toast#toast`** — `position:fixed; bottom:16px; left:50%;
transform:translateX(-50%); background:var(--ink); color:#fff; padding:10px 18px;
font-size:13px; font-weight:600; opacity:0; pointer-events:none; transition:opacity .25s;
z-index:99; max-width:90vw; text-align:center`. `.show` sets `opacity:1`. Auto-hides after
**2600 ms**. Content is set with `innerHTML` (so emoji entities render).

**2.0.6 Progress strip `mondrianStrip()`** — rendered at the top of the Learn card body and
the top of the Progress tab. `div.mstrip`: `display:flex; height:22px; border:var(--rule);
margin:16px 0`. Children have `border-right:3px solid var(--line)` except the last.
Three segments, widths as percentages of `max(total,1)`:
`learned` (`.m-learned`, blue) at `max(learned/total*100, learned?2:0)`,
`learning` (`.m-learning`, yellow) at `max(learning/total*100, learning?2:0)`,
and `.m-new` (paper) filling `max(100 − pl − pg, 0)`. The learned and learning divs are
**omitted entirely** when their count is 0. `title` = `T('blue = learned, yellow = learning, white = new')`.

---

### 2.1 Screen — LEARN (`tab === 'learn'`, the default)

**2.1.1 Purpose.** Present one flashcard at a time from the study queue and collect a grade.

**2.1.2 Layout order (top to bottom).** `renderLearn()` writes exactly two containers into
`#main`: `<div id="learnBars">` and `<div id="learnBody">`. This split exists so a filter
change rebuilds only the body and never closes an open dropdown.

`#learnBars` (from `learnBars()`):
1. `div.filterbar` — `display:flex; gap:8px; margin-bottom:12px; align-items:stretch;
   flex-wrap:nowrap`. Contains, in order:
   1. **Study mode** dropdown (`drop-lmode`), single-select.
   2. **Source** dropdown (`drop-lsrc`) — rendered only when `srcFilterOpts().length > 2`.
   3. **Word type** dropdown (`drop-lpos`), multi-select.
   4. **Options** dropdown (`drop-lopts`), multi-select.
   Each `.msdrop` is `flex:1 1 0; min-width:0`, so all dropdowns are exactly equal width on
   every viewport.
2. `div.drill-banner` — **only when `leechOnly === true`**. 🔥 + `T('Drilling hardest words')`
   + an ✕ button (`aria-label` = `T('Exit drill')`) that calls `exitDrill()`. Style:
   `border:2px solid var(--red)`, red text, `var(--font-head)` weight 800, 12px, uppercase,
   letter-spacing 1px, `padding:8px 12px; margin-bottom:10px`.

`#learnBody` (from `renderLearnBody()`), in order: progress strip → card → actions →
`div.deckinfo` counter → optional daily line → optional due line.

**2.1.3 The dropdown widget (`.msdrop`).** A native `<details>` element.
- `<summary>`: `list-style:none`, marker hidden, `display:flex; justify-content:space-between;
  gap:4px; padding:8px 9px; border:2px solid var(--line); background:var(--paper);
  font-family:var(--font-body); font-size:12px; font-weight:600; white-space:nowrap;
  overflow:hidden; line-height:1.2`. Inside: `<span class="lbl">` (`flex:1 1 0; min-width:0;
  text-overflow:ellipsis`) and `<span class="msdrop-arw">▾</span>` (9px, `var(--muted)`,
  `transition:transform .15s`, rotated 180° when open).
- Border turns `var(--blue)` (Sepia: `var(--accent)`) when the dropdown is open **or** has
  at least one selection (`.on`).
- `<div class="msdrop-menu">`: `position:absolute; z-index:45; top:calc(100% + 4px); left:0;
  min-width:100%; max-width:260px; background:var(--card-bg,var(--paper));
  border:2px solid var(--line); box-shadow:var(--shadow); max-height:300px;
  overflow-y:auto; padding:4px`. The **last** dropdown in a `.filterbar` anchors right
  (`left:auto; right:0`) so it cannot spill off-screen.
- `<button class="msdrop-opt">`: `display:flex; gap:6px; padding:8px 8px; font-size:13px;
  border-radius:6px`. Contains `<span class="chk">` (15px wide, centred, `var(--blue)`,
  weight 700, shows `✓` when selected) and `<span class="otxt">` (ellipsised).
  Selected rows get `.sel` → `font-weight:700`. Hover: `background:var(--line)`
  (Midnight: `rgba(255,255,255,.08)`).

**Summary label rule** (`dropSummary`): single-select shows the chosen option's label.
Multi-select shows the filter's **plain-language name** when nothing is selected (never the
word "All"), the option's own label when exactly one is selected, and `Name · N` when 2+
are selected.

**Dropdown registry** (`dropDef`):

| key | Multi | Bound state | Name | Options | Reset row |
|---|---|---|---|---|---|
| `lmode` | no | `learnMode` | `T('Study mode')` | the six `LEARN_MODES`, each `icon + ' ' + T(label)` | — |
| `lsrc` | yes | `learnSrc[]` | `T('Source')` | `srcFilterOpts()` minus the leading "all" | `T('All sources')` |
| `lpos` | yes | `learnPos[]` | `T('Word type')` | `POS_FILTER` minus "all", labelled via `POS_LABELS` | `T('All types')` |
| `lopts` | yes | derived from `learnShuffle`/`newOnly` | `T('Options')` | `🔀 T('Shuffle')`, `🔴 T('New words only')` | — |
| `wstatus` | yes | `statusSel[]` | `T('Status')` | `T('new')`, `T('learning')`, `T('learned')` | `T('All')` |
| `wsrc` | yes | `srcFilter[]` | `T('Source')` | as `lsrc` | `T('All sources')` |
| `wpos` | yes | `posFilter[]` | `T('Word type')` | as `lpos` | `T('All types')` |

Closing rules: a document-level `click` listener closes every open `details.msdrop` that
does not contain the click target; option buttons call `stopPropagation()` so ticking a box
keeps the menu open. `Escape` closes all open dropdowns (a separate listener from the one
that closes the drawer).

**2.1.4 The six study modes (`LEARN_MODES`).**

| id | Label | Icon (entity) | Card renderer | Grading |
|---|---|---|---|---|
| `cards` | Cards | `&#128196;` 📄 | `recogCardHtml` | self-grade after flip |
| `reverse` | Reverse | `&#128260;` 🔄 | `recogCardHtml` | self-grade after flip |
| `type` | Type | `&#9000;` ⌨ | `typeCardHtml` | auto-graded |
| `listen` | Listen | `&#128266;` 🔊 | `recogCardHtml` | self-grade after flip |
| `cloze` | Cloze | `&#9986;` ✂ | `typeCardHtml` | auto-graded |
| `dehet` | `de / het` | `&#127475;&#127473;` 🇳🇱 | `deHetCardHtml` | auto-graded |

`learnModeLabel(m)` returns the literal string `de / het` for the `dehet` mode (never
translated — it is Dutch) and `m.label` otherwise.

**2.1.5 Recognition card (`cards` / `reverse` / `listen`).**

`div.card` — `border:var(--rule); background:var(--paper); min-height:300px; display:flex;
flex-direction:column; cursor:pointer`, `tabindex="0"`, `role="button"`,
`aria-label = T('Flip card')`, `onclick="flip()"`.
- `div.card-tag` — `font-size:10px; letter-spacing:2px; text-transform:uppercase;
  font-weight:600; padding:8px 12px; border-bottom:var(--rule); display:flex;
  justify-content:space-between`. Left span: `T(entry.t || 'word')`, plus ` · de` / ` · het`
  when the entry has an article. Right span: `T(status).toUpperCase()` where status is
  `new` / `learning` / `learned`.
- `div.card-body` — `flex:1; display:flex; flex-direction:column; justify-content:center;
  padding:24px 20px; gap:8px`.

Front faces:

| Mode | Front content | Hint text |
|---|---|---|
| `cards` | `wordBlock`: `.word-nl` (the Dutch word + speaker button), `.rankline` (rank text), and a `.rankline.booktag` chapter line when the word is in a textbook | `T('Tap to reveal meaning, forms, examples &amp; related words')` |
| `reverse` | `.prompt-lbl` = `T('What is this in Dutch?')`, then `.word-en.big` with the translated meaning | `T('Tap to reveal the Dutch word')` |
| `listen` | `.prompt-lbl` = `T('Listen, then recall the meaning')`, then `.bigplay-wrap` containing `button.bigplay.spk` (88×88px circle, `border:var(--rule)`, 44×44px speaker SVG, `aria-label = T('Play audio')`) | `T('Tap the card to reveal')` |

The hint is `div.word-hint` — 12px, `var(--muted)`, `margin-top:12px`.

Back faces: `cards` shows `meaningBlock(e)`; `reverse` and `listen` show
`wordBlock(e) + meaningBlock(e)`.

`meaningBlock(e)` has four states:
1. `e.rich` → `.word-en` (translated meaning) + Forms section + Examples section + Synonyms/Antonyms sections.
2. `e.hasMeaning` only → `.word-en` + Synonyms/Antonyms + `.word-hint` (margin-top 14px) reading `T('More examples and grammar forms are being added.')`.
3. `enrichInFlight` → `.word-en` reading `T('Preparing this card…')`.
4. otherwise → `.word-en` reading `T('Not translated yet')`.

Action rows (`div.actions`: `display:flex; gap:0; margin-top:14px; border:var(--rule)`;
buttons `flex:1; padding:14px 6px; var(--font-head) weight 700 13px uppercase
letter-spacing 0.5px`, separated by `border-left:var(--rule)`):

| State | Buttons |
|---|---|
| Not flipped | `T('Show answer')` (plain) · `↷ T('Skip')` (`.btn-skip`, 12px, `var(--muted)`) |
| Flipped | Row 1: `✗ T('Again')` (`.btn-again`, red text) · `≈ T('Learning')` (`.btn-learning`, yellow bg) · `✓ T('Know it')` (`.btn-know`, blue bg, white text). Row 2: a second `.actions` bar with `↷ T('Skip for now')` |

**2.1.6 Typing card (`type` / `cloze`).** `div.card.no-flip` (`cursor:default`, no flip
handler). Card-tag left span is `T('Type')` or `T('Cloze')`.

Prompt, before an answer:
- `type`: `.prompt-lbl` = `T('Type the Dutch word')`, `.word-en.big` = translated meaning,
  and a `.rankline` with the part of speech (+ ` · de`/` · het`) when present.
- `cloze`: `.prompt-lbl` = `T('Fill in the missing word')`, `.cloze-sent` (19px, line-height
  1.5, weight 600) built as `pre` + `<span class="cloze-blank">_____</span>` + `post`, then
  `.cloze-en` (13px, `var(--muted)`, italic) with the translated English of the sentence.
  `.cloze-blank`: `display:inline-block; min-width:70px; text-align:center;
  border-bottom:3px solid var(--red); color:var(--red); font-weight:800; padding:0 6px`.

Then `<input type="text" id="typeInput" class="type-input">` —
`width:100%; padding:13px 14px; border:var(--rule); font-size:18px; margin-top:14px;
background:var(--paper); color:var(--ink)`; focus turns the border blue.
`autocomplete=off autocapitalize=none autocorrect=off spellcheck=false`,
placeholder `T('Type here…')`. It is auto-focused after render, and **Enter** submits.

Actions before answering: `T('Check')` (`.btn-know`) · `↷ T('Skip')`.

After answering, the prompt stays (with the blank now filled by the correct answer in cloze
mode) and a `div.result` box appears — `margin-top:14px; padding:12px 14px;
border:2px solid var(--line)`; `.ok` → blue border + `color-mix(in srgb, var(--blue) 12%, var(--paper))`
background; `.bad` → red equivalents. Inside:
- `.result-head` (`var(--font-head)` weight 900 14px uppercase letter-spacing 1px) reading
  `✓ T('Correct!')` or `✗ T('Not quite')`.
- `.ans-reveal` — `.ans-word` (`var(--font-head)` weight 900 26px) with the correct answer,
  plus a speaker button.
- `.ans-yours` (13px, `var(--muted)`, margin-top 4px) reading `T('You typed:')` followed by
  the user's answer inside `<s>` — shown only when the answer was wrong and non-empty.
- `.word-en` (margin-top 8px) with the word's meaning.

Actions after answering: if correct, one button `T('Continue') →` which marks `learned`.
If wrong, two buttons: `↷ T('Review again')` (marks `again`) and `T('I knew it')`
(marks `learned`).

**2.1.7 de/het card.** `div.card.no-flip`, card-tag left span `T('article')`.
Before answering: `.prompt-lbl` = `T('de or het?')`, `.word-nl` with the word + speaker,
then `div.dehet-btns` (`display:flex; gap:12px; margin-top:18px`) holding two
`button.dehet-btn` (`flex:1; padding:18px 0; border:var(--rule); var(--font-head) weight 900
22px; text-transform:lowercase`; `:active` scales to .96) labelled literally **de** and
**het**. Actions row: `↷ T('Skip')`.
After answering: the word line becomes `<span class="dehet-answer">de|het</span> word` (the
article coloured `var(--blue)`), the meaning is shown when available, and a `.result` box
reads `✓ T('Correct!')` or `✗ T('It is “{a}”')` with the correct article. Action row: one
button `T('Next') →`, which marks **`learning`** when correct (the user only proved the
gender) and **`again`** when wrong.

**2.1.8 Locked card (Free plan, `isLocked(e)` true).** The whole card gets `.pro-lock`
(`position:relative`); the body gets `.locked-blur` (`filter:blur(5px); opacity:.6;
user-select:none; pointer-events:none`) and contains only the word, the rank line and the
standard hint. `proOverlay()` is appended. The only action is `↷ T('Skip')`. There is **no
flip handler in any mode** when locked.

`proOverlay()` markup — `div.pro-overlay`: `position:absolute; inset:0; z-index:5;
display:flex; flex-direction:column; align-items:center; justify-content:center; gap:9px;
text-align:center; padding:22px; cursor:pointer; background:rgba(255,255,255,.6)`
(Midnight `rgba(13,14,21,.6)`, Sepia `rgba(243,234,214,.64)`). Children:
`.pro-lockico` 🔒 at 34px · `.pro-msg` = `T('Locked')` (`var(--font-head)` weight 900 15px
uppercase letter-spacing 2px) · `.pro-sub` = `T('Unlock Pro version for full access')`
(13px, `var(--muted)`, `max-width:250px`) · `button.pro-cta` = `T('Unlock Pro to go') →`
(`padding:11px 18px; background:var(--red); color:#fff; var(--font-head) weight 800
uppercase letter-spacing 1px`). Clicking anywhere on the overlay calls `openPro(event)`.

**2.1.9 Footer lines below the card.** All are `div.deckinfo` (12px, `var(--muted)`,
`margin-top:10px`, centred):
1. Always: `T('Card {a} of {b} in this round · {c} words in deck')` with a = `qPos+1`,
   b = `queue.length`, c = `deck.length`.
2. Only when a study plan exists: `T('Today: {n} learned · streak {s}')` 🔥, where n is
   `<b>todayCount()</b>` optionally followed by ` / perDay`, and s is `<b>currentStreak()</b>`.
3. Only when `dueCount() > 0`: `↻ T('{n} due for review')`.

**2.1.10 Empty state.** When `queue.length === 0`, `#learnBody` shows a single
`div.empty` (`border:var(--rule); padding:32px 20px; text-align:center; font-size:14px;
color:var(--muted)`) containing one of three messages plus `<br>` plus `T('Try “All”.')`:

| Condition | Message |
|---|---|
| `leechOnly` | `T('No tricky words yet — keep going!')` |
| `newOnly` | `T('No new words left — turn off “New words only” to review.')` |
| otherwise | `T('No words available for this mode with these filters.')` |

**2.1.11 Other states.** *Loading:* none — the deck is synchronous and in-file; the first
paint already has a card. *Offline:* identical to online; nothing on this screen makes a
network request. *Error:* the only possible toast here is
`T('Card preparation failed — check your API key in Progress')` from the dormant AI
enrichment path (§9.3).

---

### 2.2 Screen — WORDS, list view (`tab === 'words'`, `wordView === null`)

**2.2.1 Purpose.** Search and browse the entire deck; entry point to word detail cards.

**2.2.2 Layout order.**
1. `<input type="search" id="wordSearch">` — `width:100%; padding:11px 12px;
   border:var(--rule); font-family:var(--font-body); font-size:14px; margin-bottom:12px;
   outline:none`. Placeholder `T('Search Dutch or English…')`, `autocomplete="off"`, value
   pre-filled from the `search` variable.
2. `div.filterbar` with three dropdowns in order: **Status** (`wstatus`), **Source**
   (`wsrc`, only when `srcFilterOpts().length > 2`), **Word type** (`wpos`).
3. `div.wlist#wlist` — the rows.
4. `div#wmore` — the "show more" button or the result count.

**2.2.3 Row markup (unlocked).** `div.wrow` — `border:2px solid var(--line);
border-bottom:none; padding:10px 12px; display:flex; align-items:center;
justify-content:space-between; gap:10px; cursor:pointer`. The last row in `.wlist` gets
`border-bottom:2px solid var(--line)`.
- Left column, line 1 (`div.nl`, `var(--font-head)` weight 700 15px): optional article
  (`de ` / `het `), the Dutch word, an optional `span.wpos` part-of-speech pill
  (`var(--font-body)` weight 500 9px uppercase letter-spacing 1px, `color:var(--muted2)`,
  `border:1px solid var(--faint)`, `padding:1px 5px`), zero or more source badges, and the
  speaker button.
- Left column, line 2 (`div.en`, 13px, `var(--muted)`): the translated meaning, or
  `T('tap to open')` for a textbook word with no meaning, or `#<rank> · T('tap to open')`
  for a frequency stub with no meaning.
- Right: `div.dot` — 14×14px, `border:2px solid var(--line)`, `flex-shrink:0`;
  `.learned` blue, `.learning` yellow, `.new` white (Midnight `#2a2d42`).
  `title` = `T(status)`.

**Source badge** (`span.srcbadge.sb-<src>`) — `display:inline-block; var(--font-head)
weight 900; font-size:9px; min-width:15px; height:15px; line-height:15px; padding:0 3px;
box-sizing:border-box; text-align:center; margin-left:4px; vertical-align:middle;
color:#fff`. Badges are emitted for every `srcTag` **except `general`**:

| srcTag | Badge glyph | Class background |
|---|---|---|
| `essential` | `&#9733;` ★ | `.sb-essential` = `var(--purple)` |
| `gang` | `A2` | `.sb-gang` = `var(--blue)` |
| `actie` | `B1` | `.sb-actie` = `var(--red)` |
| `niveau` | `B2` | `.sb-niveau` = `var(--yellow)`, text `#111` |
| `perfectie` | `C1` | `.sb-perfectie` = `var(--green)` |
| anything else | `?` | — |

**2.2.4 Row markup (locked, Free plan).** `div.wrow.locked-row`. The whole left column is
wrapped in `.locked-blur` (which also gets `flex:1`) and the right slot becomes
`div.pro-mini` 🔒 (16px, `opacity:.8`, `title = T('Locked')`). No speaker button, no status
dot. Tapping the row calls `openPro(event)` instead of opening the word.

**2.2.5 Footer (`#wmore`).**
- If `list.length > listLimit`: `button.loadmore` reading
  `T('Show more ({n} remaining)')`, n = `list.length − listLimit`. Tapping adds **300** to
  `listLimit` and re-renders only the list. `.loadmore` = `width:100%; padding:12px;
  margin-top:10px; background:var(--paper); border:var(--rule); var(--font-head) weight 700
  uppercase letter-spacing 1px`.
- Otherwise: `div.deckinfo` reading `T('1 word')` when exactly one result, else
  `T('{n} words')`.

**2.2.6 States.**

| State | Rendering |
|---|---|
| Default | First `listLimit = 100` matching rows (free-first ordering applied for Free users) |
| Empty | `#wlist` contains a single `div.empty` reading `T('No words match.')` |
| Loading | None. The deck is in-memory; filtering is synchronous |
| Error | None on this screen |
| Offline | Identical. Note: when a non-English language is active and its content pack has not loaded, meanings render in English |

**2.2.7 Critical interaction rule.** Typing in the search box **must never** re-render
`#main`. `inp.oninput` sets `search`, resets `listLimit` to 100 and calls `renderWordList()`,
which writes only `#wlist` and `#wmore`. Re-rendering `#main` destroys the input and
dismisses the mobile keyboard.

---

### 2.3 Screen — WORDS, detail card (`tab === 'words'`, `wordView !== null`)

**2.3.1 Purpose.** Full information for one word, plus status grading and navigation to
related words.

**2.3.2 Layout order.**
1. `button.loadmore` with inline `margin-top:0; margin-bottom:14px`, label
   `← T('Back')` when `wordViewStack` is non-empty **or** the chain was entered from a Learn
   card, else `← T('Back to list')`.
2. `div.card` with a `.card-tag` (left: `T(e.t || 'word')` + optional ` · de|het`;
   right: `T(status).toUpperCase()`).
3. `div.card-body` containing:
   - `div.word-nl` — the Dutch headword (`var(--font-head)` weight 900, **44px**,
     letter-spacing −1px, line-height 1, `word-break:break-word`) plus a 34×34px speaker button.
   - `div.word-en` — the translated meaning (20px, weight 600, `var(--blue)`).
   - `div.rankline` — 11px, letter-spacing 1px, uppercase, `var(--muted2)`, margin-top 2px.
     Content: `T('#{n} most frequent')` when the word has a frequency rank; else
     `T('textbook word')` when it belongs to a book; else `T('curated extra')`.
   - `div.rankline.booktag` (red, weight 600, letter-spacing 0.5px) — 📚 plus `bookTag(e)`,
     shown only for textbook words.
   - Forms section, Examples section, Synonyms section, Antonyms section (§2.3.3).
   - A trailing `.word-hint` reading `T('More examples and grammar forms are being added.')`
     when the entry has a meaning but is not rich and has no examples.
4. `div.actions` with the same three grade buttons as the Learn card
   (`✗ Again` / `≈ Learning` / `✓ Know it`), calling `setWordStatus(idx, …)`. Unlike the
   Learn card, grading here **stays on the detail card**.

**2.3.3 Sub-sections inside the card body.** Each is a `div.section` —
`margin-top:16px; border-top:2px solid var(--line); padding-top:10px; text-align:left` —
introduced by `div.sec-h` (`var(--font-head)` weight 700 11px uppercase letter-spacing 1.5px,
`var(--muted)`, `margin-bottom:8px`).

- **Forms** — heading `T('Forms')`. One `div.frow` per pair (13px, line-height 1.7); the
  label is `<b>` with `font-weight:600; display:inline-block; min-width:96px;
  color:var(--muted)` and is passed through `T()`. Known labels in the data: `Present`,
  `Past`, `Past sg/pl`, `Perfect`, `Plural`, `Diminutive`, `Comparative`, `Superlative`,
  `Feminine`, `Object`, `Possessive`, `Stressed`, `Informal`, `Formal`, `Note`, `Forms`.
- **Examples** — heading `T('Examples')`. One `div.sentence` per example —
  `margin-top:10px; padding-left:10px; border-left:4px solid var(--yellow); font-size:14px;
  line-height:1.5`. Inside: `span.sen-nl` with the Dutch sentence plus a 22×22px
  `button.spk.spk-ex` (title/aria-label `T('Hear this sentence')`), then `<em>` with the
  translated English (`display:block; font-style:normal; color:var(--muted);
  font-size:12.5px`).
- **Synonyms** / **Antonyms** — headings `T('Synonyms')` / `T('Antonyms')`. One `div.rel`
  per word — `display:flex; align-items:center; gap:8px; padding:8px 10px;
  border:2px solid var(--line); margin-bottom:6px; cursor:pointer; background:var(--paper)`,
  plus `.rel-syn` (`border-left:6px solid var(--blue)`) or `.rel-ant`
  (`border-left:6px solid var(--yellow)`). Contents: `span.rel-w` (`var(--font-head)`
  weight 700 14px, `white-space:nowrap`) showing `= word` (synonym) or `≠ word` (antonym,
  `&#8800;`), `span.rel-m` (`flex:1`, 12.5px, `var(--muted)`) with the related word's
  meaning when known, and `span.rel-go` (`var(--font-head)` weight 900 18px, `var(--red)`)
  showing `›`. When the related word is **not** in the deck the row gets `.rel-plain`
  (`cursor:default; opacity:0.85`) and the `›` chevron is hidden.

**2.3.4 Alternative bodies.**
- `enrichInFlight` and the word is neither rich nor has a meaning: body is
  `.word-en` = `T('Preparing…')` + rank line + book line.
- Neither rich nor meaning and not in flight: `.word-en` = `T('Not translated yet')` +
  rank line + book line + `.word-hint` (margin-top 12px) =
  `T('Meaning will be added when you add an API key, or from the app online.')`.

**2.3.5 Locked detail (Free plan).** Back button, then `div.card.pro-lock` whose
`.card-body.locked-blur` contains only the word and the standard reveal hint, with
`proOverlay()` on top. No grade buttons.

**2.3.6 Back behaviour.** See §7.11 — Back restores the Words-list scroll position, or
returns to the Learn card when the chain started from a flashcard.

---

### 2.4 Screen — PROGRESS (`tab === 'progress'`)

**2.4.1 Purpose.** Show real progress only: counts, review queue, hardest words, activity
history, and two breakdown charts. It contains **no configuration** — goal and plan setup
live on the Profile page.

**2.4.2 Layout order (top to bottom).**

1. **Progress strip** — `mondrianStrip(counts())`.
2. **Stat tiles** — `div.stats`: `display:grid; grid-template-columns:1fr 1fr;
   border:var(--rule)`. Each `div.stat`: `padding:18px 14px;
   border-right:3px solid var(--line); border-bottom:3px solid var(--line)`; every 2nd
   child drops the right border, the last two drop the bottom border. Inside:
   `div.num` (`var(--font-head)` weight 900, **34px**, line-height 1) and `div.lbl`
   (10px uppercase letter-spacing 1.5px `var(--muted)` margin-top 6px).

   | # | Value | Colour class | Label |
   |---|---|---|---|
   | 1 | `counts().learned` | `.c-blue` (`var(--blue)`) | `T('Learned')` |
   | 2 | `counts().learning` | `.c-yellow` (`#b89200`; Midnight `var(--yellow)`) | `T('Still learning')` |
   | 3 | `counts().fresh` | none | `T('Not started')` |
   | 4 | `pct + '%'` | `.c-red` (`var(--red)`) | `T('Of {goal} goal')` |

   `pct = min(100, goalLearned/goalTotal*100).toFixed(1)` — one decimal place, always.
3. **Streak card** — `div.genbox` with `<h3>` = 🔥 `T('Streak')`, then `div.daily-head`
   (`display:flex; justify-content:space-between; align-items:center; margin:6px 0 10px`)
   containing on the left `div.daily-num` (`var(--font-head)` weight 900 **36px**) with
   today's word count and `div.lbl` = `T('words today')`, and on the right
   `div.streak-badge` (`var(--font-head)` weight 900 26px, right-aligned) = 🔥 + streak
   number with a `<small>` (`display:block`, `var(--font-body)` weight 400 9px uppercase
   letter-spacing 1px `var(--muted)`) reading `T('day streak')`.
4. **Review box** — `div.genbox.review-box` (`border-width:3px`), `<h3>` = ↻ `T('Review')`.
   - When `dueCount() > 0`: a `.daily-head` with `.daily-num.c-red` showing the count and
     `.lbl` = `T('due for review')`; a paragraph
     `T('Words you’ve started that are scheduled to come back today. Reviewing on time is what moves them into long-term memory.')`;
     and `button.genbtn` (margin-top 4px) reading `↻ T('Start review')`.
   - When 0 due: a single paragraph
     `T('All caught up — nothing due right now. Words you learn come back on a spaced schedule so you review them right before you’d forget.')`.
   - This box is **never Pro-gated**.
5. **Hardest words box** — rendered **only when `leeches().length > 0`**. `div.genbox`,
   `<h3>` = 🔥 `T('Hardest words')`. Then `div.leechlist` with up to **8** `div.leechrow`
   (`display:flex; align-items:center; gap:8px; padding:8px 0;
   border-bottom:1px solid var(--faint); cursor:pointer`; last row no border): `span.leech-w`
   (`var(--font-head)` weight 700 14px) with optional article + word, `span.leech-m`
   (`flex:1`, 12px, `var(--muted)`, ellipsised) with the meaning, and `span.leech-x`
   (12px weight 700 `var(--red)`, `title = T('times missed')`) reading `✗<lapses>`.
   Tapping a row opens that word's detail card. Then `div.note` (11.5px, `var(--muted)`,
   margin-top 10px, line-height 1.5) =
   `T('Words you keep missing. Drill them to lock them in.')` and `button.genbtn`
   (margin-top 10px) = 🔥 `T('Drill hardest words')`. **Never Pro-gated.**
6. **Last 14 days** — `div.genbox`, `<h3>` = `T('Last 14 days')`, then `div.histgrid`
   (`display:grid; grid-template-columns:repeat(14,1fr); gap:4px`) of 14 `div.histcell`
   (`aspect-ratio:1; border:2px solid var(--line)`), oldest (13 days ago) first, today last.
   Level thresholds by that day's learned count n: `lvl0` n = 0 (paper),
   `lvl1` 1 ≤ n < 5 (`#bcd`; Midnight `#26406e`), `lvl2` 5 ≤ n < 10 (`#6b9`; Midnight
   `#3a63b0`), `lvl3` n ≥ 10 (`var(--blue)`). Each cell's `title` is
   `"YYYY-MM-DD: <n> word(s)"`. Then `div.note` =
   `T('Each square is a day; darker means more words learned. Learn at least one word a day to keep your streak alive.')`.
7. **By word type** — `div.genbox` (plus `.pro-lock` when Free), `<h3>` = `T('By word type')`.
   `div.posbreak` (`display:flex; flex-direction:column; gap:8px`; plus `.locked-blur` when
   Free) with one `div.posrow` per part of speech present, in the fixed order
   `verb, noun, adjective, adverb, pronoun, preposition, conjunction, number, expression,
   article`. Each row: `span.posname` (`flex:0 0 96px`, 13px weight 600) with
   `T(POS_LABELS[p])`, `span.posbar` (`flex:1; height:12px; border:2px solid var(--line);
   background:var(--paper); display:flex`) holding one `span.posbar-fill`
   (`flex:0 0 auto; height:100%`) per source present, width
   `bySrc[s]/total*100` percent (unrounded) and `background:var(<SRC_COLORVAR[s]>)`, with
   `title` = `"<SRC_SHORT[s]>: <count>"`; and `span.poscount` (`var(--font-head)` weight 700
   12px `var(--muted)`) reading `learned/total`. Tapping a row sets `posFilter=[p]` and
   switches to the Words tab. Then `div.note` =
   `T('Tap a type to study or browse just those words.')`, and `proOverlay()` when Free.
8. **By source** — `div.genbox` (plus `.pro-lock` when Free), `<h3>` = `T('By source')`.
   `div.srcbreak` (`display:flex; align-items:center; gap:18px; flex-wrap:wrap`; plus
   `.locked-blur` when Free) containing:
   - `div.srcdonut-wrap` with `svg.srcdonut` — 140×140px, `viewBox="0 0 140 140"`,
     `role="img"`, `aria-label = T('By source')`. Geometry constants: **R = 52, stroke-width
     SW = 22, centre CX = CY = 70, circumference = 2πR ≈ 326.7256**. Segments sit inside
     `<g transform="rotate(-90 70 70)">`; each is a `<circle class="donut-seg" fill="none"
     stroke="var(<colour>)" stroke-width="22" stroke-linecap="butt">` with
     `stroke-dasharray = "max(len−2,0) <CIRC>"` (the −2 creates a 2px gap between slices)
     and `stroke-dashoffset = −(cumulative length so far)`, where
     `len = learned_s / totalLearned * CIRC`. Each carries a `<title>` of
     `"<SRC_SHORT[s]>: <learned> (<share>%)"` with share rounded to a whole number.
     Centre labels: `text.donut-num` at (70, 69) — `var(--font-head)` weight 900 30px,
     `fill:var(--ink)`, `text-anchor:middle` — with the summed learned total; and
     `text.donut-lbl` at (70, 86) — `var(--font-head)` weight 700 11px uppercase
     letter-spacing .5px, `fill:var(--muted)` — reading `T('Learned')`.
     **Empty state:** when nothing is learned, a single full ring
     `<circle r="52" stroke="var(--faint)" stroke-width="22">` and a centre number of `0`.
   - `div.srclegend` (`flex:1 1 190px; min-width:190px; display:flex;
     flex-direction:column; gap:8px`) with one `div.srcrow` per source: `span.srcdot`
     (12×12px, `border:2px solid var(--line)`, filled with the source colour),
     `span.srcname` (`flex:0 0 64px`, 13px weight 600) = `SRC_SHORT[s]`, a single-segment
     `.posbar` at `round(learned/total*100)`%, and `span.poscount` = `learned/total`.
   Tapping a slice **or** a legend row sets `srcFilter=[s]`, `posFilter=[]` and switches to
   the Words tab. Then `div.note` = `T('Tap a source to study or browse just those words.')`,
   and `proOverlay()` when Free.

**2.4.3 States.** *Empty (nothing learned):* stat tiles read 0/0/deck.length/0.0%, the
strip is all-white, the history grid is 14 `lvl0` cells, the donut is the faint empty ring,
the Hardest-words box is absent, and the Review box shows the "All caught up" copy.
*Loading / error / offline:* none — everything is computed from local state.

---

### 2.5 Screen — PROFILE (`tab === 'profile'`)

Reached only by the header avatar button. Wrapped in `div.profile-page`.

**2.5.1 Title.** `h2.pf-title` — `var(--font-head)` weight 900 22px, `margin:4px 0 0` —
reading `T('Profile')`.

**2.5.2 Account card, signed OUT.** `div.genbox.profile-signin` (`text-align:center`):
- `div.pf-avatar.guest` — 52×52px circle, `background:var(--grey)`, `color:var(--muted)`,
  `margin:0 auto 6px`, font-size 26px, glyph 👤.
- `<h3 style="text-align:center">` = `T('Save your progress')`.
- `<p style="text-align:center">` = `T('Create an account or log in so your progress and Pro plan live in your account — not just on this device.')`.
- `div.auth-actions` (`display:flex; flex-direction:column; gap:10px; margin-top:14px`):
  1. `button.gsi-btn` — `display:flex; align-items:center; justify-content:center; gap:10px;
     padding:12px; background:var(--card-bg); color:var(--ink); border:2px solid var(--line);
     var(--font-head) weight 700 14px`. Contains `span.gsi-g` (22×22px white circle,
     `color:#4285F4`, Arial weight 800 14px, `border:1px solid var(--line)`) holding the
     letter **G**, then `T('Continue with Google')`. Gets `.active` (blue border) when its
     form is open.
  2. The Google form, when `authMode === 'google'`.
  3. `button.auth-alt` (`padding:11px; background:transparent; border:2px solid var(--line);
     weight 600 13px`) = `T('Sign up with email')`.
  4. The signup form, when `authMode === 'signup'`.
  5. `button.auth-alt.ghost` (`border-style:dashed; color:var(--muted)`) =
     `T('I already have an account')`.
  6. The login form, when `authMode === 'login'`.

  Each `div.auth-form` is `display:flex; flex-direction:column; gap:10px; text-align:left;
  padding:4px 0 2px`. Inputs are `.cf-input` (`width:100%; padding:11px 12px;
  border:2px solid var(--line); background:var(--card-bg); color:var(--ink);
  font-size:15px`; focus → `box-shadow:inset 0 0 0 2px var(--accent, var(--blue))`;
  `.cf-err` → `box-shadow:inset 0 0 0 2px var(--red)`). Each form has a
  `div#authHint.cf-hint.cf-err-msg` (12px, `var(--red)`, hidden while empty) and a
  `button.genbtn`. Enter submits in every form.

  | Form | Fields (in order) | Submit label |
  |---|---|---|
  | google | `#authEmail` placeholder `T('Your Google email')` | `T('Continue') →`, followed by `div.note` = `T('Demo Google sign-in — real Google login is coming soon.')` |
  | signup | `#authName` placeholder `T('Your name')` (autocomplete `name`), `#authEmail` placeholder `T('Email address')` | `T('Create account')` |
  | login | `#authEmail` placeholder `T('Email address')` | `T('Log in')` |

**2.5.3 Account card, signed IN.** Two boxes:
- `div.genbox.profile-head` (`display:flex; align-items:center; gap:14px`):
  `div.pf-avatar` (52×52px circle, `background:var(--blue)`, white text,
  `var(--font-head)` weight 800 20px) with up to 2 uppercase initials — plus `.is-pro`
  (yellow bg, `#111` text, `border:2px solid var(--ink)`) when Pro; then `div.pf-id`
  containing `div.pf-name` (`var(--font-head)` weight 800 18px), `div.pf-email` (13px,
  `var(--muted)`, `word-break:break-all`) and `div.pf-meta` (11px, letter-spacing .5px,
  `var(--muted2)`, margin-top 3px) reading `T('Signed in with {p}') · T('Member since {d}')`
  where `{p}` is the literal `Google` or `T('Email')` and `{d}` is the account creation date
  formatted `{year:'numeric', month:'short'}` in the active locale.
- `div.genbox` with two `div.pf-row`s (`display:flex; justify-content:space-between;
  align-items:center; padding:8px 0; border-bottom:1px solid var(--line); font-size:14px`;
  last row no border): `T('Plan')` → `👑 T('Pro')` (with `.c-blue`) or `T('Free')`; and
  `T('Words learned')` → the learned count. Then `div.note` (margin-top 6px) =
  `T('Your progress is saved to your account. Cloud sync across devices is coming soon; for now it is stored on this device.')`,
  and `button.loadmore` (margin-top 12px) = `T('Sign out')`.

**2.5.4 Pro card.** `div.genbox.probox` (`border:var(--rule)`).
- Not Pro: `div.pro-h` (`display:flex; align-items:center; gap:8px; var(--font-head) 17px
  weight 900 uppercase letter-spacing 1px`) with `span.pro-crown` 👑 (20px) and
  `<b>T('Pro to go')</b>`; `<p>` (margin-top 8px, 13px, `var(--muted)`) =
  `T('Go Pro for full access to every word across all levels, the complete word list and all progress stats.')`;
  `button.pro-cta.wide` (`width:100%; margin-top:10px`) reading `T('Get Pro') →` when signed
  in or `T('Sign in to get Pro') →` when a guest; and, for guests only, a centred
  `div.note` = `T('Pro is tied to your account, so it follows you when sync arrives.')`.
- Pro: `div.genbox.probox.pro-on` with the same `.pro-h` plus `span.pro-chk`
  (`margin-left:auto; font-size:12px; letter-spacing:1px; color:var(--blue)`) reading
  `✓ T('Active')`; `<p>` = `T('You have full access to every word, list and stat.')`; and
  `button.pro-restore` (`margin-top:10px; padding:8px 12px; background:transparent;
  border:2px solid var(--line); font-size:12px; uppercase; letter-spacing:1px`) reading
  `T('Switch back to Free (test)')`.

**2.5.5 Learning goal box** (`goalBoxHtml`). `div.genbox.goal-box`:
- `<h3>` = 🎯 `T('Learning goal')`.
- `<p>` = `T('Set a target — a number of words, or specific sources to finish. Your progress percentage and daily plan are measured against it.')`.
- `div.daily-num` (margin-bottom 10px) = `goalLearned` `<span>/ goalTotal</span>`
  (the `<span>` is 18px `var(--muted2)`), both locale-formatted.
- **Mode toggle** — `div.chiprow.srcchips` (`display:flex; gap:8px; flex-wrap:wrap;
  margin-bottom:14px`) with two `button.planchip.srcchip`: `T('By word count')` and
  `T('By source')`. The active one gets `.active` (`background:var(--blue); color:#fff`).
  `.planchip` base = `flex:1; min-width:48px; padding:12px 10px; border:var(--rule);
  background:var(--paper); var(--font-head) weight 900 15px; line-height:1.15;
  text-align:center`; `:hover` → yellow background. `.srcchip` overrides to
  `flex:0 1 auto; min-width:0; padding:12px 16px; font-size:14px; font-weight:800;
  letter-spacing:0.2px; white-space:nowrap`.
- **Count mode body:** `<label>` (`display:block; 12px; weight 600; uppercase;
  letter-spacing 0.5px; color:var(--muted); margin-bottom:6px`) = `T('Words to learn')`;
  then `div.chiprow.onerow` (`flex-wrap:nowrap`, chips uppercased) with the presets
  **500, 1000, 3000, 5000** (each filtered out if ≥ `deck.length`) rendered compactly as
  `500`, `1K`, `3K`, `5K`, plus a final chip `T('All')` which is active whenever no custom
  goal is set. Then `<label style="margin-top:12px">` = `T('Or enter an exact number')`;
  `<input type="number" id="goalInput" min="1" max="<deck.length>" value="<goalTotal()>"
  inputmode="numeric">` (Enter submits); `button.genbtn` (margin-top 10px) = `T('Set goal')`;
  and, only when a custom goal is set, `button.loadmore` (margin-top 8px) =
  `T('Learn all {n} words')` with the locale-formatted deck size.
- **Source mode body:** `<label>` = `T('Learn every word from the sources you choose')`;
  `div.chiprow.srcchips` with one `button.planchip.srcchip` per available source, labelled
  with `SRC_SHORT` (Essential, General, A0–A2, A2–B1, B1–B2, B2–C1), toggling in and out of
  `goalSources`; then a `p.note` (margin-top 10px) reading
  `T('Goal: learn all {n} words in the selected {c} source(s).')` when at least one source
  is picked, else `T('Pick one or more sources above to set your goal.')`.

**2.5.6 Study plan box** (`studyPlanHtml`). `div.genbox.plan-box` (`border-width:3px`),
`<h3>` = 📅 `T('Study plan')`.
- **No plan set:** `<p>` = `T('Pick how many words to learn per day (or a target date), and the app tracks your streak and shows exactly how many to do each day.')`;
  `div.plan-form` with `<label>` = `T('Words per day')`; `div.chiprow` of five
  `button.planchip` labelled **5, 10, 15, 20, 30**; `<label style="margin-top:12px">` =
  `T('Or reach {goal} by a date')`; `<input type="date" id="planDate" min="<today>">`; and
  `button.genbtn` (margin-top 10px) = `T('Set target date')`, which toasts
  `T('Pick a date or tap a number above')` when the date field is empty.
- **Plan set:** `div.daily-head` with `div.daily-num` = `<done> <span>/ <goalN></span>` and
  `div.lbl` = `T('words today')`; `div.progbar` (`height:14px;
  border:2px solid var(--line); background:var(--paper)`) with a `div.progbar-fill`
  (`height:100%; background:var(--blue); transition:width .3s`) at
  `min(100, round(done/goalN*100))`%; a `<p style="margin-top:12px">` with the ETA line;
  then either `div.keyok` (12px weight 600 `var(--blue)`, margin-top 8px) reading
  `✓ T('Daily goal complete — nice work!')` when `done ≥ goalN`, or `button.genbtn`
  (margin-top 10px) reading `T('Study now') →`; then `div.rowbtns`
  (`display:flex; gap:10px; margin-top:10px`; buttons `flex:1; padding:12px;
  border:var(--rule); var(--font-head) weight 700 12px uppercase letter-spacing 0.5px`)
  with `T('Edit plan')` and `T('Remove')`.

  ETA line, per-day plan: `T("At {n}/day you'll reach {goal} in about {d} days (~{date}).")`.
  ETA line, target-date plan (this **overwrites** the per-day line when `plan.endDate` is
  set): `T('To hit {goal} by {date}, learn about {n}/day ({d} days left).')`.
  Date format for both: `{month:'short', day:'numeric', year:'numeric'}` for the per-day
  ETA and `{month:'short', day:'numeric'}` for the target date, in the active locale.
- **Reminder block** — rendered only when `'Notification' in window`, always shown
  (independent of whether a plan exists). `div.plan-remind`
  (`margin-top:16px; padding-top:14px; border-top:1px solid var(--line)`; its `.loadmore`
  gets `margin-top:0`):
  - `button.loadmore` reading `🔔 T('Turn on daily reminders')` when off, or
    `✓ T('Daily reminders on')` when on. It is a **true toggle** — tapping while on turns
    reminders off.
  - Only when on: `div.remind-time` (`display:flex; align-items:center; gap:10px;
    margin-top:10px`) with a `<label>` (12px weight 600 uppercase letter-spacing 1px
    `var(--muted)`) reading `T('Reminder time')` and an `<input type="time">`
    (`width:auto; margin:0; padding:7px 10px`) bound to `remindTime`.
  - Only when on: `div.note` reading `T('Times are in your device timezone ({tz}).')` —
    with `{tz}` from `Intl.DateTimeFormat().resolvedOptions().timeZone`, omitted entirely if
    that throws — followed by a space and
    `T('Reminders fire while the app is open in your browser; keep the tab around to be nudged.')`.

**2.5.7 Order on the page:** title → account card → Pro card → Learning goal → Study plan.

**2.5.8 Error states.** Inline only: `#authHint` shows the email-validation message
(§7.12) or `T('No account found for that email — sign up instead.')`, and the offending
input gets `.cf-err`.

---

### 2.6 Modal — SETTINGS DRAWER

**2.6.1 Structure.** Two `<body>`-level siblings, deliberately **outside** `.topbar` and
`#main` (the drawer's own `transform` would otherwise trap Midnight's `position:fixed` nav,
and `#main` re-renders must never touch the drawer):
- `div.scrim#scrim` — `position:fixed; inset:0; background:rgba(0,0,0,.45); z-index:58;
  opacity:0; pointer-events:none; transition:opacity .25s`. `.show` → opacity 1 +
  `pointer-events:auto`. Midnight override: `rgba(0,0,0,.6)`.
- `aside.drawer#drawer` — `position:fixed; top:0; bottom:0; left:0; z-index:60;
  width:min(340px, 88vw); background:var(--paper); border-right:var(--rule);
  padding:16px 16px 32px; overflow-y:auto; transform:translateX(-105%);
  visibility:hidden; transition:transform .28s ease, visibility 0s linear .28s`.
  `.open` → `transform:none; visibility:visible; transition:transform .28s ease`.
  `aria-hidden` is kept in sync.

Z-order: drawer 60 > scrim 58 > Midnight's floating nav 50 > topbar/nav 20. The scrim must
cover the pill nav.

**2.6.2 Header.** `div.drawer-head` (`display:flex; justify-content:space-between; gap:12px;
border-bottom:var(--rule); padding-bottom:12px`): `div.drawer-title#drawerTitle`
(`var(--font-head)` weight 900 18px uppercase letter-spacing 1px) whose text is set to
`T('Menu')` on every open — so it renders as **MENU**; and `button.drawer-close#drawerClose`
(36×36px, `border:var(--rule)`, 15px, `aria-label = T('Close')`) showing ✕ (`&#10005;`).

**2.6.3 Body (`#drawerBody`), rebuilt on every open.** Five blocks in fixed order:

1. **Pro to go box** (`proBox()`) — always first, **not** an accordion.
   - Free: `div.genbox.probox` with `role="button" tabindex="0"`, the whole box clickable
     (`unlockPro()`). Contents: `.pro-h` (👑 + `T('Pro to go')`), `<p>` =
     `T('The free version unlocks a limited set of words. Go Pro for full access to every word across all levels, the complete word list and all progress stats.')`,
     and `button.pro-cta.wide` = `T('Unlock Pro to go')`.
   - Pro: `div.genbox.probox.pro-on` with `.pro-h` + `.pro-chk` `✓ T('Unlocked')`, `<p>` =
     `T('You have full access to every word, list and stat.')`, and `button.pro-restore` =
     `T('Switch back to Free (test)')`.
   - `.probox.flash` runs `@keyframes proflash` for **1.4 s ease** — `box-shadow:0 0 0 3px
     var(--red)` between 30 % and 60 % of the animation, none at 0 % and 100 %.
2. **About the app** (accordion id `about`).
3. **App language** (accordion id `lang`).
4. **Theme** (accordion id `theme`).
5. **Contact us** (accordion id `contact`).

**2.6.4 Accordion mechanics (`menuBox`).** `div.genbox.accbox` (`padding:0;
overflow:hidden`), gaining `.open` when expanded. Header: `button.acc-h` —
`width:100%; display:flex; justify-content:space-between; gap:12px; padding:16px;
background:transparent; border:none; text-align:left; var(--font-head) weight 900 16px
uppercase letter-spacing 0.5px; color:var(--ink)` — with `aria-expanded` and a
`span.acc-arrow` `›` (`&#8250;`, 22px, `var(--muted)`, `transition:transform .25s ease`,
rotated 90° when open). Body: `div.acc-body` — `max-height:0; overflow:hidden;
padding:0 16px; transition:max-height .28s ease, padding .28s ease`; when open,
`max-height:1200px; padding-bottom:16px`.

**All sections start collapsed, and only one may be open at a time**: tapping a header
collapses every section first, then opens the tapped one (tapping an already-open header
just closes it). Open state lives in the module-level object
`menuSections = {about:false, lang:false, theme:false, contact:false}` so it survives the
`renderMenu()` re-runs fired by a theme or language switch.

**2.6.5 About body.** A sequence of `<p>`s (13px, `var(--muted)`, `margin:8px 0 12px`,
line-height 1.5; the later ones with inline `margin-top:6px`):
1. `T('Build your Dutch vocabulary in a structured way. This one-stop app shows all the details of a word — meaning, example sentences, grammar forms and synonyms — so learners can pick it up in a practical way.')`
2. `T('The app has {n} common Dutch words, grouped by level:')` — n = `deck.length` (6,752).
3. ⭐ `<b>T('Essential')</b>: T('{n} core everyday words.')` — n = 1,484. Shown only when
   Essential words exist.
4. 📚 `<b>General</b>: T('{n} popular words.')` — n = 2,365. **`General` is a bare literal,
   never passed through `T()`.**
5. 📚 `<b>A0 → A2</b>: T('{n} words').` — n = 946. Shown only when that book is present.
6. 📚 `<b>A2 → B1</b>: T('{n} words').` — n = 1,214.
7. 📚 `<b>B1 → B2</b>: T('{n} words').` — n = 499.
8. 📚 `<b>B2 → C1</b>: T('{n} words').` — n = 368.

The CEFR range labels are literals sitting outside the translated string (language-neutral).

**2.6.6 App language body.** `div.themepick` (`display:flex; flex-wrap:wrap; gap:8px;
margin-top:4px`) of 11 `button.themebtn.langbtn` — `min-width:52px; justify-content:center;
padding:8px 12px; border:var(--rule); background:var(--card-bg); color:var(--ink);
var(--font-head) weight 800 13px letter-spacing 1px`. The visible content is the **two-letter
code only**; the full language name is in `aria-label` and `title`. Active chip:
`box-shadow:inset 0 0 0 3px var(--accent)`. Below the chips, `p.lang-note` (12px,
`var(--muted)`, margin-top 10px, line-height 1.4) =
`T('Some languages may not be fully translated. English is used where a translation is missing.')`.

| id | Code | Name |
|---|---|---|
| en | EN | English |
| fr | FR | Français |
| it | IT | Italiano |
| es | ES | Español |
| de | DE | Deutsch |
| pt | PT | Português |
| pl | PL | Polski |
| tr | TR | Türkçe |
| uk | UK | Українська |
| ru | RU | Русский |
| bg | BG | Български |

**2.6.7 Theme body.** `div.themepick` of three `button.themebtn` containing **only** a
`span.swatch` — `display:flex; width:44px; height:24px; border:2px solid var(--line);
border-radius:calc(var(--radius) * .5); overflow:hidden` — holding three equal-flex `<i>`
blocks. No text label; the theme name is in `aria-label` and `title`.

| id | Name | Swatches |
|---|---|---|
| `minimalistic` | Minimalistic | `#FFFFFF`, `#DD0100`, `#225095` |
| `midnight` | Midnight | `#0d0e15`, `#6c8cff`, `#ff6b81` |
| `sepia` | Sepia | `#f3ead6`, `#9c3b23`, `#3f6f6f` |

**2.6.8 Contact us body.** `div.contact-form` (`display:flex; flex-direction:column;
gap:10px`). Labels are `label.cf-label` (12px weight 700 `var(--muted)` letter-spacing .5px
`margin-bottom:-4px`). Fields are `.cf-input` (`width:100%; padding:9px 11px;
border:var(--rule); background:var(--card-bg); color:var(--ink); font-size:14px`;
focus → `box-shadow:inset 0 0 0 2px var(--accent)`; `.cf-err` → red inset shadow).

Order:
1. `T('Subject')` label + `<select id="cfSubject">` with six options, each label from
   `CONTACT_SUBJECTS` through `T()`. **The option `value` is the translated label**, and
   that value is what gets sent.
   `CONTACT_SUBJECTS = ['General feedback', 'Report a problem', 'Word or translation error',
   'Feature request', 'Question', 'Other']`.
2. `T('Your email (optional)')` label + `<input type="email" id="cfEmail" inputmode="email"
   autocomplete="email" autocapitalize="off" spellcheck="false">` with placeholder
   `T('you@example.com')`.
3. `div#cfEmailHint.cf-hint.cf-note` — normally `var(--muted)` text reading
   `T('Only if you would like a reply. We will use it just to get back to you.')`; on a
   validation failure it gains `.cf-err-msg` (red) and shows the error.
4. `div.cf-locktarget` (`display:flex; flex-direction:column`; gains `.pro-lock` when Free)
   wrapping `div.cf-lockwrap` (`display:flex; flex-direction:column; gap:10px`; gains
   `.locked-blur` when Free), which contains: `T('Message')` label; `<textarea
   id="cfMessage" class="cf-input">` (`resize:vertical; min-height:96px; line-height:1.4`)
   with placeholder `T('What would you like to tell us?')`; `div#cfHint.cf-hint` (12px,
   `var(--red)`); and `button.cf-send#cfSend` (`width:100%; margin-top:2px; padding:11px;
   border:var(--rule); background:var(--blue); color:#fff; var(--font-head) weight 800 15px
   letter-spacing .5px; uppercase`; `:active` scales .98; `:disabled` opacity .55) reading
   `T('Send')`. When Free, `proOverlay()` is appended inside `.cf-locktarget`.

**Gating rule:** the Subject dropdown and the optional email field stay fully usable in
Free mode; only the message textarea and Send are locked.

**2.6.9 Drawer states.**

| State | Behaviour |
|---|---|
| Sending | Send button disabled, text becomes `T('Sending…')` |
| Success | Message + email fields cleared, `#cfHint` cleared, toast `T('Thanks! Your message has been sent.')`, and the Contact accordion collapses |
| Validation — empty message | Textarea gains `.cf-err`, `#cfHint` = `T('Please enter a message before sending.')`, focus moves to the textarea, nothing is sent |
| Validation — bad email | Email input gains `.cf-err`, `#cfEmailHint` gains `.cf-err-msg` and shows the specific error, focus moves to the email input, nothing is sent |
| Network error | `#cfHint` = `T('Could not send right now. Please check your connection and try again.')` and toast `T('Could not send your message.')`; the button is re-enabled and its label restored |
| Free plan | `sendContact()` returns immediately and calls `openPro()` instead |
| Offline / `file://` | Delivery always fails (the form UI and validation still work) |

**2.6.10 Closing.** Three ways: the ✕ button, tapping the scrim, or pressing `Escape`.

---

### 2.7 Per-theme layout differences

These are not repaints — the same DOM renders as three different layouts.

| Aspect | Minimalistic (default) | Midnight | Sepia |
|---|---|---|---|
| Nav position | Top, sticky, filled active tab | **Fixed floating pill at the bottom** (`bottom:14px`, `left:50%`, `translateX(-50%)`, `width:min(440px,92vw)`, `border-radius:22px`, `background:#161829e6`, `box-shadow:0 14px 36px rgba(0,0,0,.55)`, `padding:6px`, `gap:6px`, `z-index:50`); `main` gets `padding-bottom:98px` | Centred running-head text tabs, `gap:24px`, `padding:4px 0`; active tab is `border-bottom:2px solid var(--accent)` + italic, no fill |
| Header | Rules, logo left, counter right | `border-bottom:none; padding:20px 18px 8px`; logo weight 800, 22px | **Centred title-page column** (`flex-direction:column; gap:3px; text-align:center; padding:22px 18px`); logo 26px weight 400 letter-spacing .5px; counter centred; hamburger is `position:absolute; left:16px; top:50%; translateY(-50%)` |
| Card | Boxed, `min-height:300px`, sharp | Big rounded card, radius 18px, `box-shadow:0 10px 30px rgba(0,0,0,.45)`; card-tag gets a blue gradient wash; `.word-nl` weight 800 | **Ruled entry**: no side borders, only `border-top`/`border-bottom: 2px solid var(--line)`, transparent background, `min-height:auto`, `padding:4px 0`; `.word-nl` is serif italic weight 400 **46px** letter-spacing 0; `.word-en` italic |
| Page width | `main` 640px | 640px | **`main` max-width 520px, `padding:24px 22px 60px`** |
| Background | Flat white | Two radial gradients over `#0d0e15`, `background-attachment:fixed`, replicated on `.topbar` | `repeating-linear-gradient(0deg, rgba(120,90,50,.028) 0 2px, transparent 2px 5px)` paper grain over `#f3ead6`, replicated on `.topbar` and the drawer |
| Word rows | Boxed rows | Boxed rows | `border:none; border-bottom:1px solid var(--line)` — dictionary-style |
| Drawer | Paper panel | Solid `#12141f` panel (deliberately **not** the ambient gradient) with `box-shadow:24px 0 60px rgba(0,0,0,.55)` | Paper-grain panel; title is italic serif 20px, not uppercase |
| Filter menu | `var(--card-bg)` | `var(--card-bg)` | Forced to opaque `var(--paper)` (Sepia's `--card-bg` is transparent, which would make the floating menu unreadable) |

In Sepia, the whole title-page header freezes when scrolling because the entire `.topbar`
is sticky. That is known and accepted.

---

## 3. DESIGN SYSTEM

### 3.1 Design language: Mondrian (the default theme)

The default theme is a deliberate De Stijl / Piet Mondrian pastiche. Reproduce these rules
literally:

1. **Only the three primaries plus black and white.** Red `#DD0100`, blue `#225095`,
   yellow `#FAC901`, ink `#111111`, paper `#FFFFFF`, plus a single off-white `#F2F2EF`.
   (Green `#0B7A3B` and purple `#6A2C91` were added later purely as data-series colours for
   the two newest sources; they appear only in badges, chart segments and legend dots —
   never as chrome.)
2. **Every border is a heavy black rule.** The token `--rule: 3px solid var(--line)` is used
   for card, nav, header, action-bar, input and button borders. Secondary structures use
   `2px solid var(--line)`. There are no light-grey dividers except `1px solid var(--faint)`
   inside list rows.
3. **Zero corner rounding.** `--radius: 0px`. The only circles in the design are functional
   (avatar, the 88px audio play button, the donut chart, the `.gsi-g` badge).
4. **Zero elevation.** `--shadow: none`. Depth comes from black rules only.
5. **Colour blocks are flat and full-bleed inside their rule.** The progress strip, the
   grade buttons, the status dots and the chart bars are solid unmodulated fills separated
   by 3px black rules — the Mondrian composition motif.
6. **Two typefaces, hard-separated by role.** A condensed-ish grotesque (Archivo) at heavy
   weights for every structural label, number and headword; a neutral UI sans (Inter) for
   body copy. Headings are uppercase with wide letter-spacing; body copy is not.
7. **Semantic colour mapping is fixed everywhere:** blue = learned / primary confirm,
   yellow = learning / intermediate, white = new / untouched, red = again / destructive /
   accent / error.

### 3.2 Colour tokens

**3.2.1 Minimalistic (default — `:root`, no `data-theme` attribute).**

| Token | Value | Semantic role |
|---|---|---|
| `--ink` | `#111111` | Primary text; active-tab fill; toast background |
| `--paper` | `#FFFFFF` | Page background; card fill; button fill |
| `--grey` | `#F2F2EF` | Secondary surface (synonym chips, word-detail sub-panel, guest avatar) |
| `--red` | `#DD0100` | Accent; "Again"; destructive; error text; primary CTA fill; focus outline; book tags; `.rel-go` chevron |
| `--blue` | `#225095` | "Learned"; "Know it"; primary confirm; progress-bar fill; meaning text; checkmarks |
| `--yellow` | `#FAC901` | "Learning"; antonym chips; example-sentence left rule |
| `--green` | `#0B7A3B` | Source colour for B2–C1 only |
| `--purple` | `#6A2C91` | Source colour for Essential only |
| `--line` | `var(--ink)` = `#111111` | Border colour (themeable independently of text ink) |
| `--rule` | `3px solid var(--line)` | The standard heavy border shorthand |
| `--muted` | `#666666` | Secondary text (hints, notes, labels, meanings in lists) |
| `--muted2` | `#999999` | Tertiary text (rank lines, POS pills, denominators) |
| `--faint` | `#cccccc` | Faint borders; the empty donut ring |
| `--radius` | `0px` | Corner rounding |
| `--card-bg` | `var(--paper)` | Surface fill for cards and inputs |
| `--shadow` | `none` | Card elevation |
| `--font-head` | `'Archivo', sans-serif` | Display / structural type |
| `--font-body` | `'Inter', sans-serif` | Body type |
| `--accent` | `var(--red)` = `#DD0100` | Focus rings, active-chip inset, generic accent |

Hard-coded colours outside the token system (must be reproduced literally):

| Value | Where |
|---|---|
| `#fff` | Text on `.btn-know`, `.pro-cta`, `.cf-send`, `.filters button.active`, `.posfilters button.active`, `.planchip.active`, `.toast`, `.pf-avatar`, Midnight active nav; also `.dot.new` background |
| `#111` | Text on yellow grounds: `.sb-niveau`, `.profile-btn.is-pro`, `.pf-avatar.is-pro` |
| `#b89200` | `.c-yellow` stat number (a darkened yellow for contrast on white) |
| `#bcd` | History cell level 1 |
| `#6b9` | History cell level 2 |
| `#4285F4` | The `G` glyph in the Google sign-in button |
| `rgba(0,0,0,.45)` | Scrim |
| `rgba(255,255,255,.6)` | Pro overlay wash (light themes) |
| `#0d0e15` | Anti-flash script + `applyTheme()` `theme-color` for Midnight |
| `#f3ead6` | Anti-flash script + `applyTheme()` `theme-color` for Sepia |
| `#FFFFFF` | `applyTheme()` `theme-color` for Minimalistic |

**3.2.2 Midnight (`html[data-theme="midnight"]`) — dark mode.**

| Token | Value | Notes |
|---|---|---|
| `--ink` | `#e8ebf7` | |
| `--paper` | `#0d0e15` | |
| `--grey` | `#1a1c2b` | |
| `--red` | `#ff6b81` | |
| `--blue` | `#6c8cff` | |
| `--yellow` | `#ffd166` | |
| `--green` | `#57d38a` | |
| `--purple` | `#b18cff` | |
| `--line` | `#2a2d42` | **Not** equal to `--ink` here |
| `--rule` | `1px solid var(--line)` | Rules thin from 3px to 1px |
| `--muted` | `#a2a8c4` | |
| `--muted2` | `#767c9c` | |
| `--faint` | `#2a2d42` | |
| `--radius` | `18px` | |
| `--card-bg` | `#161829` | |
| `--shadow` | `0 10px 30px rgba(0,0,0,.45)` | |
| `--font-head` | `'Inter', sans-serif` | Display face collapses to the body face |
| `--font-body` | `'Inter', sans-serif` | |
| `--accent` | `#6c8cff` | |

Midnight-only extras: body and `.topbar` background is
`radial-gradient(1100px 560px at 82% -12%, rgba(108,140,255,.18), transparent 60%),
radial-gradient(820px 480px at -12% 18%, rgba(255,107,129,.12), transparent 55%),
var(--paper)` with `background-attachment:fixed`. Active nav pill is
`linear-gradient(135deg, var(--blue), #8a6bff)` with `box-shadow:0 6px 18px
rgba(108,140,255,.42)`. Card-tag wash is `linear-gradient(135deg, rgba(108,140,255,.16),
transparent 70%)`. `.dot.new` / `.m-new` become `#2a2d42`. History levels 1 and 2 become
`#26406e` and `#3a63b0`. Toast inverts to `background:#e8ebf7; color:#0d0e15`. Dark text
`#0d0e15` is forced on `.chip.ant`, `.actions button.btn-learning` and `.planchip:hover`.
Drawer is a flat `#12141f`; scrim deepens to `rgba(0,0,0,.6)`; the pro overlay wash is
`rgba(13,14,21,.6)`.

**3.2.3 Sepia (`html[data-theme="sepia"]`).**

| Token | Value |
|---|---|
| `--ink` | `#3a2e22` |
| `--paper` | `#f3ead6` |
| `--grey` | `#e8dcc2` |
| `--red` | `#9c3b23` |
| `--blue` | `#3f6f6f` |
| `--yellow` | `#b6851b` |
| `--green` | `#4f7a3a` |
| `--purple` | `#6d4a86` |
| `--line` | `#cdbb92` |
| `--rule` | `1px solid var(--line)` |
| `--muted` | `#7c6c52` |
| `--muted2` | `#9a8a6f` |
| `--faint` | `#ddceac` |
| `--radius` | `0px` |
| `--card-bg` | `transparent` |
| `--shadow` | `none` |
| `--font-head` | `'Georgia', 'Times New Roman', serif` |
| `--font-body` | `'Georgia', 'Times New Roman', serif` |
| `--accent` | `#9c3b23` |

Sepia-only extras: paper-grain background (§2.7); the open filter menu is forced to
`background:var(--paper)` because `--card-bg` is transparent; `.actions button.btn-know`
forces `color:#fff`; `.msdrop-opt .chk` uses `var(--accent)`.

**3.2.4 Source colour map** (`SRC_COLORVAR`, used identically by the donut, the stacked
type bars, the legend dots and the row badges):

| Source id | Displayed as | Token | Minimalistic hex |
|---|---|---|---|
| `essential` | Essential | `--purple` | `#6A2C91` |
| `general` | General | `--muted` | `#666666` |
| `gang` | A0–A2 | `--blue` | `#225095` |
| `actie` | A2–B1 | `--red` | `#DD0100` |
| `niveau` | B1–B2 | `--yellow` | `#FAC901` |
| `perfectie` | B2–C1 | `--green` | `#0B7A3B` |

Because colour alone would not distinguish slices, the donut adds a 2px gap between
segments and every slice is duplicated as a labelled legend row.

### 3.3 Typography

Loaded from Google Fonts:
`https://fonts.googleapis.com/css2?family=Archivo:wght@400;600;700;900&family=Inter:wght@400;500;600&display=swap`,
preceded by `<link rel="preconnect" href="https://fonts.googleapis.com">`.

Note: the stylesheet requests Archivo 400/600/700/900 and Inter 400/500/600, but the CSS
also uses **weight 800** (`.probox .pro-h`, `.themebtn.langbtn`, `.drill-banner`,
`.pf-avatar`, `.pf-name`, `.cf-send`, `.planchip.srcchip`) and weight 900 on Inter under
Midnight. Those weights are synthesised by the browser.

| Element / class | Family | Size | Weight | Line-height | Letter-spacing | Transform |
|---|---|---|---|---|---|---|
| `body` | `--font-body` | (browser default 16px) | 400 | — | — | — |
| `.logo` | `--font-head` | 20px (Midnight 22px, Sepia 26px) | 900 (Midnight 800, Sepia 400) | — | −0.5px (Sepia .5px) | — |
| `.logo span` | `--font-head` | inherit | 700 | — | 0 | italic |
| `.counter` | `--font-head` | 13px | 700 | 1.2 | — | — |
| `.counter small` | `--font-body` | 10px | 400 | — | 1px (Midnight 1.4px, Sepia 2px) | uppercase |
| `nav button` | `--font-head` | 13px | 700 | — | 1px (Midnight .4px, Sepia .4px) | uppercase (Sepia none, 15px, weight 400) |
| `.card-tag` | inherit | 10px | 600 | — | 2px | uppercase |
| `.word-nl` | `--font-head` | **44px** (Sepia 46px italic 400) | 900 (Midnight 800) | 1 | −1px (Sepia 0) | — |
| `.word-en` | `--font-body` | 20px | 600 | — | — | — (Sepia italic) |
| `.word-en.big` | | 26px | 700 | 1.25 | — | — |
| `.word-hint` | | 12px | — | — | — | — |
| `.rankline` | | 11px | — | — | 1px | uppercase |
| `.prompt-lbl` | | 10px | 700 | — | 2px | uppercase |
| `.forms .frow`, `.frow` | | 13px | — | 1.75 / 1.7 | — | — |
| `.frow b` | | 13px | 600 | — | — | — (`min-width:96px`) |
| `.chip` | | 11.5px | 600 | — | — | — |
| `.sentence` | | 14px | — | 1.5 | — | — |
| `.sentence em` | | 12.5px | 400 | — | — | not italic |
| `.actions button` | `--font-head` | 13px | 700 | — | 0.5px | uppercase |
| `.btn-skip` | | 12px `!important` | — | — | — | — |
| `.deckinfo` | | 12px | — | — | — | — |
| `.filters button` | | 11px | 600 | — | 0.5px | uppercase |
| `.msdrop > summary` | `--font-body` | 12px | 600 | 1.2 | — | — |
| `.msdrop-arw` | | 9px | — | — | — | — |
| `.msdrop-opt` | `--font-body` | 13px | 400 (`.sel` 700) | — | — | — |
| `.wrow .nl` | `--font-head` | 15px | 700 | — | — | — |
| `.wrow .en` | | 13px | — | — | — | — |
| `.wpos` | `--font-body` | 9px | 500 | — | 1px | uppercase |
| `.srcbadge` | `--font-head` | 9px | 900 | 15px | — | — |
| `.loadmore` | `--font-head` | (inherit 16px) | 700 | — | 1px | uppercase |
| `.stat .num` | `--font-head` | **34px** | 900 | 1 | — | — |
| `.stat .lbl` | | 10px | — | — | 1.5px | uppercase |
| `.genbox h3`, `.acc-h` | `--font-head` | 16px | 900 | — | 0.5px | uppercase |
| `.genbox p` | | 13px | — | 1.5 | — | — |
| `.genbtn` | `--font-head` | 14px | 900 | — | 1px | uppercase |
| `.note` | | 11.5px | — | 1.5 | — | — |
| `.keyok` | | 12px | 600 | — | — | — |
| `.toast` | | 13px | 600 | — | — | — |
| `.empty` | | 14px | — | — | — | — |
| `.rowbtns button` | `--font-head` | 12px | 700 | — | 0.5px | uppercase |
| `.sec-h` | `--font-head` | 11px | 700 | — | 1.5px | uppercase |
| `.rel-w` | `--font-head` | 14px | 700 | — | — | — |
| `.rel-m` | | 12.5px | — | — | — | — |
| `.rel-go` | `--font-head` | 18px | 900 | — | — | — |
| `.posname` | | 13px | 600 | — | — | — |
| `.poscount` | `--font-head` | 12px | 700 | — | — | — |
| `.donut-num` | `--font-head` | 30px | 900 | — | — | — |
| `.donut-lbl` | `--font-head` | 11px | 700 | — | .5px | uppercase |
| `.srcname` | | 13px | 600 | — | — | — |
| `.daily-num` | `--font-head` | **36px** | 900 | 1 | — | — |
| `.daily-num span` | | 18px | — | — | — | — |
| `.streak-badge` | `--font-head` | 26px | 900 | 1 | — | — |
| `.streak-badge small` | `--font-body` | 9px | 400 | — | 1px | uppercase |
| `.planchip` | `--font-head` | 15px | 900 | 1.15 | — | (`.onerow` uppercase) |
| `.planchip.srcchip` | `--font-head` | 14px | 800 | — | 0.2px | — |
| `.plan-form label` | | 12px | 600 | — | 0.5px | uppercase |
| `.remind-time label` | | 12px | 600 | — | 1px | uppercase |
| `.drawer-title` | `--font-head` | 18px (Sepia 20px italic 400) | 900 | — | 1px (Sepia .5px) | uppercase (Sepia none) |
| `.acc-arrow` | | 22px | — | 1 | — | — |
| `.themebtn.langbtn` | `--font-head` | 13px | 800 | — | 1px | — |
| `.lang-note` | | 12px | — | 1.4 | — | — |
| `.probox .pro-h` | `--font-head` | 17px | 900 | — | 1px | uppercase |
| `.probox .pro-crown` | | 20px | — | — | — | — |
| `.probox .pro-chk` | | 12px | — | — | 1px | — |
| `.pro-lockico` | | 34px | — | 1 | — | — |
| `.pro-msg` | `--font-head` | 15px | 900 | — | 2px | uppercase |
| `.pro-sub` | | 13px | — | — | — | — |
| `.pro-cta` | `--font-head` | (inherit) | 800 | — | 1px | uppercase |
| `.pro-restore` | | 12px | — | — | 1px | uppercase |
| `.pf-title` | `--font-head` | 22px | 900 | — | — | — |
| `.pf-avatar` | `--font-head` | 20px (guest 26px) | 800 | — | — | — |
| `.pf-name` | `--font-head` | 18px | 800 | 1.2 | — | — |
| `.pf-email` | | 13px | — | — | — | — |
| `.pf-meta` | | 11px | — | — | .5px | — |
| `.pf-row` | | 14px | — | — | — | — |
| `.gsi-btn` | `--font-head` | 14px | 700 | — | — | — |
| `.gsi-btn .gsi-g` | Arial, sans-serif | 14px | 800 | — | — | — |
| `.auth-alt` | | 13px | 600 | — | — | — |
| `.auth-form .cf-input` | `--font-body` | 15px | — | — | — | — |
| `.cf-label` | | 12px | 700 | — | .5px | — |
| `.cf-input` | `--font-body` | 14px | — | (textarea 1.4) | — | — |
| `.cf-hint` / `.cf-note` | | 12px | — | 1.4 | — | — |
| `.cf-send` | `--font-head` | 15px | 800 | — | .5px | uppercase |
| `.type-input` | `--font-body` | 18px | — | — | — | — |
| `.result-head` | `--font-head` | 14px | 900 | — | 1px | uppercase |
| `.ans-word` | `--font-head` | 26px | 900 | — | — | — |
| `.ans-yours` | | 13px | — | — | — | — |
| `.cloze-sent` | | 19px | 600 | 1.5 | — | — |
| `.cloze-blank` | | inherit | 800 | — | — | — |
| `.cloze-en` | | 13px | — | — | — | italic |
| `.dehet-btn` | `--font-head` | 22px | 900 | — | — | lowercase |
| `.drill-banner` | `--font-head` | 12px | 800 | — | 1px | uppercase |
| `.leech-w` | `--font-head` | 14px | 700 | — | — | — |
| `.leech-m` | | 12px | — | — | — | — |
| `.leech-x` | | 12px | 700 | — | — | — |
| `input[type=search|password|text|date|number]` | `--font-body` | 14px | — | — | — | — |
| `.dot`, `.histcell`, `.srcdot`, `.posbar` etc. | — | — | — | — | — | — |

### 3.4 Spacing, borders, radii, shadows

**3.4.1 Spacing values actually used** (there is no formal scale; these are the literal
values in the stylesheet): `0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 16, 18, 20, 22,
24, 30, 32, 48, 60, 98` px. The dominant rhythm is **16 px page padding**, **12 px gutters**,
**8–10 px inner gaps** and **6 px chip gaps**.

| Purpose | Value |
|---|---|
| Page padding (`main`) | `16px`, plus `padding-bottom:48px` (Midnight 98px, Sepia `24px 22px 60px`) |
| Header padding | `14px 16px` (Midnight `20px 18px 8px`, Sepia `22px 18px`) |
| Nav button padding | `12px 4px` (Midnight `13px 4px`, Sepia `9px 2px`) |
| Card body padding | `24px 20px`, `gap:8px` |
| Card tag padding | `8px 12px` |
| Action button padding | `14px 6px` |
| Word-row padding | `10px 12px` |
| `.genbox` padding | `16px`, `margin-top:18px` |
| Accordion header padding | `16px`; open body `padding:0 16px 16px` |
| Drawer padding | `16px 16px 32px` |
| Filter-bar gap | `8px`, `margin-bottom:12px` |
| Chip row gap | `6px` (`.srcchips` 8px) |
| Section top margin | `16px`, `padding-top:10px` |
| Toast offset | `bottom:16px` |

**3.4.2 Border widths.**

| Width | Where |
|---|---|
| `var(--rule)` = 3px (Midnight/Sepia 1px) | Cards, nav, header, `.actions`, `.filters`, `.mstrip`, `.genbox`, `.stats`, `.genbtn`, `.loadmore`, `.menu-btn`, `.drawer-close`, `.themebtn`, `.planchip`, `.bigplay`, `.dehet-btn`, `.type-input`, text/date/number/search inputs, `.cf-input`, `.cf-send`, `.drawer` right edge |
| 3px (literal, not the token) | `.mstrip div` separators, `.stat` right/bottom rules |
| 2px | `.wrow`, `.dot`, `.wdetail`, `.rel`, `.chip`, `.posbar`, `.progbar`, `.histcell`, `.srcdot`, `.msdrop > summary`, `.msdrop-menu`, `.section` top rule, `.pro-restore`, `.auth-alt`, `.gsi-btn`, `.auth-form .cf-input`, `.drill-banner`, `.pf-avatar.is-pro`, `.profile-btn` |
| 1px | `.wpos` pill, `.leechrow` bottom, `.plan-remind` top, `.pf-row` bottom, `.gsi-g` |
| 4px / 6px (accent rules) | `.sentence` left rule 4px (yellow); `.rel-syn` / `.rel-ant` left rule 6px |
| 3px (cloze) | `.cloze-blank` bottom rule (red) |

**3.4.3 Corner radii.** `--radius: 0px` default, `18px` in Midnight, `0px` in Sepia. The
token is applied to `.card, .genbox, .stats, .plan-box, .actions, .filters,
input[type=search|password|text|date], .genbtn, .loadmore, .wdetail, .rel, .chip,
.planchip, .rowbtns button, .msdrop > summary, .msdrop-menu, .themebtn, .cf-input, .cf-send`.
`calc(var(--radius) * .5)` is used for `.menu-btn`, `.drawer-close` and `.themebtn .swatch`.
Fixed radii not from the token: `50%` (`.profile-btn`, `.pf-avatar`, `.bigplay`, `.gsi-g`),
`6px` (`.msdrop-opt`), `22px` and `16px` (Midnight nav pill and its buttons).

`.stats, .actions, .filters` carry `overflow:hidden` so their inner rules stay inside the
rounded corners. **`nav` is deliberately excluded** from that rule — `overflow:hidden` on
nav re-triggers the Android-Chrome vanishing-tab-bar bug.

**3.4.4 Shadows.** `--shadow: none` default; `0 10px 30px rgba(0,0,0,.45)` in Midnight;
`none` in Sepia. Applied to `.card, .genbox, .stats, .plan-box` and `.msdrop-menu`.
Additional fixed shadows: Midnight nav `0 14px 36px rgba(0,0,0,.55)`, Midnight active nav
pill `0 6px 18px rgba(108,140,255,.42)`, Midnight drawer `24px 0 60px rgba(0,0,0,.55)`.
Inset shadows are used as state indicators, never as depth: `.themebtn.active`
`inset 0 0 0 3px var(--accent)`, focused `.cf-input` `inset 0 0 0 2px var(--accent)`,
`.cf-input.cf-err` `inset 0 0 0 2px var(--red)`, `.profile-btn.on-tab`
`0 0 0 2px var(--accent) inset`.

### 3.5 Breakpoints and responsive rules

**There are no width-based media queries at all.** Responsiveness is achieved entirely with
intrinsic sizing:

| Rule | Value |
|---|---|
| Content column | `main { max-width: 640px; width:100%; margin:0 auto }` (Sepia 520px) |
| Drawer | `width: min(340px, 88vw)` |
| Midnight floating nav | `width: min(440px, 92vw)` |
| Toast | `max-width: 90vw` |
| Filter dropdowns | `flex: 1 1 0; min-width: 0` — always equal width, always one row (`.filterbar { flex-wrap: nowrap }`), labels ellipsise |
| Dropdown menu | `min-width:100%; max-width:260px; max-height:300px; overflow-y:auto`; last one right-anchored |
| Word-type / source legend | `.srcbreak { flex-wrap: wrap }`, `.srclegend { flex: 1 1 190px; min-width: 190px }` — the legend drops below the donut on narrow screens |
| Chip rows | `.chiprow { flex-wrap: wrap }` except `.onerow` which is `nowrap` |
| Headword | `word-break: break-word` |
| History grid | `grid-template-columns: repeat(14, 1fr)` with `aspect-ratio: 1` cells |
| Stats grid | `grid-template-columns: 1fr 1fr` at all widths |
| Viewport meta | `width=device-width, initial-scale=1.0` |
| Manifest orientation | `portrait` |

The only media queries present are two `@media (prefers-reduced-motion: reduce)` blocks
(§8.5).

### 3.6 Dark mode

Dark mode is **not** automatic. There is no `prefers-color-scheme` query anywhere. Dark is
the "Midnight" theme, chosen manually from the drawer and persisted as `dutch5k-theme`.
Values are in §3.2.2. See §12 for the open question about honouring the OS setting.

### 3.7 Focus and accessibility

- `button:focus-visible, input:focus-visible, .card:focus-visible` →
  `outline: 3px solid var(--red); outline-offset: 2px`.
- `button { color: var(--ink) }` is set explicitly under `body` because buttons do not
  inherit `color` and would otherwise render UA-black (invisible on Midnight). Any new
  coloured button must set its own `color`.
- Global reset: `* { box-sizing:border-box; margin:0; padding:0 }`, `html, body { height:100% }`.
- ARIA in use: `aria-label` on the menu button, drawer close, profile button, flip card,
  audio buttons, drill-exit, theme/language chips and the donut; `aria-expanded` on the
  menu button and every accordion header; `aria-hidden` on the drawer and decorative
  glyphs; `role="button"` + `tabindex="0"` on the flip card and the free-plan Pro box;
  `role="img"` on the donut SVG.

---

## 4. GRAPHICS AND ASSETS

### 4.1 Inline SVG — the only vector graphic in the app

**4.1.1 Speaker icon (`SPK_SVG`).** Used for every pronunciation button. Full source,
verbatim:

```html
<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 9v6h4l5 5V4L8 9H4z" fill="currentColor"/><path d="M15.5 8.5c1.6 1.2 1.6 5.8 0 7" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M18 6c3 2.2 3 9.8 0 12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>
```

It always inherits `currentColor`, so it is ink-coloured at rest and `var(--red)` while
speaking. Rendered sizes:

| Context | Button box | Padding | Notes |
|---|---|---|---|
| `.spk` (base) | 28×28px | 3px | `opacity:.68`, `:hover` → 1, `:active` → `scale(.88)`, `margin:0 0 0 5px` |
| `.word-nl .spk` | 34×34px | 5px | `margin-left:9px` |
| `.wrow .spk` | 26×26px | 3px | |
| `.spk-ex` (example sentences) | 22×22px | 2px | `margin-left:4px` |
| `.bigplay` (Listen mode) | 88×88px circle, SVG 44×44px | — | `border:var(--rule)`, `:active` → `scale(.94)`, `.speaking` → red text + red border |

`.spk.speaking` → `color: var(--red); opacity: 1`.

**4.1.2 Donut chart SVG.** Generated at render time, not a stored asset. Full geometry in
§2.4.2 item 8.

### 4.2 Icon glyphs — all emoji / HTML entities, no icon font

Every other "icon" in the UI is a literal character. Reproduce these exactly.

| Entity | Char | Where used |
|---|---|---|
| `&#128100;` | 👤 | Guest avatar (header button and profile page) |
| `&#128081;` | 👑 | Pro box crown (drawer + profile) |
| `&#128274;` | 🔒 | Pro overlay icon; locked word-row mini badge |
| `&#128293;` | 🔥 | Streak card, streak badge, Hardest-words heading, Drill button, drill banner, Learn daily line |
| `&#128197;` | 📅 | Study plan heading |
| `&#127919;` | 🎯 | Learning goal heading |
| `&#128218;` | 📚 | Book-tag line on cards; every About-box source line |
| `&#11088;` | ⭐ | About-box Essential line |
| `&#9733;` | ★ | Essential source badge in word rows |
| `&#128276;` | 🔔 | "Turn on daily reminders" button |
| `&#127881;` | 🎉 | Daily-goal-reached toast |
| `&#128256;` | 🔀 | Shuffle option row + shuffle-on toast |
| `&#128308;` | 🔴 | "New words only" option row + toast |
| `&#10003;` | ✓ | Know it; dropdown checkmarks; Unlocked/Active; Correct!; daily-goal-complete; reminders-on |
| `&#10007;` | ✗ | Again; Not quite; leech miss counter |
| `&#8776;` | ≈ | Learning button |
| `&#8631;` | ↷ | Skip / Skip for now / Review again |
| `&#8635;` | ↻ | Review heading, Start review, due-for-review line |
| `&#8594;` | → | CTA arrows |
| `&#8592;` | ← | Back buttons |
| `&#8250;` | › | Accordion arrow; related-word chevron |
| `&#9662;` | ▾ | Dropdown arrow |
| `&#8800;` | ≠ | Antonym marker |
| `&#183;` | · | Separator in card tags, book tags, dropdown counts |
| `&#10005;` | ✕ | Drawer close; drill-banner exit |
| `&#128196;` | 📄 | Cards mode |
| `&#128260;` | 🔄 | Reverse mode |
| `&#9000;` | ⌨ | Type mode |
| `&#128266;` | 🔊 | Listen mode |
| `&#9986;` | ✂ | Cloze mode |
| `&#127475;&#127473;` | 🇳🇱 | de/het mode |
| `&#8212;` / `&rarr;` | — / → | Title and metadata strings |

The hamburger is not an icon: it is three `<span>` elements, each `height:3px;
background:var(--ink)`, inside a 38×38px flex column with `gap:4px` and `padding:9px 8px`.

The Google `G` is not an icon either: it is the literal letter **G** in
`span.gsi-g` — a 22×22px white circle, `color:#4285F4`, `font-family:Arial, sans-serif`,
weight 800, 14px, `border:1px solid var(--line)`.

### 4.3 Raster assets in `public/`

All are real files. They **must** exist as real files: `wrangler.jsonc` sets
`not_found_handling: "single-page-application"`, so any referenced-but-missing path returns
`index.html` with HTTP 200 and the wrong content type — a silently broken icon.

| File | Dimensions | Size | Purpose |
|---|---|---|---|
| `favicon.ico` | 16×16, 32×32, 48×48 (multi-size ICO) | 8,569 B | `<link rel="icon" sizes="48x48">` |
| `favicon.svg` | 180×180 viewBox | 69,456 B | `<link rel="icon" type="image/svg+xml">`. **Not a true vector** — it is a one-line SVG wrapper embedding the 180px PNG as a base64 `data:` URI in a single `<image>` element |
| `favicon-32.png` | 32×32 | 2,441 B | Generated but **not referenced** from the HTML |
| `apple-touch-icon.png` | 180×180 | 51,975 B | iOS home screen |
| `icon-192.png` | 192×192 | 57,639 B | Manifest icon |
| `icon-512.png` | 512×512 | 309,586 B | Manifest icon |
| `icon-maskable-512.png` | 512×512 | 226,278 B | Manifest icon, `purpose: "maskable"`; badge shrunk to ~78 % of the tile so Android's circular mask never clips the ring or the arc text |
| `og-image.png` | 1200×630 | 387,625 B | `og:image` and `twitter:image` |

**4.3.1 The logo artwork.** A circular badge, used **only** for the browser tab, home-screen
icon and link-share card — **never anywhere inside the app UI**, which stays Mondrian.
Description: a Dutch-flag ring (red / white / navy arcs) around a pale-blue scene; arc text
"DUTCH TO GO" across the top in navy and "Vocab Trainer" across the bottom in orange; an
orange bicycle with a front basket in the centre; three speech bubbles reading **HALLO!**
(orange), **LEER!** (navy) and **DOORGAAN** (navy, with a small Dutch flag and a star);
windmills left, Amsterdam canal houses and a church spire right, an orange canal path
below. The badge is circle-masked and composited onto a **white** square, so every tile is
a white square with the ringed badge centred at ~94 % of the tile (78 % for maskable).

**4.3.2 The share card (`og-image.png`).** 1200×630 on white. Badge on the left at 460×460
inset 60px from the left edge, vertically centred. Text block on the right starting at
x = 580: **"Dutch To Go"** in heavy navy, **"Vocab Trainer"** in heavy orange below it, and
a two-line grey subtitle "Learn 5,000+ Dutch words — flashcards, examples, offline."

**4.3.3 Generator script.** `scratchpad/make_icons.py` (Pillow only:
`pip install Pillow numpy`) crops the circular part of a wide source banner, anti-aliased
circle-masks it, composites onto white, and writes every file listed above.
**Warning: the committed copy of this script is stale.** It still carries the previous
(v48) tulip-book artwork parameters `SRC`, `CX=511, CY=284, R=210` and the old share-card
copy `("Learn Dutch,", "5,000 words at a time", "flashcards · examples · offline")`. The
shipped PNGs are the newer bicycle badge with different copy. Re-running the committed
script would **not** reproduce the current assets. See §12.

### 4.4 `public/site.webmanifest`

```json
{
  "name": "Dutch To Go — Vocab Trainer (A0 → C1)",
  "short_name": "Dutch To Go",
  "description": "Learn the 5,000 most common Dutch words — flashcards, examples, offline.",
  "start_url": "/",
  "scope": "/",
  "display": "standalone",
  "orientation": "portrait",
  "background_color": "#ffffff",
  "theme_color": "#ffffff",
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" },
    { "src": "/icon-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable" }
  ]
}
```

Note the manifest's `theme_color` is a static `#ffffff` and does **not** track the chosen
theme; the `<meta name="theme-color">` tag does (§7.13).

### 4.5 `<head>` metadata (reproduce verbatim)

| Tag | Value |
|---|---|
| `<title>` | `Dutch To Go — Vocab Trainer (A0 → C1)` |
| `meta[name=description]` | `Learn the 5,000 most common Dutch words — flashcards, examples, offline.` |
| `meta[name=theme-color]` | `#ffffff` (rewritten at runtime by `applyTheme`) |
| `meta[name=application-name]` | `Dutch To Go` |
| `meta[name=apple-mobile-web-app-capable]` | `yes` |
| `meta[name=mobile-web-app-capable]` | `yes` |
| `meta[name=apple-mobile-web-app-status-bar-style]` | `default` |
| `meta[name=apple-mobile-web-app-title]` | `Dutch To Go` |
| `meta[property=og:type]` | `website` |
| `meta[property=og:site_name]` | `Dutch To Go` |
| `meta[property=og:title]` | `Dutch To Go — Vocab Trainer (A0 → C1)` |
| `meta[property=og:description]` | same as description |
| `meta[property=og:image]` | `/og-image.png` (**relative**) |
| `meta[property=og:image:type]` | `image/png` |
| `meta[property=og:image:width]` / `:height` | `1200` / `630` |
| `meta[property=og:image:alt]` | `Dutch To Go — Dutch vocab trainer (A0 → C1)` |
| `meta[name=twitter:card]` | `summary_large_image` |
| `meta[name=twitter:title]` / `:description` / `:image` | same values as the OG equivalents |

### 4.6 Assets that do NOT exist yet and are required for native

| Need | Platform | Status |
|---|---|---|
| iOS app icon set — 1024×1024 App Store marketing icon plus the full `AppIcon.appiconset` ladder (20/29/40/60/76/83.5 pt @1×/2×/3×) | iOS | **Missing.** Only 32/180/192/512 exist. All can be regenerated from the source badge art |
| Android adaptive icon — separate `ic_launcher_foreground` and `ic_launcher_background` layers at 108×108 dp with a 72 dp safe zone | Android | **Missing.** `icon-maskable-512.png` is a flattened square, not a two-layer adaptive icon |
| Android legacy mipmaps (mdpi 48 → xxxhdpi 192) | Android | **Missing** |
| Launch screen / splash | iOS + Android | **Missing entirely.** No splash asset or storyboard exists. A minimal equivalent would be the badge centred on `#FFFFFF` (or `#0d0e15` / `#f3ead6` per theme) |
| Notification small icon (monochrome, transparent, 24×24 dp) | Android | **Missing.** Android requires a silhouette icon for the status bar; the coloured badge cannot be used |
| App Store / Play Store screenshots and feature graphic (1024×500) | both | **Missing** |
| Original vector or high-resolution source of the badge artwork | both | **Missing from the repository.** Only rasterised outputs are committed; the source path in `make_icons.py` points outside the repo |

---

## 5. CONTENT

### 5.0 How to read these tables

- **Verbatim** — reproduce the string exactly, including curly quotes (’ “ ” « »), em dashes
  (—), the ellipsis character (…), the middle dot (·) and the exact placeholder spelling.
- **`{x}` placeholders** are substituted **after** dictionary lookup, so a translation may
  reorder them. Placeholder names are case-sensitive.
- **L10n column:**
  - **✅** — the string is a key in all 10 non-English UI dictionaries (`fr it es de pt pl
    tr uk ru bg`). 157 strings are in this class.
  - **EN-only** — the string is passed through `T()` but has **no** dictionary entry, so it
    always falls back to English. 57 strings are in this class (all of Contact, all of Pro,
    all of Profile/auth).
  - **Literal** — the string is hard-coded and never passed through `T()` at all.
- Total translated dictionary keys: **214 per language** (some are dynamic-lookup keys such
  as part-of-speech labels and grammar-form labels; some are dead keys left over from
  removed features — listed in §5.10).

### 5.1 Global chrome

| String | L10n | Notes |
|---|---|---|
| `DUTCH ` | Literal | Header logo, first half |
| `to go` | Literal | Header logo, italic red `<span>` |
| `Words learned` | ✅ | Header counter caption; also a Profile row label |
| `Learn` | ✅ | Nav tab 1 |
| `Words` | ✅ | Nav tab 2 |
| `Progress` | ✅ | Nav tab 3 |
| `Menu` | ✅ | Hamburger `aria-label` **and** the drawer title |
| `Close` | ✅ | Drawer close `aria-label` |
| `Profile` | EN-only | Avatar `aria-label` and the Profile page title |
| `blue = learned, yellow = learning, white = new` | ✅ | Progress-strip `title` |
| `Storage full — export your progress` | ✅ | Toast when `localStorage.setItem` throws |

### 5.2 Learn tab

**5.2.1 Filters and modes**

| String | L10n |
|---|---|
| `Study mode` | ✅ |
| `Word type` | ✅ |
| `Source` | ✅ |
| `Options` | ✅ |
| `All types` | ✅ |
| `All sources` | ✅ |
| `Essential` | ✅ |
| `General 5K` | ✅ |
| `A0 → A2` | Literal |
| `A2 → B1` | Literal |
| `B1 → B2` | Literal |
| `B2 → C1` | Literal |
| `Shuffle` | ✅ |
| `New words only` | ✅ |
| `Cards` | ✅ |
| `Reverse` | ✅ |
| `Type` | ✅ |
| `Listen` | ✅ |
| `Cloze` | ✅ |
| `de / het` | Literal (Dutch) |
| `Verbs` `Nouns` `Adjectives` `Adverbs` `Pronouns` `Prepositions` `Conjunctions` `Numbers` `Expressions` `Articles` | ✅ | Word-type option labels, from `POS_LABELS` |

**5.2.2 Card faces**

| String | L10n |
|---|---|
| `What is this in Dutch?` | ✅ |
| `Tap to reveal the Dutch word` | ✅ |
| `Listen, then recall the meaning` | ✅ |
| `Play audio` | ✅ |
| `Tap the card to reveal` | ✅ |
| `Tap to reveal meaning, forms, examples &amp; related words` | ✅ (note: the literal source contains the HTML entity `&amp;`) |
| `Flip card` | ✅ |
| `Hear pronunciation in Dutch` | ✅ |
| `Hear this sentence` | ✅ |
| `More examples and grammar forms are being added.` | ✅ |
| `Preparing this card…` | ✅ |
| `Not translated yet` | ✅ |
| `Forms` | ✅ |
| `Synonyms` | ✅ |
| `Antonyms` | ✅ |
| `Examples` | ✅ |
| `#{n} most frequent` | ✅ |
| `curated extra` | ✅ |
| `word` | ✅ (fallback card-tag label when an entry has no part of speech) |
| `new` / `learning` / `learned` | ✅ (rendered uppercased in the card tag) |
| `verb` `noun` `adjective` `adverb` `pronoun` `preposition` `conjunction` `number` `expression` `particle` `article` `all` | ✅ (lowercase part-of-speech names used in card tags and the Words-row pill) |

**5.2.3 Grading and navigation**

| String | L10n |
|---|---|
| `Show answer` | ✅ |
| `Again` | ✅ |
| `Learning` | ✅ |
| `Know it` | ✅ |
| `Skip` | ✅ |
| `Skip for now` | ✅ |
| `Type the Dutch word` | ✅ |
| `Fill in the missing word` | ✅ |
| `Type here…` | ✅ |
| `Check` | ✅ |
| `You typed:` | ✅ |
| `Correct!` | ✅ |
| `Not quite` | ✅ |
| `Continue` | ✅ |
| `Review again` | ✅ |
| `I knew it` | ✅ |
| `de or het?` | ✅ |
| `It is “{a}”` | ✅ (curly quotes) |
| `Next` | ✅ |
| `article` | ✅ (de/het card tag) |
| `de` / `het` | Literal (Dutch, the two answer buttons) |

**5.2.4 Footers, banners and empty states**

| String | L10n |
|---|---|
| `Card {a} of {b} in this round · {c} words in deck` | ✅ |
| `Today: {n} learned · streak {s}` | ✅ |
| `{n} due for review` | ✅ |
| `Drilling hardest words` | ✅ |
| `Exit drill` | ✅ |
| `No tricky words yet — keep going!` | ✅ |
| `No new words left — turn off “New words only” to review.` | ✅ |
| `No words available for this mode with these filters.` | ✅ |
| `Try “All”.` | ✅ |

**5.2.5 Toasts fired from Learn**

| String | L10n |
|---|---|
| `Shuffle on · strategic mix of new words` | ✅ (prefixed with 🔀) |
| `Shuffle off · frequency order` | ✅ |
| `New words only · reviews paused` | ✅ (prefixed with 🔴) |
| `Reviews resumed` | ✅ |
| `Daily goal reached: {n} words!` | ✅ (prefixed with 🎉) |
| `Card preparation failed — check your API key in Progress` | ✅ |
| `Pronunciation isn't supported on this device` | ✅ (straight apostrophe) |

### 5.3 Words tab

| String | L10n |
|---|---|
| `Search Dutch or English…` | ✅ |
| `Status` | ✅ |
| `All` | ✅ (status reset row) |
| `tap to open` | ✅ |
| `No words match.` | ✅ |
| `Show more ({n} remaining)` | ✅ |
| `1 word` | ✅ |
| `{n} words` | ✅ |
| `Back` | ✅ |
| `Back to list` | ✅ |
| `textbook word` | ✅ |
| `Preparing…` | ✅ |
| `Meaning will be added when you add an API key, or from the app online.` | ✅ |
| `Locked` | EN-only (`title` on the locked-row mini badge) |

Grammar-form labels rendered inside the Forms section are looked up dynamically and are all
translated: `Present`, `Past`, `Past sg/pl`, `Perfect`, `Plural`, `Diminutive`,
`Comparative`, `Superlative`, `Feminine`, `Object`, `Possessive`, `Stressed`, `Informal`,
`Formal`, `Note`, `Forms`.

### 5.4 Progress tab

| String | L10n |
|---|---|
| `Learned` | ✅ (stat tile **and** the donut centre caption) |
| `Still learning` | ✅ |
| `Not started` | ✅ |
| `Of {goal} goal` | ✅ |
| `Streak` | ✅ |
| `words today` | ✅ |
| `day streak` | ✅ |
| `Review` | ✅ |
| `due for review` | ✅ |
| `Words you’ve started that are scheduled to come back today. Reviewing on time is what moves them into long-term memory.` | ✅ (curly apostrophe) |
| `Start review` | ✅ |
| `All caught up — nothing due right now. Words you learn come back on a spaced schedule so you review them right before you’d forget.` | ✅ |
| `Hardest words` | ✅ |
| `times missed` | ✅ |
| `Words you keep missing. Drill them to lock them in.` | ✅ |
| `Drill hardest words` | ✅ |
| `Last 14 days` | ✅ |
| `Each square is a day; darker means more words learned. Learn at least one word a day to keep your streak alive.` | ✅ |
| `By word type` | ✅ |
| `Tap a type to study or browse just those words.` | ✅ |
| `By source` | ✅ |
| `Tap a source to study or browse just those words.` | ✅ |
| `Essential` `General` `A0–A2` `A2–B1` `B1–B2` `B2–C1` | Literal — `SRC_SHORT` legend labels (note these use an **en dash**, unlike the filter dropdown's arrow form) |

### 5.5 Profile page — all EN-only

| String | L10n |
|---|---|
| `Profile` | EN-only |
| `Save your progress` | EN-only |
| `Create an account or log in so your progress and Pro plan live in your account — not just on this device.` | EN-only |
| `Continue with Google` | EN-only |
| `Your Google email` | EN-only |
| `Demo Google sign-in — real Google login is coming soon.` | EN-only |
| `Sign up with email` | EN-only |
| `Your name` | EN-only |
| `Email address` | EN-only |
| `Create account` | EN-only |
| `I already have an account` | EN-only |
| `Log in` | EN-only |
| `No account found for that email — sign up instead.` | EN-only |
| `Signed in with {p}` | EN-only |
| `Email` | EN-only (the provider label for non-Google accounts) |
| `Google` | Literal (the provider label for Google accounts) |
| `Member since {d}` | EN-only |
| `Plan` | EN-only |
| `Pro` | EN-only |
| `Free` | EN-only |
| `Your progress is saved to your account. Cloud sync across devices is coming soon; for now it is stored on this device.` | EN-only |
| `Sign out` | EN-only |
| `Signed in as {name}.` | EN-only (toast) |
| `Signed in as {name}. Signed out of your other device.` | EN-only (toast) |
| `Signed out. Your progress stays on this device.` | EN-only (toast) |

### 5.6 Pro / paywall — all EN-only

| String | L10n |
|---|---|
| `Pro to go` | EN-only |
| `Unlocked` | EN-only (drawer badge) |
| `Active` | EN-only (profile badge) |
| `You have full access to every word, list and stat.` | EN-only |
| `Switch back to Free (test)` | EN-only |
| `The free version unlocks a limited set of words. Go Pro for full access to every word across all levels, the complete word list and all progress stats.` | EN-only (drawer copy) |
| `Go Pro for full access to every word across all levels, the complete word list and all progress stats.` | EN-only (profile copy — note the shorter first clause) |
| `Unlock Pro to go` | EN-only |
| `Locked` | EN-only |
| `Unlock Pro version for full access` | EN-only |
| `Get Pro` | EN-only |
| `Sign in to get Pro` | EN-only |
| `Pro is tied to your account, so it follows you when sync arrives.` | EN-only |
| `Create an account or sign in to go Pro.` | EN-only (toast) |
| `Pro unlocked — full access!` | EN-only (toast) |
| `Back on the Free plan.` | EN-only (toast) |

### 5.7 Goal and study plan

| String | L10n |
|---|---|
| `Learning goal` | ✅ |
| `Set a target — a number of words, or specific sources to finish. Your progress percentage and daily plan are measured against it.` | ✅ |
| `By word count` | ✅ |
| `By source` | ✅ |
| `Words to learn` | ✅ |
| `All` | ✅ (rendered uppercase as **ALL** by `.chiprow.onerow`) |
| `Or enter an exact number` | ✅ |
| `Set goal` | ✅ |
| `Learn all {n} words` | ✅ |
| `Learn every word from the sources you choose` | ✅ |
| `Goal: learn all {n} words in the selected {c} source(s).` | ✅ |
| `Pick one or more sources above to set your goal.` | ✅ |
| `Enter how many words you want to learn.` | ✅ (toast) |
| `Goal set: {n} words.` | ✅ (toast) |
| `Goal reset to all {n} words.` | ✅ (toast) |
| `Study plan` | ✅ |
| `Pick how many words to learn per day (or a target date), and the app tracks your streak and shows exactly how many to do each day.` | ✅ |
| `Words per day` | ✅ |
| `Or reach {goal} by a date` | ✅ |
| `Set target date` | ✅ |
| `Pick a date or tap a number above` | ✅ (toast) |
| `At {n}/day you'll reach {goal} in about {d} days (~{date}).` | ✅ (straight apostrophe in `you'll`) |
| `To hit {goal} by {date}, learn about {n}/day ({d} days left).` | ✅ |
| `Daily goal complete — nice work!` | ✅ |
| `Study now` | ✅ |
| `Edit plan` | ✅ |
| `Remove` | ✅ |

### 5.8 Reminders

| String | L10n |
|---|---|
| `Turn on daily reminders` | ✅ |
| `Daily reminders on` | ✅ (button label **and** toast) |
| `Daily reminders off` | ✅ (toast) |
| `Reminder permission denied` | ✅ (toast) |
| `Reminder time` | ✅ |
| `Reminder time set` | ✅ (toast) |
| `Times are in your device timezone ({tz}).` | ✅ |
| `Reminders fire while the app is open in your browser; keep the tab around to be nudged.` | ✅ |
| `Notifications not supported on this device` | ✅ (toast) |
| `Dutch To Go` | Literal — the notification **title** |
| `Time for today's words! Keep your streak going.` | ✅ — the notification **body** (straight apostrophe) |

### 5.9 Settings drawer

| String | L10n |
|---|---|
| `About the app` | ✅ |
| `Build your Dutch vocabulary in a structured way. This one-stop app shows all the details of a word — meaning, example sentences, grammar forms and synonyms — so learners can pick it up in a practical way.` | ✅ |
| `The app has {n} common Dutch words, grouped by level:` | ✅ |
| `{n} core everyday words.` | ✅ |
| `{n} popular words.` | ✅ |
| `{n} words` | ✅ |
| `General` | Literal (bold label on the General source line) |
| `App language` | ✅ |
| `Some languages may not be fully translated. English is used where a translation is missing.` | ✅ |
| `Could not load this language — check your connection and try again.` | ✅ (toast) |
| `English` `Français` `Italiano` `Español` `Deutsch` `Português` `Polski` `Türkçe` `Українська` `Русский` `Български` | Literal (endonyms; `aria-label`/`title` only) |
| `EN FR IT ES DE PT PL TR UK RU BG` | Literal (visible chip text) |
| `Theme` | ✅ |
| `Minimalistic` `Midnight` `Sepia` | Literal (`aria-label`/`title` only; never visible) |
| `Contact us` | EN-only |
| `Subject` | EN-only |
| `General feedback` `Report a problem` `Word or translation error` `Feature request` `Question` `Other` | EN-only |
| `Your email (optional)` | EN-only |
| `you@example.com` | EN-only (placeholder) |
| `Only if you would like a reply. We will use it just to get back to you.` | EN-only |
| `Message` | EN-only |
| `What would you like to tell us?` | EN-only (placeholder) |
| `Send` | EN-only |
| `Sending…` | EN-only |
| `Please enter a message before sending.` | EN-only |
| `Please enter a single valid email address.` | EN-only |
| `Please enter a valid email address.` | EN-only |
| `Please use a permanent email address, not a temporary one.` | EN-only |
| `Thanks! Your message has been sent.` | EN-only (toast) |
| `Could not send right now. Please check your connection and try again.` | EN-only |
| `Could not send your message.` | EN-only (toast) |

### 5.10 Strings present in the dictionaries but unreachable (dead)

These 12 keys are translated in all 10 languages but no code path renders them. They are
leftovers from removed features. A rebuild may drop them, but should not be surprised to
find them in the exported dictionary file.

`Shuffle On`, `Shuffle Off`, `No words left in this round with these filters.`,
`Today's plan`, `Set a daily goal`, `Your deck`, `Backup`,
`Your progress lives in this browser. Export a backup before switching phones, then import it there.`,
`Export`, `Import`, `Change how the whole app looks. Your words and progress stay exactly the same.`,
`Meanings, example translations and menus switch to your language — the Dutch words stay Dutch.`,
`Study only new words — skip reviews`, plus the three theme `desc` strings
(`Mondrian grid — …`, `Dark mobile app — …`, `Printed book — …`).

Two keys are reachable only through dead code paths (`importData()` is defined but wired to
no UI): `Progress imported` and `Import failed — not a valid backup file`.

### 5.11 Hardcoded English that bypasses `T()` entirely

These strings are emitted by the dormant AI-enrichment code paths (§9.3) and are **not**
localisable at all — flag them if that feature is ever re-enabled:

| String | Where |
|---|---|
| `API key saved on this device` | `saveKey()` toast |
| `Add your Anthropic API key first` | `enrichBulk()` toast |
| `All words already have full details!` | `enrichBulk()` toast |
| `Preparing words… ` + counter | `enrichBulk()` button label |
| `Prepared {n} words with full details` | `enrichBulk()` toast |
| `Prepared {n} before an error — tap again to continue` | `enrichBulk()` toast |
| `Failed — check your API key and credit` | `enrichBulk()` toast |
| `dutch-to-go-backup.json` | `exportData()` download filename |
| `Dutch To Go — {subject}` | Contact email subject line |
| `(not provided)` | Contact payload when no email is given |

### 5.12 Localisation recommendations for the rebuild

1. The 57 EN-only strings (Contact §5.9, Pro §5.6, Profile §5.5) **should** be moved into
   the dictionaries. They are the newest features and were simply never translated.
2. The `SRC_SHORT` legend labels and the `srcFilterOpts` dropdown labels describe the same
   six sources with **two different typographies** — en dash (`A0–A2`) in legends and badges
   vs. arrow (`A0 → A2`) in the filter dropdown. Both are literals. Unify or keep, but be
   deliberate.
3. `General` appears as a bare literal in the About box but as the translated
   `General 5K` in the source filter. This inconsistency is in the current build.
4. The Contact subject `<option value>` is the **translated** label, so the value posted to
   the email service changes with the UI language. If the rebuild keeps this feature, send a
   stable machine key and localise only the display text.

---

## 6. DATA MODEL

### 6.1 Where data lives

There is **no server and no database.** Two categories:

1. **Bundled content** — read-only, compiled into `public/index.html` as JavaScript literals,
   plus 10 JSON translation packs fetched from `/i18n/<lang>.json` on demand.
2. **User state** — written to `localStorage` through a thin adapter, under 17 distinct keys,
   all JSON-encoded.

**6.1.1 The `Store` adapter.** Every read and write goes through it. It prefers a global
`window.storage` object when one exists (the Claude-artifact host environment) and falls back
to `localStorage`. Both paths JSON-encode values, so `localStorage.getItem('dutch5k-theme')`
returns the string `"midnight"` **including the quotes**.

```
Store.hasClaude = (typeof window.storage !== 'undefined')

Store.get(key):
    if hasClaude:  r = await window.storage.get(key)
                   return r ? JSON.parse(r.value) : null      # any throw → null
    v = localStorage.getItem(key)
    return v ? JSON.parse(v) : null                            # any throw → null

Store.set(key, value):
    if hasClaude:  await window.storage.set(key, JSON.stringify(value))   # throw → console.error
                   return
    localStorage.setItem(key, JSON.stringify(value))
    on throw: toast(T('Storage full — export your progress'))
```

Every getter falls back to a default with `|| default`, so a missing or corrupt key is
indistinguishable from a fresh install and never throws.

### 6.2 Persisted keys — complete inventory

| # | Key | Value shape | Default when absent | Written by |
|---|---|---|---|---|
| 1 | `dutch5k-progress` | `{ "__v2": true, "<entryId>": "learned" \| "learning" }` — an entry is **deleted** from the map when graded "again" | `{__v2:true}` | `mark`, `setWordStatus`, `migrate`, `importData` |
| 2 | `dutch5k-srs` | `{ "<entryId>": {due, iv, ef, reps, lapses, last} }` (§6.3.2) | `{}` | `mark`, `setWordStatus` |
| 3 | `dutch5k-enriched` | `{ "<entryId>": {w, t, m, f, ex, a?, syn?, ant?} }` — AI-generated overlay | `{}` | `enrichWords`, `migrate`, `importData` |
| 4 | `dutch5k-streak` | `{count:int, lastStudied:"YYYY-MM-DD"\|null, history:{"YYYY-MM-DD":int}}` | `{count:0, lastStudied:null, history:{}}` | `recordLearned` |
| 5 | `dutch5k-plan` | `{perDay:int, endDate:"YYYY-MM-DD"\|null, startDate:"YYYY-MM-DD"}` or `null` | `null` | `savePlan`, `clearPlan` |
| 6 | `dutch5k-wordgoal` | positive integer, or `null` for "the whole deck" | `null` | `setWordGoal`, `clearWordGoal` |
| 7 | `dutch5k-goalmode` | `"count"` \| `"source"` | `"count"` | `setGoalMode` |
| 8 | `dutch5k-goalsources` | array of source ids | `[]` | `toggleGoalSource` |
| 9 | `dutch5k-remind` | boolean | `false` | `enableReminders` |
| 10 | `dutch5k-remindtime` | `"HH:MM"` 24-hour | `"19:00"` | `setRemindTime` |
| 11 | `dutch5k-theme` | `"minimalistic"` \| `"midnight"` \| `"sepia"` | `"minimalistic"` | `setTheme` |
| 12 | `dutch5k-lang` | one of the 11 `LANGS` ids | `"en"` | `setLang` |
| 13 | `dutch5k-shuffle` | boolean | `false` | `pickLearnOpt`, `toggleShuffle` |
| 14 | `dutch5k-newonly` | boolean | `false` | `pickLearnOpt`, `toggleNewOnly`, `startReview`, `drillLeeches` |
| 15 | `dutch5k-mode` | one of the six `LEARN_MODES` ids | `"cards"` | `setMode` |
| 16 | `dutch5k-pro` | boolean | `false` | `buyPro`, `cancelPro`, `signOut`, `_signInWith` |
| 17 | `dutch5k-accounts` | `{ "<email>": Account }` (§6.3.3) | `{}` | `persistAccounts` |
| 18 | `dutch5k-account` | the signed-in email string, or `null` | `null` | `persistAccounts` |
| 19 | `dutch5k-device` | `"d_" + random base-36 + Date.now() base-36` | generated on first run and immediately persisted | `init` |
| 20 | `dutch5k-apikey` | string | `""` | `saveKey` (**no UI writes this — dead**) |
| 21 | `dutch5k-words` | legacy array of enriched word objects | — | **read-only**, consumed once by `migrate()` and never written |

**Not persisted (session-only, reset on reload):** `tab`, `queue`, `qPos`, `flipped`,
`objResult`, `leechOnly`, `skipped`, `statusSel`, `posFilter`, `srcFilter`, `learnPos`,
`learnSrc`, `search`, `listLimit`, `wordView`, `wordViewStack`, `wordListScrollY`,
`wordOrigin`, `authMode`, `menuOpen`, `menuSections`.

**Validation on load:** `learnMode` falls back to `cards` if not a known mode id; `lang`
falls back to `en` if not a known language id; `theme` falls back to `minimalistic` inside
`applyTheme` if not a known theme id. Nothing else is validated.

### 6.3 Entity definitions

**6.3.1 `DeckEntry`** — the central entity. 6,752 instances, built in memory at startup.

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Stable primary key. **Three id schemes**, see §6.4 |
| `w` | string | yes | The Dutch headword, as displayed (may be multi-word) |
| `rank` | int | yes | Corpus frequency position, 1 = most frequent. **`0` means "not in the frequency list"** and sorts last (treated as 99999 by every sort) |
| `t` | string | no | Part of speech. Observed values: `verb, noun, adjective, adverb, pronoun, preposition, conjunction, number, expression, article, particle, other` |
| `a` | string | no | Grammatical article for nouns: `"de"` or `"het"` |
| `m` | string | no | English meaning. May contain several senses separated by `; ` or `, ` |
| `rich` | boolean | yes | True when the entry has example sentences (drives the full card layout) |
| `hasMeaning` | boolean | yes | True when `m` is set |
| `f` | array of `[label, value]` | no | Grammar forms |
| `syn` | array of string | no | Dutch synonyms |
| `ant` | array of string | no | Dutch antonyms |
| `ex` | array of `[dutch, english]` | no | Example sentences |
| `books` | array of `{src, ch}` | no | Textbook memberships; `src` ∈ `gang, actie, niveau, perfectie`, `ch` = chapter number |
| `srcTags` | array of string | yes | Filterable source tags; `essential, general, gang, actie, niveau, perfectie` |
| `essentialDict` | boolean | no | Marks the 484 dictionary-sourced Essential words |
| `src` | string | no | Vestigial; set only on book-only entries at creation |

**Field-presence counts across the 6,752 entries:**

| Property | Count |
|---|---|
| Total entries | **6,752** |
| `rich` | 6,729 |
| `hasMeaning` | 6,583 |
| neither rich nor hasMeaning | **23** (all known extraction artifacts, listed in §12.6) |
| `rich` but no `m` | 31 |
| has `ex` | 6,729 |
| has `f` | 897 |
| has `syn` | 849 |
| has `ant` | 488 |
| has `a` (de/het) | 1,176 |
| `id` contains `\|` (curated/homograph scheme) | 115 |
| `id` starts `book:` | 1,772 |
| `id` starts `essential:` | 484 |
| free in the Free plan | **850** |

**Part-of-speech distribution:** none 3,872 · noun 1,251 · verb 638 · expression 463 ·
adjective 318 · adverb 119 · pronoun 47 · conjunction 18 · preposition 16 · number 4 ·
article 3 · other 2 · particle 1.

**Source-tag distribution** (a word may carry more than one book tag, so these sum above
6,752): general 2,365 · essential 1,484 · actie 1,214 · gang 946 · niveau 499 ·
perfectie 368.

**Chapter coverage:** gang 1–18 · actie 1–11 · niveau 1–6 · perfectie 1–8.

**6.3.2 `SrsRecord`** — one per graded word, keyed by `DeckEntry.id`.

| Field | Type | Meaning | Initial |
|---|---|---|---|
| `due` | `"YYYY-MM-DD"` | Next review date. Compared **lexicographically** against today — safe because the format is fixed-width and zero-padded | today |
| `iv` | int | Current interval in days | `0` |
| `ef` | float | SM-2 ease factor, floored at `1.3` | `2.5` |
| `reps` | int | Consecutive successful recalls; reset to 0 on a lapse | `0` |
| `lapses` | int | Lifetime count of "Again" grades. `≥ 2` makes the word a "leech" | `0` |
| `last` | `"YYYY-MM-DD"` | Date last graded | today |

**6.3.3 `Account`** — one per email, in the local `accounts` directory.

| Field | Type | Meaning |
|---|---|---|
| `id` | string | `"u_" + Date.now().toString(36)` |
| `name` | string | Display name; defaults to the local part of the email |
| `email` | string | Lower-cased; the primary key |
| `provider` | `"google"` \| `"email"` | Which flow created or last used it |
| `createdAt` | `"YYYY-MM-DD"` | |
| `pro` | boolean | The Pro entitlement lives here, not on the device |
| `session` | `{device:string, at:int}` \| `null` | Single-active-session marker (§7.14) |

**6.3.4 `Plan`, `Streak`** — see keys 4 and 5 in §6.2.

### 6.4 Entry id schemes — the critical invariant

**Never change these without writing a migration. Breaking ids silently destroys all user
progress**, because `progress`, `srs` and `enriched` are all keyed by `id`.

| Scheme | Format | Used for | Count |
|---|---|---|---|
| Typed | `"<word lowercased>\|<type>"` | Curated/enriched entries. Exists so homographs cannot collide (e.g. `eten` the verb vs. `eten` the noun) | 115 |
| Bare | `"<word lowercased>"` | Frequency stubs (the common case) | 4,381 |
| Book | `"book:<src>:<word lowercased>"` | Words that appear only in a textbook, not in the frequency list | 1,772 |
| Essential-dictionary | `"essential:<word lowercased>"` | The 484 dictionary-sourced Essential additions | 484 |

`entryId(e)` implements the first two: `e.t ? e.w.toLowerCase() + '|' + e.t : e.w.toLowerCase()`.

Two historical schemes are handled by `migrate()` (§7.15).

### 6.5 Source data blobs (compiled into `index.html`)

These are the **inputs** to the build. The **output** — the assembled deck — is the attached
dataset. A rebuild only needs the output.

| Const | Type | Records | Schema |
|---|---|---|---|
| `FREQ` | array of string | 5,000 | Dutch words in corpus-frequency order (from Python `wordfreq`). Index + 1 = rank |
| `SEED` | array of object | 115 | Hand-curated rich entries: `{w, t, m, f, ex, syn?, ant?, a?}` |
| `TRANS` | object | 3,887 | `word → {m, t?}` — offline English glosses (FreeDict NL-EN + lemmatisation + manual fixes) |
| `BOOKS` | array of object | 2,233 at declaration, **3,105 after merges** | `{w, src, ch, t?, a?, m?, f?, syn?, ant?, ex?, rich?}` |
| `NIVEAU` | array of object | 501 | Same shape, `src:"niveau"`; pushed into `BOOKS` at load |
| `PERFECTIE` | array of object | 371 | Same shape, `src:"perfectie"`; pushed into `BOOKS` at load |
| `BOOKEX` | object | 1,211 | `"<src>:<word lowercased>" → [[nl,en],…]` or `{m?, t?, a?, ex}` |
| `GENEX` | object | 3,545 | `"<word lowercased>" → [[nl,en],…]` or `{m?, ex?}` (object `m` **overrides** a wrong `TRANS` gloss) |
| `JUNK` | Set of string | 515 | Corpus noise dropped from `FREQ` entirely: proper names, brands, foreign places, standalone abbreviations, English tokens |
| `ESSENTIAL` | array of object | 484 | `{w, t, a?, m, ex}` — dictionary-sourced Essential additions |
| `UI` | object | 10 languages × 214 keys | UI translations |

### 6.6 Bundled dataset — the attached file

**File:** `dutch-to-go-deck-v110.json`
**Record count exported: 6,752** — verified equal to `deck.length` at runtime.

Top level:

```json
{
  "schemaVersion": 1,
  "generatedFrom": "public/index.html @ v110",
  "recordCount": 6752,
  "freeIdCount": 850,
  "records": [ … 6752 DeckEntry objects … ]
}
```

Each record uses the `DeckEntry` schema of §6.3.1, plus one derived field
**`freeInFreePlan`** (boolean) recording whether `computeFree()` (§7.4) unlocked it for
Free users. Records appear in **deck order**, which is also the natural build order:
frequency 1…5000 (minus junk), then curated non-frequency entries, then book-only entries,
then dictionary Essential entries.

Sample records (three of 6,752):

```json
{
  "id": "de|article", "w": "de", "rank": 1, "srcTags": ["general"],
  "t": "article", "m": "the (common gender)", "rich": true, "hasMeaning": true,
  "ex": [["De trein komt eraan.", "The train is coming."],
         ["Waar is de auto?", "Where is the car?"]],
  "freeInFreePlan": true
}
```

```json
{
  "id": "bereiken", "w": "bereiken", "rank": 898, "srcTags": ["actie"],
  "t": "verb", "m": "to reach, to achieve, to attain; to get in touch with someone",
  "rich": true, "hasMeaning": true,
  "f": [["Present", "ik bereik, hij bereikt"], ["Past", "bereikte / bereikten"],
        ["Perfect", "heeft bereikt"]],
  "syn": ["halen", "verwezenlijken"], "ant": ["mislopen", "falen"],
  "ex": [["Na drie uur wandelen bereikten we eindelijk de top.",
          "After three hours of hiking we finally reached the summit."],
         ["Ik heb geprobeerd hem te bellen, maar ik kon hem niet bereiken.",
          "I tried calling him but I couldn't get through to him."]],
  "books": [{"src": "actie", "ch": 1}],
  "freeInFreePlan": false
}
```

```json
{
  "id": "book:actie:een hekel hebben aan iets", "w": "een hekel hebben aan iets",
  "rank": 0, "srcTags": ["actie", "niveau"], "t": "expression",
  "m": "to hate/dislike something; to have an aversion to something",
  "rich": true, "hasMeaning": true,
  "syn": ["een afkeer hebben van iets"],
  "ex": [["Ik heb echt een hekel aan vroeg opstaan op maandag.",
          "I really hate getting up early on Monday."],
         ["Ze heeft een hekel aan mensen die altijd te laat komen.",
          "She can't stand people who are always late."]],
  "books": [{"src": "actie", "ch": 1}, {"src": "niveau", "ch": 2}],
  "freeInFreePlan": false
}
```

### 6.7 Content translation packs

**Location:** `/i18n/<lang>.json`, one per non-English language. Fetched lazily by
`loadLangDict(id)` on first use, memoised in `CTCACHE`, and runtime-cached by the service
worker (so a language stays available offline after being picked once).

**Shape:** a flat object mapping the **exact English source string** to its translation:

```json
{ "the (common gender)": "le (sexe commun)",
  "of, from": "des, de",
  "the (neuter); it": "le (neutre), C'est" }
```

Keys cover every word meaning and every example-sentence English translation in the built
deck. A missing key falls back to English via `ct(s)` — so partial coverage is safe by
design, never an error.

| Language | Entries | Raw size |
|---|---|---|
| bg | 12,179 | 1,182,880 B |
| ru | 12,343 | 1,224,999 B |
| uk | 12,278 | 1,189,216 B |
| pt | 11,923 | 900,676 B |
| de | 11,875 | 932,334 B |
| pl | 11,874 | 884,812 B |
| it | 11,790 | 910,456 B |
| fr | 11,690 | 923,651 B |
| es | 11,468 | 878,079 B |
| tr | **9,201** | 768,461 B — weakest coverage; Turkish falls back to English most often |

**Gotcha:** a *missing* pack file does **not** 404 under the SPA fallback — the server
returns `index.html` with HTTP 200, `r.json()` throws, and `setLang` toasts
`T('Could not load this language — check your connection and try again.')`. Always ship the
pack file alongside its `LANGS` entry.

### 6.8 UI string dictionaries — the attached file

**File:** `dutch-to-go-ui-strings-v110.json`. Contains `englishKeys` (the 214 canonical
English source strings, sorted) and `translations` (an object of 10 language codes, each
with all 214 keys — verified key parity). English is never a dictionary: `T()` returns the
key itself.

### 6.9 Persistence across sessions

- All user state survives a reload, a browser restart and going offline.
- All user state is destroyed by: clearing site data, using a private window, or switching
  browser or device. There is **no** export path wired to the UI (the `exportData()` /
  `importData()` functions still exist in the source but no button calls them), so a user
  currently has **no supported way to back up or move their progress**.
- The account layer does **not** protect progress. Signing in does not upload anything;
  signing out leaves progress on the device (the toast says so explicitly).

---

## 7. LOGIC AND ALGORITHMS

All pseudocode below is language-agnostic. Constants shown are the literal values in the
shipped build.

### 7.1 Deck construction (`buildDeck`)

Runs at startup, and again after migration, and again after an import. It is fully
deterministic — same inputs, same 6,752 entries in the same order.

```
function buildDeck():
    deck = []; byId = {}
    seedByWord = group SEED by lowercase(w)      # a word may have several typed seeds
    placed = empty set

    # -- Pass 1: the frequency list, in rank order ------------------------
    for i, w in FREQ:                            # i is 0-based
        if JUNK contains w: continue             # 515 words dropped entirely
        if seedByWord has w:
            for each seed s in seedByWord[w]:
                e = { rank: i+1, rich: true, ...s }
                e.id = entryId(e)                # "word|type"
                append e to deck; byId[e.id] = e
            add w to placed
        else:
            e = { w: w, rank: i+1, id: w, rich: false }
            t = TRANS[w]
            if t and t.m:  e.m = t.m; if t.t: e.t = t.t; e.hasMeaning = true
            append e to deck; byId[e.id] = e

    # -- Pass 2: curated entries not present in FREQ (multiword etc.) -----
    for each seed s in SEED:
        if placed contains lowercase(s.w): continue
        e = { rank: 0, rich: true, ...s }; e.id = entryId(e)
        if byId has no e.id: append e to deck; byId[e.id] = e

    # -- Pass 3: the persisted AI-enrichment overlay ----------------------
    for each id in enriched:
        if byId[id] exists:  merge enriched[id] into it; set rich = true
        else:                create { rank:0, rich:true, id, ...enriched[id] } and append

    # -- Pass 4: merge textbook vocabulary --------------------------------
    for each b in BOOKS:                         # 3,105 after NIVEAU + PERFECTIE are pushed in
        lw = lowercase(b.w)
        target = byId[b.t ? lw+"|"+b.t : lw] or byId[lw]
                 or first deck entry whose lowercase(w) == lw
        if target:
            append {src:b.src, ch:b.ch} to target.books
            if b.rich AND NOT target.rich:
                copy m,f,syn,ant,ex,t,a from b onto target (only the fields b has)
                target.rich = true; target.hasMeaning = true
            else if NOT target.rich AND NOT target.hasMeaning AND b.m:
                target.m = b.m; target.hasMeaning = true
                if b.t and not target.t: target.t = b.t
                if b.a and not target.a: target.a = b.a
        else:
            e = { w:b.w, rank:0, id:"book:"+b.src+":"+lw, src:b.src,
                  rich:false, books:[{src:b.src, ch:b.ch}] }
            copy a, t; if b.m: e.m = b.m, e.hasMeaning = true
            if b.rich: copy f,syn,ant,ex; e.rich = true; e.hasMeaning = true
            if enriched has e.id: merge it; rich = hasMeaning = true
            append e to deck; byId[e.id] = e

    # -- Pass 5: BOOKEX overlay (examples, sometimes meanings) ------------
    for each b in BOOKS:
        spec = BOOKEX["<b.src>:<lowercase(b.w)>"];  if none: continue
        ex = isArray(spec) ? spec : spec.ex
        ent = byId[typed] or byId[bare] or byId["book:src:word"]
              or first deck entry with that word AND that book src
        if none: continue
        if spec is an object:
            if spec.m and ent has no m: ent.m = spec.m
            if spec.t and ent has no t: ent.t = spec.t
            if spec.a and ent has no a: ent.a = spec.a
        if ex is non-empty AND ent has no examples: ent.ex = ex
        if ent.m:  ent.hasMeaning = true
        if ent.ex: ent.rich = true

    # -- Pass 6: GENEX overlay (general, non-book words) ------------------
    for each w in GENEX:
        ent = byId[w] or first deck entry with that word AND no book memberships
        if none: continue
        spec = GENEX[w];  ex = isArray(spec) ? spec : spec.ex
        if spec is an object AND spec.m:  ent.m = spec.m      # UNCONDITIONAL override
        if ex is non-empty AND ent has no examples: ent.ex = ex
        if ent.m:  ent.hasMeaning = true
        if ent.ex: ent.rich = true

    # -- Pass 7: dictionary-sourced Essential words -----------------------
    for each x in ESSENTIAL:
        lw = lowercase(x.w)
        if byId[lw] or byId[lw+"|"+x.t] or any deck entry with that word: continue
        e = { w:x.w, rank:0, id:"essential:"+lw, rich:true, hasMeaning:true,
              essentialDict:true, t:x.t, m:x.m }
        copy a and ex if present
        append e to deck; byId[e.id] = e

    # -- Pass 8: primary source tags --------------------------------------
    for each e in deck:
        if e.books is non-empty:   e.srcTags = distinct list of e.books[*].src
        else if e.essentialDict:   e.srcTags = ["essential"]
        else:                      e.srcTags = ["general"]

    # -- Pass 9: carve the Essential core out of General -------------------
    ESSENTIAL_N = 1000
    take every deck entry with NO book memberships AND hasMeaning,
      sort ascending by (rank or 99999),
      take the first ESSENTIAL_N,
      set each one's srcTags = ["essential"]        # replaces ["general"] — NOT additive

    computeFree()
```

**Key consequences to preserve:**
- Essential and General are **disjoint** — a word is one or the other, never both, so their
  counts never double-count. Final Essential = 1,000 frequency-core + 484 dictionary = 1,484.
- Pass 6 overrides meanings unconditionally, which is how ~264 wrong FreeDict homograph
  glosses were corrected (e.g. `kan` → "can" not "jug", `waar` → "where" not "authentic",
  `tel` → "count" not "esteem").
- A word can carry several book tags; the resulting card shows every chapter, joined by ` · `.

### 7.2 Source membership (`inSource`)

```
inSource(entry, src):
    if src == "all": return true
    return entry.srcTags contains src        # purely tag-based; no special cases
```

### 7.3 Primary source attribution (`primarySource`)

Used **only** by the stacked "By word type" bars, where segment widths must sum exactly to
the row's learned total. Unlike `inSource`, it picks exactly one source per word.

```
primarySource(entry):
    if entry has no book memberships:
        return entry.srcTags contains "essential" ? "essential" : "general"
    for s in ["gang", "actie", "niveau", "perfectie"]:      # this order is the taxonomy
        if entry.srcTags contains s: return s
    return "general"
```

### 7.4 Free-plan entitlement (`computeFree`)

```
FREE_LIMITS = { essential:150, general:500, gang:200, actie:0, niveau:0, perfectie:0 }

computeFree():
    freeIds = empty set
    buckets = { essential:[], general:[], gang:[], actie:[], niveau:[] }
                                     # NOTE: no "perfectie" bucket exists at all
    for each entry e in deck:
        for each tag t in e.srcTags:
            if buckets has t: append e to buckets[t]
    for each src in buckets:
        cap = FREE_LIMITS[src] or 0
        if cap <= 0: continue                            # actie and niveau contribute nothing
        sort buckets[src] ascending by (rank or 99999)   # rank 0 sorts last
        take the first `cap` entries; add each id to freeIds

isLocked(entry) = (NOT isPro) AND entry exists AND freeIds does not contain entry.id
```

Result: **850 free ids**. A word is free if it falls under the cap of **any** of its
sources, so a word shared between A0–A2 (cap 200) and A2–B1 (cap 0) is still reachable via
A0–A2. Because of that overlap the free set breaks down as essential 150, general 500,
gang 200, plus 4 words that also carry an `actie` tag and 2 that also carry a `niveau` tag.
The `perfectie` source can never be free.

### 7.5 Free-first ordering (`freeFirst`)

```
freeFirst(orderedIndices):
    if isPro OR length < 2: return unchanged
    partition into free[] and locked[] preserving relative order
    if either partition is empty: return unchanged
    return free ++ locked
```

Order **within** each partition is preserved (a plain rank sort would not do — a low-rank
locked General word could otherwise jump ahead of a free A0–A2 book word). Applied in two
places: the Learn queue's fresh segment when shuffle is **off**, and the Words list before
the `listLimit` slice.

### 7.6 Spaced repetition (SM-2-lite)

```
GRADES:  again = 0,  learning = 1,  know-it = 2,  easy = 3   # 3 is defined but never sent

scheduleSrs(id, grade):
    today = local date as "YYYY-MM-DD"
    s = srs[id] or { iv:0, ef:2.5, reps:0, lapses:0 }

    if grade <= 0:                                     # a lapse
        s.lapses += 1
        s.reps = 0
        s.iv = 0
        s.ef = max(1.3, s.ef - 0.2)
        s.due = today                                  # comes back this session / today
    else:
        if   s.reps == 0:  s.iv = 1                    # first correct recall → tomorrow
        elif s.reps == 1:  s.iv = (grade >= 2) ? 4 : 2
        else:              s.iv = max(1, round(s.iv * s.ef *
                                        (grade == 1 ? 0.5 : grade >= 3 ? 1.3 : 1.0)))
        s.reps += 1
        q = grade + 2                                  # map grades 1..3 to SM-2 quality 3..5
        s.ef = max(1.3, s.ef + (0.1 - (5-q) * (0.08 + (5-q) * 0.02)))
        s.due = today + s.iv days
    s.last = today
    srs[id] = s
```

Worked ease-factor deltas: quality 5 (grade 3, easy) → **+0.10**; quality 4 (grade 2,
know it) → **0.00**; quality 3 (grade 1, learning) → **−0.14**; a lapse → **−0.20**. Floor
1.3, no ceiling.

```
isDue(id):
    s = srs[id]
    if s exists: return s.due <= today          # lexicographic string comparison
    p = progress[id]
    return p == "learning" OR p == "learned"    # legacy pre-SRS words are due immediately

dueCount():
    count entries where progress is learning/learned AND isDue(id)

leeches():
    all deck indices whose srs record has lapses >= 2,
    sorted by lapses DESCENDING (hardest first)
```

`addDays` uses `new Date(dateStr + 'T00:00:00')` — i.e. **local** midnight — then
`setDate(getDate()+n)`, which handles month and year rollover and DST automatically.

### 7.7 Study-queue construction (`buildQueue`)

```
buildQueue():
    due = []; notDue = []; fresh = []
    leechIds = leechOnly ? set of leech ids : null

    for each index i, entry e in deck:
        if learnPos is non-empty AND learnPos does not contain lowercase(e.t): skip
        if learnSrc is non-empty AND no s in learnSrc has inSource(e, s):     skip
        if NOT modeEligible(e):                                              skip
        if leechIds AND leechIds lacks e.id:                                 skip
        status = progress[e.id]
        if status is "learning" or "learned":
            (isDue(e.id) ? due : notDue).append(i)
        else if NOT leechOnly:
            fresh.append(i)                    # never introduce new words during a drill

    sort due ascending by (srs[id].due or "0000-00-00")     # most overdue first

    if learnShuffle:
        # Efraimidis–Spirakis weighted sampling: common words still surface first on
        # average, but every rebuild draws a different set; rare words rarely jump ahead.
        for each i in fresh: key[i] = random()^log2((deck[i].rank or 6000) + 2)
        sort fresh by key DESCENDING
    else:
        sort fresh ascending by (deck[i].rank or 99999)
        fresh = freeFirst(fresh)

    if newOnly:
        queue = fresh                          # every due review is held back; NO fallback
    else:
        queue = due ++ fresh
        if queue is empty: queue = notDue      # never leave the deck needlessly empty

    if skipped is non-empty:
        move every index present in `skipped` to the back, preserving relative order

    qPos = 0; flipped = false; objResult = null
```

**Mode eligibility:**

```
modeEligible(e):
    reverse | type | listen  →  e.m exists AND (e.rich OR e.hasMeaning)
    cloze                    →  clozePick(e) is not null
    dehet                    →  e.a == "de" OR e.a == "het"
    cards (default)          →  true
```

**Skip:**
```
skipCard():
    idx = queue[qPos]
    add idx to `skipped`
    remove queue[qPos]; append idx to the end of queue
    if qPos >= queue.length: qPos = 0
    flipped = false; objResult = null; render
```
`skipped` is cleared on a mode change, a shuffle/new-only toggle, `startReview`,
`drillLeeches` and `exitDrill` — but **not** on a filter change via `applyDrop`… actually it
**is**: `applyDrop` resets `skipped` for every Learn-side dropdown.

### 7.8 Grading (`mark`)

```
mark(status):                          # status ∈ "again" | "learning" | "learned"
    e = deck[queue[qPos]]
    wasLearned = (progress[e.id] == "learned")
    if status == "again":  delete progress[e.id]        # falls back to "new"
    else:                  progress[e.id] = status
    progress.__v2 = true
    scheduleSrs(e.id, status=="again" ? 0 : status=="learning" ? 1 : 2)
    persist progress; persist srs
    if status == "learned" AND NOT wasLearned:  recordLearned()
    qPos += 1; flipped = false; objResult = null
    if qPos >= queue.length: buildQueue()               # a fresh round starts automatically
    render
```

`setWordStatus(idx, status)` (used by the Words detail card) is identical except that it
does **not** advance a queue position; it rebuilds the queue and re-renders in place.
It also calls `recordLearned()` **without** the `wasLearned` guard, so re-marking an
already-learned word from the detail card increments today's count again.

### 7.9 Streak and daily plan

```
todayStr()  = local date as "YYYY-MM-DD" (zero-padded)
daysBetween(a, b) = round((Date(b) - Date(a)) / 86400000)

recordLearned():
    if no streak object: streak = {count:0, lastStudied:null, history:{}}
    t = todayStr()
    streak.history[t] += 1
    if streak.lastStudied != t:
        if streak.lastStudied exists AND daysBetween(lastStudied, t) == 1: streak.count += 1
        elif streak.lastStudied is null OR daysBetween(lastStudied, t) > 1: streak.count = 1
        streak.lastStudied = t
    elif streak.count == 0:
        streak.count = 1; streak.lastStudied = t
    persist streak
    if a plan exists AND streak.history[t] == plan.perDay:
        vibrate 30 ms; toast "🎉 Daily goal reached: {perDay} words!"      # fires exactly once

todayCount()    = streak.history[todayStr()] or 0
currentStreak() = (streak.lastStudied is null) ? 0
                : let d = daysBetween(lastStudied, today)
                  return (d == 0 or d == 1) ? streak.count : 0
```

**Edge cases:** the streak survives one missed day of *display* (`d == 1` still shows the
count) but a second consecutive miss shows 0 while `streak.count` in storage is unchanged —
the next `recordLearned` then resets it to 1 because `daysBetween > 1`. Learning a word for
the second time (already `learned`) does **not** increment the history from the Learn card
(guarded by `wasLearned`) but **does** from the Words detail card.

**Daily goal used by the plan progress bar:**
```
goalN = plan.perDay
     or (plan.endDate ? ceil(max(0, goalTotal - goalLearned)
                             / max(1, daysBetween(today, plan.endDate)))
                      : 10)                     # 10 is the final fallback
barPct = min(100, round(todayCount / goalN * 100))
```

### 7.10 Learning goal

```
goalSourceList()   = goalSources filtered to those that are "general" or have chapters
goalSourceCounts() = one pass over the deck; an entry counts ONCE if ANY selected source
                     matches (so overlapping sources never double-count)
                     → { total, learned }

goalTotal():
    d = deck.length or 5000
    if goalMode == "source":  t = goalSourceCounts().total;  return t or d
    return (wordGoal > 0) ? min(wordGoal, d) : d

goalLearned(counts):
    return goalMode == "source" ? goalSourceCounts().learned : counts.learned

setWordGoal(n):
    n = parseInt(n, 10)
    if n is falsy or n < 1: toast "Enter how many words you want to learn."; return
    wordGoal = min(n, deck.length); persist; render; toast "Goal set: {n} words."
```

The header counter, the "Of {goal} goal" percentage, the goal-box readout and the study
plan's remaining-word maths all read `goalLearned` / `goalTotal`, so switching to source
mode rescopes **both** numerator and denominator coherently. The percentage is capped at
100 and rendered to one decimal.

### 7.11 Search relevance (`searchScore`)

Applies only when the query is non-empty. Filtering is a plain case-insensitive substring
match over three fields — the Dutch word, the English meaning, and the translated meaning —
and then results are **re-ordered** by relevance. Every match still appears; only the
sequence changes.

```
wordBoundary(q) = regex  (^|[^a-zÀ-ɏ]) <escaped q> ($|[^a-zÀ-ɏ])   case-insensitive
                  # the class is a-z plus Unicode U+00C0–U+024F (Latin + diacritics)

searchScore(e, q):                      # lower is better
    best = 9
    for f in [e.w, e.m or "", (a content pack is loaded ? ct(e.m) : "")]:
        f = lowercase(f)
        if f is empty or does not contain q: continue
        if   f == q:                  sc = 0     # exact field match
        elif f starts with q:         sc = wordBoundary(q) matches f ? 1 : 3
        elif wordBoundary(q) matches: sc = 2     # whole word somewhere inside
        else:                         sc = 4     # mid-word substring
        best = min(best, sc)
    return best

sort matches ascending by score, using a STABLE sort so corpus-frequency order
survives inside each relevance tier; then apply freeFirst(); then slice to listLimit
```

### 7.12 Answer checking

```
normalizeAns(s):
    lowercase
    Unicode NFD decompose, then strip all combining marks U+0300–U+036F
    collapse runs of whitespace to a single space, trim
    strip a leading "de ", "het " or "een "
    strip trailing [.!?,;:]+ , trim

checkAnswer():
    e = current entry
    answer = (learnMode == "cloze" and clozePick(e) exists) ? clozePick(e).answer : e.w
    correct = normalizeAns(input) is non-empty AND equals normalizeAns(answer)
    objResult = { correct, given: raw input, answer }
    vibrate correct ? 12 : 24 ms
```

```
clozeRe(w) = regex  (^|[^\p{L}]) ( <escaped w> ) ($|[^\p{L}])   flags: i, u

clozePick(e):
    for each example sentence in e.ex:
        m = clozeRe(e.w) applied to the Dutch side
        if matched:
            start = m.index + length(m[1]); end = start + length(m[2])
            return { pre:  dutch[0 .. start),
                     answer: dutch[start .. end),
                     post: dutch[end ..],
                     en:   the English side or "",
                     full: the whole Dutch sentence }
    return null                       # this is why the cloze pool is smaller than the deck:
                                      # a conjugated verb rarely contains its own infinitive
```

```
answerDeHet(choice):
    objResult = { correct: choice == e.a, given: choice, answer: e.a }
    vibrate correct ? 12 : 24 ms
# grading: correct → mark("learning")   NOT "learned" (gender alone is not knowing the word)
#          wrong   → mark("again")
```

### 7.13 Email validation (`contactEmailError`)

Returns `""` when acceptable, otherwise a human-readable message. Only ever run on a
**non-empty** value; an empty optional email is accepted as-is.

```
v = trim(raw)
if v matches [\s,;<>()]                        → "Please enter a single valid email address."
                                                  (rejects lists and display names)
split on the single "@";  if not exactly one @ → "Please enter a valid email address."
local part must be:  length <= 64
                     no leading dot, no trailing dot, no ".."
                     only [A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]
domain (lower-cased) must be:  length <= 255
                     matches ^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$
                     (labels of letters/digits/hyphens, at least one dot,
                      TLD of 2+ letters, no leading or trailing hyphen)
if the domain is in CONTACT_DISPOSABLE (39 entries)
                                               → "Please use a permanent email address, not a temporary one."
```

`CONTACT_DISPOSABLE` (verbatim, 39 domains): `mailinator.com, guerrillamail.com,
guerrillamail.info, sharklasers.com, grr.la, 10minutemail.com, 10minutemail.net,
tempmail.com, temp-mail.org, tempmail.net, yopmail.com, yopmail.fr, trashmail.com,
throwawaymail.com, getnada.com, nada.email, maildrop.cc, dispostable.com, fakeinbox.com,
mailnesia.com, mailcatch.com, mohmal.com, mintemail.com, spamgourmet.com, tempinbox.com,
emailondeck.com, moakt.com, tmail.com, discard.email, mailsac.com, inboxkitten.com,
harakirimail.com, spam4.me, einrot.com, burnermail.io, 33mail.com, anonaddy.com,
anonaddy.me`.

The same validator is reused for all three sign-in forms.

### 7.14 Account and single-session logic

```
_signInWith(acc):
    # one active ACCOUNT per device
    if a different account is currently signed in here:
        that account.session = null; write it back to the directory
    # one active DEVICE per account
    tookOver = acc.session exists AND acc.session.device != this deviceId
    acc.session = { device: deviceId, at: now-epoch-ms }
    account = acc; accounts[acc.email] = acc
    isPro = acc.pro                      # the entitlement comes from the account
    persist dutch5k-pro, dutch5k-accounts, dutch5k-account
    authMode = null; buildQueue(); render()
    toast tookOver ? "Signed in as {name}. Signed out of your other device."
                   : "Signed in as {name}."

on startup (init):
    if the restored account's session.device != this deviceId:
        account = null; clear dutch5k-account        # this device was taken over
    if account: isPro = account.pro                  # guests keep the legacy dutch5k-pro flag

signOut():
    account.session = null; write back
    account = null; isPro = false; persist
    toast "Signed out. Your progress stays on this device."
```

Newest login always wins — take-over, never a hard block. Today this is only enforceable
inside one browser (the `accounts` directory is device-local); the `session` field is the
exact hook a future backend would use to enforce it for real.

`buyPro()` requires an account: a guest is routed to the profile sign-up form with the
toast `Create an account or sign in to go Pro.` The drawer's `unlockPro()` does the same,
also closing the drawer first.

### 7.15 Legacy migration (`migrate`)

Runs once between the first and second `buildDeck()` call.

```
# 1. old AI-generated words stored as full deck copies → keep as an enrichment overlay
oldWords = Store.get("dutch5k-words")
if it is an array:
    for each x with a `w`:
        id = x.t ? lowercase(x.w)+"|"+x.t : lowercase(x.w)
        target = byId[id] or byId[lowercase(x.w)]
        useId = target ? target.id : id
        if byId[useId] exists AND is rich: skip        # curated content always wins
        data = { w, t, m, ex: x.ex or [] }
        copy a if present
        if x.f is a non-empty string and not "—":  data.f = [["Forms", x.f]]
        elif x.f is an array:                      data.f = x.f
        copy syn, ant
        enriched[useId] = data
    persist enriched

# 2. old progress keyed by plain word or word|type → re-key onto deck ids
oldProg = Store.get("dutch5k-progress")
if oldProg exists AND has no __v2 marker:
    np = { __v2: true }
    for each key k (skipping "__v2"):
        if byId[k]:                     np[byId[k].id] = value
        elif byId[lowercase(k)]:        np[byId[lowercase(k)].id] = value
        else: find the first deck entry whose lowercase(w) equals the part of k before "|"
              if found: np[thatEntry.id] = value
    progress = np; persist
```

The `__v2` marker is the migration sentinel and must be preserved.

### 7.16 Startup sequence (`init`)

```
1.  read enriched, progress, srs, apiKey, plan, wordGoal, goalMode, goalSources,
    streak, remindOn, remindTime, isPro, accounts
2.  deviceId = stored or newly generated ("d_" + random base36 + now base36); persist it
3.  restore the signed-in account by email; drop it if its session moved to another device
4.  if signed in: isPro = account.pro
5.  read learnShuffle, newOnly, learnMode (validated), theme (applied immediately),
    lang (validated)
6.  applyNavLang()
7.  if lang != "en": start loadLangDict(lang) WITHOUT awaiting — first paint is not blocked;
    when it resolves, set CT and re-render
8.  buildDeck()
9.  await migrate()
10. buildDeck()      # again, so migrated enrichment is applied
11. buildQueue()
12. render()
13. maybeEnrichAhead()          # no-op without an API key
14. scheduleReminder()
15. setTimeout(backgroundFill, 2500)   # no-op without an API key
16. register an "online" listener that retries backgroundFill after 1000 ms
```

A separate synchronous script in `<head>` reads `dutch5k-theme` from `localStorage` **before
first paint** and sets `data-theme` — this is the anti-flash guard. It hard-codes the two
theme ids; keep it in sync with `applyTheme`.

### 7.17 Theme application (`applyTheme`)

```
applyTheme(t):
    if t is not a known theme id: t = "minimalistic"
    theme = t
    if t == "minimalistic": remove the data-theme attribute from <html>
    else:                   set data-theme = t
    bg = t=="midnight" ? "#0d0e15" : t=="sepia" ? "#f3ead6" : "#FFFFFF"
    set (creating if needed) <meta name="theme-color" content=bg>
```

The three paper hexes must stay in sync across three places: the CSS token, the anti-flash
`<head>` script, and this function.

### 7.18 Counting helpers

```
counts():          learned  = entries whose progress == "learned"
                   learning = entries whose progress == "learning"
                   fresh    = deck.length - learned - learning
                   total    = deck.length

countsByPos():     per lowercase part of speech (missing → "other"):
                   { total, learned, bySrc: { primarySource → learned count } }

countsBySource():  buckets = general, essential (if any exist), and every book source
                             that has at least one chapter, in SRC_ORDER
                   for each entry, for each bucket: if inSource(entry, bucket)
                       bucket.total += 1;  if learned, bucket.learned += 1
                   # NOTE: a word in two books counts in BOTH buckets, so the donut's slice
                   # sum can exceed the distinct learned total. That is intentional — it
                   # matches how the source filter presents the data.
```

### 7.19 Boundary conditions worth spelling out

| Situation | Behaviour |
|---|---|
| `deck.length` is 0 | `goalTotal()` falls back to the literal `5000` |
| No source selected in source-goal mode | `goalTotal()` falls back to `deck.length` |
| `goalLearned / goalTotal` exceeds 1 | The percentage is clamped to `100` |
| Learned count is 0 on the Progress tab | Donut renders a single faint full ring with a centre `0`; the strip is all white |
| Filters exclude everything | `queue` is empty → the empty state of §2.1.10 |
| `newOnly` is on and nothing is fresh | Deliberately empty — there is **no** fallback to reviews |
| Every mode-eligible word is not yet due | `notDue` is used as the queue so the deck is never needlessly empty (unless `newOnly`) |
| A leech drill with no leeches | Empty state `No tricky words yet — keep going!` |
| Cloze mode and no example contains the headword | The word is filtered out of the queue by `modeEligible` |
| Cloze fallback if `clozePick` returns null at render time | `{pre:'', answer:e.w, post:'', en:''}` — the blank is the whole prompt |
| `setTimeout` delay for a reminder exceeds 2³¹−1 ms | Clamped to `0x7fffffff` (~24.8 days) |
| A word graded before v82 (no SRS record) | Treated as due immediately |
| Rank 0 (not in the frequency list) | Sorts last everywhere via `rank || 99999`; in the shuffle key it uses `rank || 6000` |

---

## 8. INTERACTIONS

### 8.1 Navigation model

A single-page app with **no routing whatsoever** — no URL fragments, no History API, no
deep links. The current view is a module-level string `tab` plus a nullable `wordView`.

```
tab ∈ { "learn", "words", "progress", "profile" }
```

`setTab(t)` resets `expanded = null`, `wordView = null`, `wordViewStack = []` and
`listLimit = 100`, then re-renders. `render()` dispatches in this order: profile → learn →
words (detail, else list) → progress.

Consequences to reproduce or deliberately change:
- The browser **Back button does not navigate the app** — it leaves the site.
- A reload always returns to the Learn tab (`tab` starts as `"learn"`).
- Nothing is shareable or bookmarkable below the app root.
- The Profile page is reachable only from the header avatar and has no nav highlight.

**Cross-screen jumps:**

| From | Action | Effect |
|---|---|---|
| Progress → Words | Tap a "By word type" row | `posFilter = [thatType]`, then `setTab('words')` |
| Progress → Words | Tap a donut slice or a legend row | `srcFilter = [thatSource]`, `posFilter = []`, then `setTab('words')` |
| Progress → Learn | "Start review" | `leechOnly = false`, `newOnly = false` (persisted); if the mode is `dehet` or `cloze` it is forced back to `cards`; clear skips; rebuild the queue; `setTab('learn')` |
| Progress → Learn | "Drill hardest words" | `leechOnly = true`, `newOnly = false` (persisted), mode forced to `cards`; clear skips; rebuild; `setTab('learn')` |
| Progress → Words | Tap a hardest-word row | `openWord(index)` |
| Profile → Learn | "Study now" | `setTab('learn')` |
| Learn / Words card → Words detail | Tap a synonym or antonym row | `openWord(index, fromLink = true)`; switches to the Words tab |
| Anywhere → Profile | Any Pro CTA while signed out | `closeMenu()`, toast, `setAuthMode('signup')` which forces `tab = 'profile'` |
| Anywhere → drawer | Any lock overlay | `openPro(event)` → opens the drawer, smooth-scrolls the Pro box into view, flashes it for 1500 ms |

**Word-detail back-stack:**

```
openWord(idx, fromLink):
    if wordView is null:                      # this is the START of a chain
        wordOrigin = (tab == "learn") ? "learn" : "words"
        if tab == "words": wordListScrollY = window.scrollY
    if fromLink AND wordView is not null: push wordView onto wordViewStack
    wordView = idx
    if tab != "words": tab = "words"
    render; scrollTo(0, 0)

backFromWord():
    if wordViewStack is non-empty:
        wordView = pop();  render;  scrollTo(0, 0)        # parent card, top-aligned
        return
    wordView = null
    if wordOrigin == "learn":  tab = "learn"; render; scrollTo(0, 0)
    else:                      render; scrollTo(0, wordListScrollY)   # restore list position
```

`listLimit` is deliberately **not** reset by `backFromWord`, so a list that had been
expanded with "Show more" is restored at the same height and the saved scroll offset still
points at the right row.

The Back button's label follows the same rule: `T('Back')` when the stack is non-empty or
the chain started from a flashcard, otherwise `T('Back to list')`.

### 8.2 Animations and transitions — complete inventory

| Element | Property | Duration | Easing | Notes |
|---|---|---|---|---|
| Card flip out (`.card-flip-out`) | `transform` → `perspective(1400px) rotateY(90deg)` | **150 ms** | `ease-in` | `backface-visibility:hidden`. A `setTimeout(150)` swaps the face at the edge-on moment |
| Card flip in (`.card-flip-in`, `@keyframes cardFlipIn`) | `perspective(1400px) rotateY(-90deg)` → `rotateY(0)` | **200 ms** | `ease-out` | `both` fill, `transform-origin: center` |
| Drawer open/close | `transform` | **280 ms** | `ease` | Closing also delays `visibility` by 280 ms (`transition: transform .28s ease, visibility 0s linear .28s`) |
| Scrim | `opacity` | **250 ms** | (default) | |
| Accordion body | `max-height` and `padding` | **280 ms** | `ease` | Open cap is `max-height: 1200px` |
| Accordion arrow | `transform` → `rotate(90deg)` | **250 ms** | `ease` | |
| Dropdown arrow | `transform` → `rotate(180deg)` | **150 ms** | (default) | |
| Toast | `opacity` | **250 ms** | (default) | Visible for 2600 ms total |
| Plan progress bar | `width` | **300 ms** | (default) | |
| Donut segment hover | `opacity` → `.8` | **120 ms** | (default) | |
| Pro box flash (`@keyframes proflash`) | `box-shadow` | **1400 ms** | `ease` | Red 3px ring between 30 % and 60 % of the timeline; class removed after 1500 ms |

**Instant press feedback (no transition, `:active` only):** `.spk` → `scale(.88)`,
`.bigplay` → `scale(.94)`, `.dehet-btn` → `scale(.96)`, `.pro-cta` → `scale(.97)`,
`.cf-send` → `scale(.98)`.

**Smooth scroll:** `openPro()` calls `scrollIntoView({block:'center', behavior:'smooth'})`
inside a try/catch.

**The flip sequence in full:**
```
flip():
    if flipping: return                    # re-entrancy guard blocks double-taps
    vibrate 10 ms
    if not yet flipped AND the entry is not rich: maybeEnrichAhead(force = true)
    cardEl = the first .card in the document
    reduced = matchMedia('(prefers-reduced-motion: reduce)').matches
    if cardEl exists AND NOT reduced:
        flipping = true
        add class .card-flip-out to cardEl
        after 150 ms: flipping = false; flipped = !flipped; flipAnimateIn = true; render()
    else:
        flipped = !flipped; render()       # instant swap
```
`recogCardHtml` consumes `flipAnimateIn` (reads it, then immediately clears it) to decide
whether the freshly built card gets `.card-flip-in`. Only recognition cards call `flip()` —
`.card.no-flip` (type, cloze, de/het) has no handler at all.

### 8.3 Gestures

There are **no** custom gestures: no swipe, no long-press, no pinch, no drag, no
pull-to-refresh. Every interaction is a tap or a click. Scrolling is native. The only
non-obvious touch affordance is that the entire flashcard is one large tap target for the
flip, and the entire Free-plan Pro box in the drawer is one tap target for the upsell.

`-webkit-tap-highlight-color: transparent` is set on `.spk` only.

### 8.4 Keyboard handling

| Key | Context | Behaviour |
|---|---|---|
| `Escape` | Drawer open | Closes the drawer |
| `Escape` | Any open filter dropdown | Closes every open `details.msdrop` (a separate listener; both fire) |
| `Enter` | `#typeInput` (type / cloze modes) | `preventDefault()` then `checkAnswer()` |
| `Enter` | `#goalInput` | `preventDefault()` then `saveWordGoalFromInput()` |
| `Enter` | `#authEmail` in any of the three auth forms | `preventDefault()` then the form's submit action |
| `Tab` | Everywhere | Native order. `.card` and the Free Pro box are focusable via `tabindex="0"` |
| Any | — | There are **no** study shortcuts (no 1/2/3 to grade, no space to flip) |

Focus management: `#typeInput` is auto-focused after every render in the typing modes
(before an answer is submitted). `setMode()` also attempts to focus it. On a validation
failure, focus moves to the offending field.

A document-level `click` listener (`dropOutsideClose`) closes any open dropdown whose
subtree does not contain the click target.

### 8.5 Reduced motion

Honoured twice, deliberately:
1. `@media (prefers-reduced-motion: reduce) { * { transition: none !important } }` — kills
   every CSS transition globally.
2. `@media (prefers-reduced-motion: reduce) { .card-flip-out { transform: none !important }
   .card-flip-in { animation: none !important } }`
3. `flip()` additionally checks `matchMedia` in JavaScript and takes the instant-swap branch,
   so the 150 ms delay is skipped entirely rather than merely being invisible.

### 8.6 Haptics

`hap(ms)` calls `navigator.vibrate(ms || 10)` inside a try/catch, so it silently no-ops
where unsupported — which includes **all of iOS Safari**.

| Duration | Trigger |
|---|---|
| **10 ms** (default) | Tab switch, card flip, every grade button, skip, every dropdown pick, theme/language change, drawer toggle, drawer close, accordion header, every Pro action, every auth action, opening a word, back from a word, speaking, plan and goal chips, review/drill entry points |
| **12 ms** | A correct answer in type / cloze / de-het |
| **24 ms** | A wrong answer in type / cloze / de-het |
| **30 ms** | Reaching the daily goal (fired alongside the 🎉 toast) |

### 8.7 Sound

There are no sound effects. The only audio is **speech synthesis**:

```
_speakDutch(text, btn):
    if 'speechSynthesis' not in window:
        toast "Pronunciation isn't supported on this device"; return
    speechSynthesis.cancel()                                   # stop anything in flight
    remove .speaking from every .spk in the document
    if no cached Dutch voice: reload the voice list
    u = new SpeechSynthesisUtterance(text)
    u.lang = "nl-NL"
    if a Dutch voice was found: u.voice = it
    u.rate = 0.9
    if a button was passed: add .speaking to it; clear it on both `end` and `error`
    speechSynthesis.speak(u)

_loadNlVoice():
    from speechSynthesis.getVoices(), take the first voice whose lang matches /^nl(-|_|$)/i,
    else the first whose name matches /dutch|nederlands/i, else null
```

The voice list is loaded once at script evaluation and again on every
`speechSynthesis.onvoiceschanged`. `speak(idx, ev)` speaks a headword; `speakText(text, ev)`
speaks any string (used for example sentences). Both call `ev.stopPropagation()` so tapping
a speaker never flips the card or opens the row.

**Quality caveat:** output depends entirely on the device's installed TTS voices. With no
Dutch voice installed, the browser reads Dutch with the wrong accent rather than failing.

### 8.8 Rendering discipline (performance-critical)

| Rule | Why |
|---|---|
| Typing in the Words search must update **only** `#wlist` and `#wmore` | Re-rendering `#main` destroys the input and dismisses the mobile keyboard |
| A Learn filter change must rebuild **only** `#learnBody` | Rebuilding `#learnBars` would close the open dropdown mid-multi-pick |
| `refreshDrop(key)` regenerates one dropdown via `outerHTML` and **restores its `open` state** | Keeps the menu open while options are ticked |
| The drawer lives outside `#main` and is rebuilt only by `renderMenu()` | `render()` must never touch it |
| `nav` must keep `position:sticky` + `translateZ(0)` and must **not** get `overflow:hidden` | Both are required to stop the Android-Chrome bug where the tab bar vanishes after a tab tap. JavaScript repaint hacks were tried and did not work; the CSS compositing-layer promotion is the actual fix |
| `.topbar` must never get a `transform` | It would become the containing block for Midnight's `position:fixed` nav |
| `event.stopPropagation()` is always guarded as `event && event.stopPropagation()` | Synthetic clicks pass no event object |
| The Words list caps at `listLimit` (100, +300 per "Show more") | Rendering 6,752 rows at once is too slow on mobile |

---

## 9. BACKEND AND INFRASTRUCTURE

### 9.1 Hosting and deployment

- **Platform:** Cloudflare Workers, static-assets mode. There is no Worker script — the
  entire deployment is the `public/` directory served as assets.
- **Config — `wrangler.jsonc`, verbatim:**

```jsonc
{
  "name": "drop-a757014e-97c",
  "compatibility_date": "2025-01-01",
  "assets": {
    "directory": "./public",
    "not_found_handling": "single-page-application"
  }
}
```

- The Worker **name is the URL** and must not change.
- **Pipeline:** Workers Builds watches the `main` branch. A push to `main` runs
  `npx wrangler deploy` and is live in roughly 60 seconds. Pushing any other branch deploys
  nothing.
- **`not_found_handling: "single-page-application"`** is the single most consequential
  setting: any path that does not match a real file returns `index.html` with **HTTP 200**.
  That is why (a) every icon and pack must exist as a real file, and (b) a missing i18n pack
  surfaces as a JSON parse error rather than a 404.
- **Deployed surface:** `index.html`, `sw.js`, `site.webmanifest`, 8 image files, and 10
  files under `/i18n/`. Nothing else. Cloudflare gzips the responses; `index.html` is
  ~1.84 MB raw.
- **Build step:** none. No bundler, no transpiler, no package manager, no dependencies.

### 9.2 API endpoints

The app makes exactly **three** kinds of network request. There is no first-party API.

**9.2.1 Content pack fetch** — the only one that runs in normal use.

```
GET /i18n/<lang>.json
    lang ∈ fr it es de pt pl tr uk ru bg
Response 200: application/json — a flat { "<english string>": "<translation>" } object
Failure mode: under the SPA fallback a missing file returns 200 + HTML, so r.json() throws
Client: fetch(), memoised in CTCACHE, cached by the service worker at runtime
```

**9.2.2 Contact form** — third-party, no backend of ours.

```
POST https://formsubmit.co/ajax/<url-encoded owner email>
Headers: Content-Type: application/json
         Accept: application/json
Body:
{
  "_subject":  "Dutch To Go — <selected subject>",
  "_template": "table",
  "_captcha":  "false",
  "_replyto":  "<user email>",          // present ONLY when the optional email is filled in
  "Category":  "<selected subject>",
  "Email":     "<user email>" | "(not provided)",
  "Message":   "<free text>"
}
Success: any 2xx; the response body is parsed but ignored
Failure: a non-ok status throws Error("http <status>")
```

The recipient address is assembled at send time as `['whiskeyneat3060','gmail.com'].join('@')`
inside `sendContact()` only. It never appears in rendered markup. FormSubmit requires a
one-time activation: the very first live submission emails the owner a confirmation link;
after that link is clicked, all later messages arrive silently. **Sending cannot work from a
`file://` copy** (no page origin).

**9.2.3 Anthropic Messages API** — present in the source but **dormant**. `canCallApi()`
requires either the Claude-artifact host (`window.storage`) or a stored `dutch5k-apikey`,
and **no UI writes that key** (`saveKey()` exists but nothing calls it). In the deployed web
app these code paths never fire.

```
POST https://api.anthropic.com/v1/messages
Headers: Content-Type: application/json
         x-api-key: <the stored key>
         anthropic-version: 2023-06-01
         anthropic-dangerous-direct-browser-access: true
Body:  { "model": "claude-sonnet-4-6", "max_tokens": 4000,
         "messages": [ { "role": "user", "content": "<enrichment prompt>" } ] }
Response: text blocks are concatenated, ``` fences stripped, and JSON.parse'd into an array
          of { w, a?, t, m, f, syn, ant, ex } which is merged into `enriched`
Batching: maybeEnrichAhead → up to 10 of the next 12 queue entries
          backgroundFill  → 25 at a time, 1200 ms apart, until nothing is left
          enrichBulk      → the 100 lowest-rank non-rich entries, 20 per call
```

Three callers: `maybeEnrichAhead()` (on flip and after each grade), `backgroundFill()`
(2500 ms after load and on the `online` event), and `enrichBulk()` (no UI). The service
worker explicitly **never caches** `api.anthropic.com`.

### 9.3 Environment variables and secrets

**None.** There is no `.env`, no build-time substitution, no CI secret. The two sensitive
strings are both in client source:

| Name | Value location | Exposure |
|---|---|---|
| Owner contact email | Assembled from two literals inside `sendContact()` | Present in the shipped JavaScript; obfuscated only against naive scraping |
| Anthropic API key | `localStorage['dutch5k-apikey']` | User-supplied; never shipped; currently unreachable |

`.gitignore` is 68 bytes; nothing secret is tracked.

### 9.4 Auth model

**There is none.** The account layer is a deliberate local placeholder:

- No password is ever collected, stored, hashed or checked. "Log in" means "an entry with
  this email exists in this browser's `dutch5k-accounts` object".
- "Continue with Google" is a demo: it asks for an email address and creates or reuses a
  local account tagged `provider: "google"`. There is no OAuth client, no redirect, no token,
  no verification. The UI says so: *"Demo Google sign-in — real Google login is coming soon."*
- The Pro entitlement is a boolean on the local account. `buyPro()` sets it immediately with
  **no payment step of any kind**. `cancelPro()` clears it. There is no receipt, no store, no
  server validation.
- Single-session enforcement (§7.14) writes a `session = {device, at}` marker onto the
  account. Within one browser it is trivially satisfied; the marker exists as the hook a
  future backend would use.
- Signing out clears `isPro` (the entitlement belongs to the account) but leaves all study
  progress on the device.

**For the rebuild this means: any real authentication, entitlement or sync is new work, not
a port.** See §12.

### 9.5 Service worker — `public/sw.js`

Registered from a **real same-origin file**: `navigator.serviceWorker.register('/sw.js')`
inside a try/catch with a swallowed rejection. This is important history: an earlier build
registered the worker from a `blob:` URL, which browsers reject outright, so the app silently
ran with no service worker at all — no offline cache, and reminders that could never fire
because `navigator.serviceWorker.ready` never resolved.

Full source:

```js
const C = 'dutch5k-v110';
self.addEventListener('install',  e => { self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });
self.addEventListener('fetch', e => {
  const url = e.request.url;
  // never cache the Anthropic API
  if (url.includes('api.anthropic.com')) return;
  e.respondWith(
    caches.open(C).then(cache =>
      cache.match(e.request).then(hit => {
        const net = fetch(e.request).then(resp => {
          if (resp && resp.status === 200 && (e.request.method === 'GET')) {
            cache.put(e.request, resp.clone());
          }
          return resp;
        }).catch(() => hit);
        return hit || net;
      })
    )
  );
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(cls => {
      for (const c of cls) { if ('focus' in c) return c.focus(); }
      if (self.clients.openWindow) return self.clients.openWindow('/');
    })
  );
});
```

**Caching strategy: cache-first, with an unconditional background network fill.**
- A cache hit is returned immediately; the network request still runs and overwrites the
  cache entry for next time (a stale-while-revalidate variant where the revalidation result
  is discarded for this request).
- A cache miss awaits the network; a network failure on a miss falls back to the (absent)
  cache hit — i.e. it fails.
- Every successful 200 GET on any origin is cached, including cross-origin font files and
  the i18n packs. That is how a language pack becomes available offline after being picked
  once.
- `skipWaiting` + `clients.claim` mean a new worker takes over immediately.
- **There is no cache cleanup.** Old caches under previous version names are never deleted,
  so `caches.keys()` accumulates one entry per shipped version.

**The cache version tag `C` must be bumped on every deploy**, or returning users keep the
stale app. It lives in `sw.js`, not in `index.html`.

### 9.6 Offline behaviour summary

| Capability | Offline |
|---|---|
| Study, grade, browse, search, all statistics | ✅ Fully functional — all data is in the cached HTML |
| Themes, language switching to an already-loaded pack | ✅ |
| Switching to a language whose pack was never fetched | ❌ Toast: `Could not load this language — check your connection and try again.` |
| Web fonts | ✅ after first load (cached by the service worker); otherwise the fallback stacks apply |
| Text-to-speech | ✅ — device-local synthesis, no network |
| Contact form | ❌ Network error path |
| Reminders | ✅ Local timers, but see §10.3 |
| Service worker itself | ❌ Does not run at all from `file://`; an offline copy of `index.html` opened directly has no cache and no reminders, and its i18n packs cannot load, so meanings display in English |

---

## 10. NATIVE PORTING NOTES

### 10.1 Web-specific behaviour with no native equivalent

| # | Web behaviour | Native replacement |
|---|---|---|
| 10.1.1 | **`localStorage` via the `Store` adapter.** Synchronous-ish, string-keyed, JSON-encoded, ~5 MB cap, wiped when site data is cleared | iOS: `UserDefaults` for the small scalars, a JSON file in Application Support (or Core Data / SQLite) for `progress`, `srs` and `enriched`. Android: `DataStore<Preferences>` for scalars, Room or a JSON file for the maps. **Keep the exact key names** so a future import path stays trivial |
| 10.1.2 | **The whole app is one 1.84 MB HTML file, deck included.** | Ship the deck as a bundled read-only asset (the attached `dutch-to-go-deck-v110.json`, ideally pre-baked into SQLite or a Realm/Room database at build time so the 6,752 records are not JSON-parsed on every cold start) |
| 10.1.3 | **Web Speech API** (`SpeechSynthesisUtterance`, `lang='nl-NL'`, `rate=0.9`, Dutch voice preferred by lang prefix then by name) | iOS: `AVSpeechSynthesizer` with `AVSpeechSynthesisVoice(language: "nl-NL")` and `rate` scaled to the platform range. Android: `TextToSpeech` with `Locale("nl","NL")` and `setSpeechRate(0.9f)`. **Both must handle the missing-voice case**: iOS voices are downloaded on demand; Android may need a `TextToSpeech.Engine.ACTION_INSTALL_TTS_DATA` prompt. The web version silently reads Dutch in the wrong accent — native should tell the user instead |
| 10.1.4 | **`navigator.vibrate(ms)`** with 10/12/24/30 ms pulses; no-ops entirely on iOS | iOS: `UIImpactFeedbackGenerator(style: .light)` for the 10 ms taps, `.notificationOccurred(.success)` for 12 ms, `.error` for 24 ms, `.success` again for the 30 ms goal celebration. **iOS users currently get no haptics at all, so this is a net improvement.** Android: `VibrationEffect.createOneShot` with the same durations, or `HapticFeedbackConstants` |
| 10.1.5 | **CSS `data-theme` themes.** Three complete layouts driven by custom properties | Define three theme objects (SwiftUI `Environment` / Compose `MaterialTheme` + a custom token set). Note that theme changes here alter **structure**, not just colour — nav placement, page width, card chrome and type all change — so plan for layout switches, not just a palette swap |
| 10.1.6 | **`prefers-reduced-motion`** honoured in CSS and again in JS | iOS: `UIAccessibility.isReduceMotionEnabled`. Android: `Settings.Global.ANIMATOR_DURATION_SCALE == 0` |
| 10.1.7 | **`<details>` dropdowns with outside-click close** | Native menus / bottom sheets. Preserve the multi-select behaviour: the sheet stays open while options are ticked and the list updates live behind it |
| 10.1.8 | **The 3D CSS card flip** (150 ms out at `rotateY(90°)`, 200 ms in from `rotateY(-90°)`, `perspective(1400px)`) | iOS: `withAnimation` on a `rotation3DEffect`, or `UIView.transition(.transitionFlipFromRight)`. Android: `graphicsLayer { rotationY }` with `cameraDistance`. Match the 150/200 ms split — the content swap must happen while the card is edge-on |
| 10.1.9 | **`window.scrollY` capture and restore** for the Words list | iOS: `UITableView`/`List` scroll offset or `scrollPosition(id:)`. Android: `LazyListState.firstVisibleItemIndex` + `firstVisibleItemScrollOffset`. The web version also relies on `listLimit` not being reset — natively use a normal infinite list and simply restore the item index |
| 10.1.10 | **No routing at all**; browser Back exits the site | Both platforms need a real back stack. Map it as: Profile and word-detail push; the three tabs are siblings that do not stack; system Back from a word detail behaves as `backFromWord()` (§8.1) |
| 10.1.11 | **`fetch('/i18n/<lang>.json')`** for content packs | Bundle all 10 packs as assets (≈9.6 MB raw, far smaller compressed) or download on demand into app storage. Bundling removes the "pack failed to load" error state entirely |
| 10.1.12 | **Service-worker cache-first offline** | Not needed — a native app is inherently offline. Drop it entirely |
| 10.1.13 | **`Notification` API + `setTimeout` reminders that only fire while the tab is open** | See §10.3 — this becomes a genuine local notification and is a straight upgrade |
| 10.1.14 | **`Intl.DateTimeFormat().resolvedOptions().timeZone`** and `toLocaleDateString(langLocale())` | iOS: `TimeZone.current.identifier`, `DateFormatter` with the app `Locale`. Android: `ZoneId.systemDefault()`, `DateTimeFormatter`. Preserve the exact formats: `{month:'short', day:'numeric', year:'numeric'}`, `{month:'short', day:'numeric'}`, `{year:'numeric', month:'short'}` |
| 10.1.15 | **`toLocaleString(langLocale())`** for thousands separators (fr/ru space, de/tr dot, pl none, en comma) | Use the platform number formatter with the app's chosen locale, **not** the device locale — the app language and the device language can differ |
| 10.1.16 | **FormSubmit contact form** | Either keep the same HTTPS POST, or replace it with `MFMailComposeViewController` / an `ACTION_SENDTO` intent, or a real support endpoint. Note §10.5 on store review |
| 10.1.17 | **Google Fonts `<link>`** (Archivo 400/600/700/900, Inter 400/500/600) | Bundle the font files. Both families are SIL Open Font License. Remember weight 800 is currently synthesised by the browser — either bundle a real 800 or accept the difference |
| 10.1.18 | **`try { } catch { }` around every storage call, returning `null`** | Preserve the philosophy: a corrupt or missing store must read as a fresh install, never crash |

### 10.2 Storage migration table

The web app writes nothing that a native app can read directly. The table below states, per
key, what should happen.

| Web key | Value shape | iOS mechanism | Android mechanism | What happens to an existing web user's data |
|---|---|---|---|---|
| `dutch5k-progress` | `{"__v2":true, "<id>":"learned"\|"learning"}` | JSON file in Application Support, or a Core Data `WordProgress` entity keyed by `id` | Room table `word_progress(id TEXT PK, status TEXT)`, or a DataStore JSON blob | **LOST.** No automatic path exists. Requires either a manual export/import (§10.2.1) or a sync account (§10.2.2) |
| `dutch5k-srs` | `{"<id>":{due,iv,ef,reps,lapses,last}}` | Core Data `SrsRecord` keyed by `id` | Room table `srs(id TEXT PK, due TEXT, iv INT, ef REAL, reps INT, lapses INT, last TEXT)` | **LOST** — same |
| `dutch5k-enriched` | `{"<id>":{w,t,m,f,ex,a?,syn?,ant?}}` | JSON file | Room / JSON | **LOST** — but harmless in practice: the enrichment feature is dormant (§9.2.3), so this key is empty for essentially every user |
| `dutch5k-streak` | `{count,lastStudied,history:{date:int}}` | JSON file (the `history` map grows one key per active day) | Room table `streak_day(date TEXT PK, count INT)` + two scalars | **LOST** — same |
| `dutch5k-plan` | `{perDay,endDate,startDate}` or `null` | `UserDefaults` (encoded struct) | DataStore | **LOST** |
| `dutch5k-wordgoal` | int or `null` | `UserDefaults` (`Int?`) | DataStore `intPreferencesKey` | **LOST** |
| `dutch5k-goalmode` | `"count"` \| `"source"` | `UserDefaults` | DataStore `stringPreferencesKey` | **LOST** |
| `dutch5k-goalsources` | `["general","gang",…]` | `UserDefaults` (`[String]`) | DataStore `stringSetPreferencesKey` | **LOST** |
| `dutch5k-remind` | boolean | `UserDefaults` | DataStore `booleanPreferencesKey` | **LOST** — trivial to re-set |
| `dutch5k-remindtime` | `"HH:MM"` | `UserDefaults` | DataStore | **LOST** — trivial to re-set |
| `dutch5k-theme` | `"minimalistic"\|"midnight"\|"sepia"` | `UserDefaults` | DataStore | **LOST** — trivial to re-set |
| `dutch5k-lang` | one of 11 ids | `UserDefaults` | DataStore | **LOST** — trivial to re-set |
| `dutch5k-shuffle` | boolean | `UserDefaults` | DataStore | **LOST** — session-level preference |
| `dutch5k-newonly` | boolean | `UserDefaults` | DataStore | **LOST** — session-level preference |
| `dutch5k-mode` | one of 6 mode ids | `UserDefaults` | DataStore | **LOST** — trivial to re-set |
| `dutch5k-pro` | boolean | **Do not port as-is.** Entitlement must come from StoreKit 2 `Transaction.currentEntitlements` | **Do not port as-is.** Google Play Billing `queryPurchasesAsync` | **N/A.** A web `dutch5k-pro:true` must **never** grant a native entitlement — it is an unverified client-side boolean and honouring it would be a purchase bypass |
| `dutch5k-accounts` | `{"<email>":Account}` | Do not port. Replace with a real identity provider (Sign in with Apple / Google Sign-In) | Same | **N/A.** These are unauthenticated placeholder records with no password; migrating them would import accounts nobody can prove they own |
| `dutch5k-account` | signed-in email or `null` | Real session token in the Keychain | Real session token in `EncryptedSharedPreferences` | **N/A** — same |
| `dutch5k-device` | `"d_<random><timestamp>"` | `identifierForVendor`, or a UUID generated once and stored in the Keychain | `Settings.Secure.ANDROID_ID` or a generated UUID in DataStore | Regenerated on first native launch. Harmless |
| `dutch5k-apikey` | string | **Do not port.** Shipping a path for users to paste an LLM API key is an App Store rejection risk and a security liability | Same | **N/A** — dormant and unreachable in the web build anyway |
| `dutch5k-words` | legacy array | Do not port | Do not port | Already consumed by `migrate()`; obsolete |

**10.2.1 Statement on progress, required by this specification:**

> **A web user's saved progress is LOST when they move to the native app**, unless one of
> the two mechanisms below is built. It is not migrated on first launch, because a native
> app cannot read another origin's `localStorage`, and the web app currently exposes **no
> export UI at all** (`exportData()` exists in the source but is wired to no button, and the
> drawer's Backup box was removed).

**10.2.2 The two viable recovery paths, in order of cost:**

1. **Manual export / import (small).** Re-expose `exportData()` in the web app — it already
   produces `{v:2, progress, enriched, exported:<ISO timestamp>}` as
   `dutch-to-go-backup.json` — and build a matching "Import backup" screen in the native
   apps that accepts that file via the document picker / `ACTION_GET_CONTENT` and merges it
   the way `importData()` does (`Object.assign` over `progress` and `enriched`, then set
   `__v2`). Because ids are stable (§6.4) the merge is exact. This is the recommended
   minimum and should ship in the **web** app before the native apps launch, so users have
   something to export.
2. **A real sync account (large).** Build the backend the placeholder layer was always
   shaped for: real OAuth, a server-side `progress`/`srs`/`streak` document per user, and
   last-write-wins or per-key merge. This also solves the entitlement problem (§10.2, the
   `dutch5k-pro` row) and makes the existing `session = {device, at}` marker meaningful.

**10.2.3 Native-to-native.** Once native, use the platform backup systems: iOS iCloud
Key-Value store / CloudKit and Android Auto Backup (`android:allowBackup`) or Backup &
Restore. Note that Android Auto Backup has a 25 MB per-app quota — the deck is a bundled
asset and must be **excluded** from backup; only user state should be backed up.

### 10.3 Push notification requirements

**Current web behaviour:** entirely local and best-effort. `scheduleReminder()` reads
`dutch5k-remind`, and when enabled with granted permission it (a) fires immediately if the
chosen time has already passed today and nothing has been learned, and (b) sets a single
`setTimeout` to the next occurrence of `HH:MM` in **device-local** time, clamped to
`0x7fffffff` ms. `_fireReminder()` bails out if `todayCount() > 0`, then prefers
`registration.showNotification(...)` with a 2000 ms timeout guard, falling back to the page
`Notification` constructor. Title `Dutch To Go`, body
`Time for today's words! Keep your streak going.`, tag `dutch5k-daily`. The worker's
`notificationclick` handler focuses an existing window or opens `/`.

**This only fires while a tab is open.** There is no push server. The UI says so.

**Native requirements:**

| Requirement | iOS | Android |
|---|---|---|
| Permission | `UNUserNotificationCenter.requestAuthorization([.alert, .sound, .badge])`. iOS also offers provisional authorisation, which suits a study nudge well | `POST_NOTIFICATIONS` runtime permission (API 33+); declare a notification channel (e.g. `daily_reminder`, importance DEFAULT) |
| Scheduling | `UNCalendarNotificationTrigger` with `DateComponents(hour:, minute:)` and `repeats: true` — this fires **whether or not the app is running**, which the web version cannot do | `AlarmManager.setExactAndAllowWhileIdle` (needs `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` on API 31+) or, preferably, a daily `WorkManager` `PeriodicWorkRequest` if exact timing is not critical |
| "Already studied today" suppression | Cannot be evaluated inside a repeating trigger. Either post the notification and let the tap open the app, or reschedule the next occurrence at each app launch after checking `todayCount()`. **Recommended:** keep the repeating trigger and additionally cancel today's pending request the moment `todayCount()` becomes > 0 | Same approach; cancel the pending work/alarm when the first word of the day is learned |
| Timezone | Both platforms schedule in the device timezone by default, matching the current behaviour. Reschedule on `NSSystemTimeZoneDidChange` / `ACTION_TIMEZONE_CHANGED` | |
| Small icon | **Required on Android**: a white-on-transparent silhouette at 24×24 dp. Does not exist yet (§4.6) | |
| Tap handling | Deep-link into the Learn tab (the web worker just focuses `/`) | Same |
| Server push | **Not needed.** Everything here is local. Do not add APNs/FCM unless a real backend appears | |

### 10.4 Deep links

**None exist today** — no URL scheme, no universal links, no `intent-filter`, no fragment
routing. If the native apps add them, the natural minimum set is:

| Link | Destination |
|---|---|
| `dutchtogo://learn` | Learn tab |
| `dutchtogo://review` | Learn tab with `startReview()` semantics |
| `dutchtogo://word/<id>` | The word-detail card for that entry id |
| `dutchtogo://progress`, `dutchtogo://profile` | Those screens |

Universal Links (iOS `apple-app-site-association`) and App Links (Android
`assetlinks.json`) would need to be served from the existing Cloudflare deployment. Note the
SPA fallback returns `index.html` with HTTP 200 for unknown paths, so those well-known files
must be **real files** in `public/.well-known/` or verification will silently fail.

### 10.5 Permissions needed

| Permission | Platform | Why | Notes |
|---|---|---|---|
| Notifications | both | The daily study reminder | Optional feature — the app must be fully usable if denied. The web version already handles denial with the toast `Reminder permission denied` |
| Exact alarms (`SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM`) | Android 12+ | Only if the reminder must fire at the exact minute | Prefer `WorkManager` and avoid this permission — Play reviews exact-alarm usage |
| Internet | Android | The contact form and (if not bundled) i18n packs | Declare `INTERNET` |
| Nothing else | — | — | **No** camera, microphone, location, contacts, storage or tracking permission is needed. Text-to-speech needs none |

### 10.6 App Store / Play Store review flags

| # | Issue | Severity | What to do |
|---|---|---|---|
| 10.6.1 | **The Pro upgrade is not a real purchase.** `buyPro()` flips a local boolean with no payment. Any "Get Pro" affordance that unlocks content without going through StoreKit / Play Billing violates App Store Review Guideline 3.1.1 and Play's Payments policy | **Blocker** | Wire the entitlement to real in-app purchase before submission, or remove every Pro affordance and ship the app fully unlocked |
| 10.6.2 | **"Switch back to Free (test)"** is a visible test-only control, and the drawer copy calls the flow a test | **Blocker** | Remove it from production builds |
| 10.6.3 | **"Continue with Google" is a non-functional demo.** It collects an email address and grants an "account" with no authentication. Reviewers will test it | **Blocker** | Either implement real Sign in with Google, or remove the button. Note: **if any third-party sign-in is offered on iOS, Sign in with Apple must also be offered** (Guideline 4.8) |
| 10.6.4 | **Account creation with no way to delete the account.** Apple requires in-app account deletion for any app that supports account creation (Guideline 5.1.1(v)) | **Blocker if accounts ship** | Add account deletion, or ship without accounts |
| 10.6.5 | **Copyrighted source material.** The vocabulary lists derive from four commercial Coutinho NT2 textbooks and a commercial Teach Yourself dictionary. Only headwords, articles and verb principal parts were taken; **every meaning and example sentence is original**, and no book sentences are reproduced. The book titles were deliberately removed from all user-visible text and replaced with CEFR bands | **Review risk** | Keep the book titles out of the app, the store listing and the marketing. Be able to state the provenance rule if challenged. Consider a formal review of the word-list compilation question |
| 10.6.6 | **An "add your own API key" flow** would be flagged if re-enabled | **Blocker if re-enabled** | Keep `saveKey()` unreachable, or delete the code |
| 10.6.7 | **Third-party form posting to `formsubmit.co`** sends user-typed text and an optional email address off-device | **Privacy disclosure** | Declare it in the App Privacy nutrition label and the Play Data Safety form: "Contact info (optional) and User content (message), collected, not linked to identity, for app functionality." Consider replacing it with a native mail composer |
| 10.6.8 | **The owner's personal Gmail address is embedded in the client** as the support destination | **Advisory** | Move support to a role address or a real endpoint |
| 10.6.9 | **No privacy policy exists.** Both stores require a privacy-policy URL | **Blocker** | Write one. It is short: no analytics, no tracking, no ad SDK, no third-party identifiers; local storage only; one optional outbound form post |
| 10.6.10 | **Minimum functionality** (Guideline 4.2) — "a repackaged website" | **Low risk** | The app has substantial offline functionality and native-worthy features; do not ship it as a `WKWebView` wrapper around the existing HTML, which *would* be rejected |
| 10.6.11 | **Age rating.** The content is a language dictionary. One historical note in the project records an offensive gloss that was corrected | **Advisory** | Rate 4+/Everyone; keep the gloss review discipline |
| 10.6.12 | **Accessibility.** `aria-label`s exist but nothing has been audited: theme swatch buttons carry no visible text, the donut is colour-plus-legend, and there are no study keyboard shortcuts | **Advisory** | Run VoiceOver and TalkBack passes; give every icon-only control an accessibility label; verify contrast in all three themes, especially Sepia's `--muted2` on `--paper` |

---

## 11. ACCEPTANCE CRITERIA

A build is correct if and only if every numbered statement below passes. Each is testable
without reference to the original source.

### 11.1 Data integrity

1. The built deck contains exactly **6,752** entries.
2. Every entry has a unique `id`; there are no duplicates.
3. Exactly **115** ids match `<word>|<type>`, **4,381** are bare words, **1,772** start with
   `book:`, and **484** start with `essential:`.
4. Exactly **6,729** entries are `rich`; **6,583** have `hasMeaning`; exactly **23** have
   neither, and those 23 are the extraction artifacts listed in §12.6.
5. Exactly **6,729** entries carry at least one example sentence; **897** carry grammar
   forms; **849** carry synonyms; **488** carry antonyms; **1,176** carry a `de`/`het`
   article.
6. Source-tag totals are exactly: general **2,365**, essential **1,484**, actie **1,214**,
   gang **946**, niveau **499**, perfectie **368**.
7. No entry is tagged both `essential` and `general` — the two sets are disjoint.
8. Chapter ranges are exactly: gang 1–18, actie 1–11, niveau 1–6, perfectie 1–8.
9. The word `bereiken` resolves to a rich entry with meaning
   `"to reach, to achieve, to attain; to get in touch with someone"`, three grammar forms,
   two synonyms, two antonyms, two examples, and the book tag `{src:"actie", ch:1}`.
10. Every one of the **515** `JUNK` words is absent from the deck.
11. `computeFree()` produces exactly **850** free ids.
12. `GENEX` object-form meanings override the dictionary gloss: `kan` reads `"can; to be
    able to (form of kunnen)"`, not `"jug"`; `waar` reads `"where; true, real"`, not
    `"authentic; genuine; deserving"`; `tel` reads `"count; tally"`, not `"esteem; regard"`.

### 11.2 Study queue and scheduling

13. With no filters, no progress and shuffle off, the first card is the lowest-rank
    (rank 1) non-junk entry.
14. Grading a brand-new word "Know it" sets `progress = "learned"` and creates an SRS record
    with `iv = 1`, `reps = 1`, `ef = 2.5`, `lapses = 0`, and `due` = tomorrow's local date.
15. Grading that word "Know it" again the next day yields `iv = 4`, `reps = 2`, `ef = 2.5`.
16. Grading "Learning" on a fresh word yields `iv = 1`, `reps = 1` and `ef = 2.36`
    (2.5 − 0.14).
17. Grading "Again" on any word deletes its `progress` entry, increments `lapses`, sets
    `reps = 0` and `iv = 0`, reduces `ef` by exactly 0.2 (floor 1.3), and sets `due` to today.
18. `ef` never drops below **1.3** under any sequence of grades.
19. A word with a `due` date on or before today, whose status is learning or learned, is
    counted by `dueCount()`; a never-started word never is.
20. A word with a progress status but **no** SRS record is treated as due.
21. The queue is ordered: due reviews sorted by ascending `due`, then fresh words.
22. With `newOnly` on, the queue contains only fresh words and **no** due reviews, and it is
    allowed to be empty.
23. With `leechOnly` on, the queue contains only words with `lapses >= 2` and introduces no
    fresh words.
24. When nothing is due and nothing is fresh (and `newOnly` is off), the queue falls back to
    not-yet-due words rather than being empty.
25. Skipping a card moves it to the end of the queue and it reappears later in the same round.
26. `modeEligible` restricts the pool correctly: `reverse`/`type`/`listen` require a meaning,
    `cloze` requires an example containing the headword, `dehet` requires `a ∈ {de, het}`.
27. A correct answer in `dehet` mode marks the word **`learning`**, not `learned`.
28. Reaching the end of the queue rebuilds it automatically without an empty flash.

### 11.3 Answer checking

29. `normalizeAns` makes all of these equal for the noun `huis`: `huis`, `Huis`, `het huis`,
    `HUIS.`, `  huis  `.
30. Diacritics are ignored: `een` matches `één`.
31. An empty typed answer is always wrong, even against an empty expected answer.
32. `clozePick` blanks the headword only on a whole-word boundary, so `viool` in
    `"Zij speelt al tien jaar viool."` is blanked but the `viool` inside a longer word is not.

### 11.4 Free / Pro gating

33. With `isPro = false`, exactly 850 entries are unlocked and every other entry renders
    blurred behind the Pro overlay in Learn, Words rows and Words detail.
34. With `isPro = false`, the Words list shows every unlocked word before the first locked
    word, and the Learn queue's fresh segment does the same **when shuffle is off**.
35. With shuffle **on**, free-first ordering is deliberately **not** applied.
36. With `isPro = false`, the Progress tab's stat tiles, Streak, Review, Hardest words and
    14-day history are fully visible, while "By word type" and "By source" are blurred behind
    the overlay.
37. With `isPro = false`, the Contact form's Subject and email fields are usable but the
    message textarea and Send button are locked; calling the send action opens the upsell
    instead of sending.
38. With `isPro = true`, no overlay appears anywhere.
39. A guest tapping any Pro CTA is routed to the Profile sign-up form and no purchase occurs.

### 11.5 Goals, streaks and plan

40. The header counter reads `<goalLearned> / <goalTotal>`.
41. With no custom goal, `goalTotal()` equals `deck.length` (6,752).
42. Setting a goal of 1,000 makes the "Of {goal} goal" tile read against 1,000, and the
    percentage is capped at 100 with exactly one decimal place.
43. In source mode with two overlapping sources selected, a word belonging to both is counted
    **once** in both the total and the learned count.
44. In source mode with no source selected, `goalTotal()` falls back to `deck.length`.
45. Learning the first word of a day increments `streak.history[today]` to 1 and sets
    `streak.count` to 1 when there was no previous study day.
46. Studying on consecutive days increments `streak.count` by exactly 1 per day.
47. `currentStreak()` returns the stored count when the last study day was today or
    yesterday, and 0 otherwise.
48. With a per-day plan of N, reaching exactly N learned words today fires the 🎉 toast
    **once** and vibrates for 30 ms.
49. The 14-day grid shows 14 cells, oldest first, with level thresholds 0 / 1–4 / 5–9 / 10+.

### 11.6 Filtering, search and navigation

50. All filter dropdowns are multi-select except Study mode, and an empty selection shows the
    filter's name (never the word "All").
51. Selecting two options in one dropdown shows `Name · 2` and keeps the menu open.
52. Selecting a filter option does **not** close other dropdowns, does not scroll the bar,
    and does not rebuild the filter row.
53. Clicking outside an open dropdown, or pressing Escape, closes it.
54. Typing in the Words search never loses input focus and never dismisses the mobile
    keyboard.
55. Searching `tell` ranks the exact word `tell` above `teller` and `vertellen`; every
    substring match still appears somewhere in the list.
56. The Words list renders at most 100 rows initially; "Show more" adds exactly 300 more.
57. Opening a word from the Words list and pressing Back restores the previous scroll
    position and the previous list length.
58. Following a synonym from a Learn flashcard and pressing Back returns to the Learn tab,
    not the Words list.
59. Following a synonym from a word detail pushes a back-stack entry; Back returns to the
    parent card, top-aligned.
60. Tapping a "By word type" row opens the Words tab filtered to that type; tapping a donut
    slice or legend row opens it filtered to that source with the type filter cleared.

### 11.7 Persistence

61. Every one of the 17 live storage keys uses the exact name in §6.2 and stores a
    JSON-encoded value.
62. Reloading the app restores progress, SRS state, streak, plan, goal, theme, language,
    study mode, shuffle and new-only exactly.
63. A missing, empty or malformed value for any key produces the documented default and never
    throws.
64. Marking a word "Again" removes its key from `progress` entirely (it is not stored as
    `"new"`).
65. `progress.__v2` is always `true` after any write.
66. A storage-quota failure surfaces the toast `Storage full — export your progress` and does
    not crash.

### 11.8 Theming and presentation

67. All three themes are selectable and every token in §3.2 matches exactly.
68. Switching theme updates `<meta name="theme-color">` to `#FFFFFF`, `#0d0e15` or `#f3ead6`
    respectively.
69. The saved theme is applied before first paint, with no flash of the default theme.
70. In Midnight the nav is a fixed bottom pill and `main` has 98px bottom padding; in Sepia
    `main` is 520px wide with a centred title-page header; in Minimalistic the nav is a top
    tab bar.
71. Switching theme or language while the drawer is open keeps the drawer open and refreshes
    its active-state highlights and translations.
72. Only one drawer accordion can be open at a time; opening a second collapses the first.
73. All accordions start collapsed on every open of the drawer.
74. No text renders as black-on-dark or invisible in any theme.
75. The Words filter row and the Learn filter row each fit on one line at 320px width, with
    every dropdown the same width.

### 11.9 Localisation

76. Switching to any of the 10 non-English languages translates the nav, header, drawer and
    all ✅-marked strings in §5.
77. Switching to a language whose pack has not been fetched, while offline, shows the toast
    `Could not load this language — check your connection and try again.` and does **not**
    change the language.
78. Dutch headwords, grammar-form values, synonyms and antonyms are **never** translated.
79. A meaning missing from a content pack falls back to English rather than rendering blank.
80. `{n}`-style placeholders are substituted after lookup, so a translation may reorder them.
81. Numbers in goal and count strings are formatted for the **app** language, not the device
    locale.

### 11.10 Interaction and media

82. The card flip runs 150 ms out and 200 ms in, and the face swaps while the card is
    edge-on.
83. Double-tapping during a flip does not produce a double flip.
84. With reduced motion enabled, the flip is instant and no CSS transition runs.
85. Tapping any speaker icon speaks the Dutch text at rate 0.9 in a `nl-NL` voice, turns the
    icon red while speaking, and does **not** flip the card or open the row.
86. Speaking a new item cancels any in-flight utterance.
87. On a device with no speech synthesis, the toast
    `Pronunciation isn't supported on this device` appears.
88. Enter submits in the typing modes, the goal input and all three auth forms.
89. Escape closes the drawer and any open dropdown.

### 11.11 Offline and infrastructure

90. After one online load, the app opens and is fully usable with the network disabled.
91. A language pack fetched once remains available offline.
92. The service worker cache version tag differs from the previous release.
93. Requests to `api.anthropic.com` are never cached.
94. Tapping a reminder notification focuses an existing app window, or opens the app root.
95. Every referenced asset path resolves to a real file (no SPA fallback serving HTML in
    place of an icon, manifest or pack).

### 11.12 Reminders

96. Enabling reminders requests notification permission; a denial shows
    `Reminder permission denied` and leaves the setting off.
97. The reminder button is a true toggle: tapping while on turns reminders off, clears the
    pending timer, and toasts `Daily reminders off`.
98. The chosen `HH:MM` is interpreted in the device's local timezone, and the note names that
    timezone.
99. A reminder does not fire on a day the user has already learned at least one word.
100. On a platform where notifications are unavailable, the reminder block is not rendered and
     no error occurs.

### 11.13 Accounts (only if the placeholder layer is reproduced)

101. Signing in stores a `session = {device, at}` on the account and marks any previously
     signed-in account's session as null.
102. Signing in an email whose session belongs to a different device shows
     `Signed in as {name}. Signed out of your other device.`
103. On startup, an account whose session device no longer matches this device is signed out.
104. Signing out clears the account session, sets `isPro` to false, and leaves progress intact.
105. Attempting to log in with an unknown email shows
     `No account found for that email — sign up instead.` and does not sign in.
106. All three auth forms reject malformed and disposable email addresses per §7.13.

---

## 12. OPEN QUESTIONS

Everything below is a genuine ambiguity or a decision the rebuilder must make. Nothing here
is a guess dressed up as a fact.

### 12.1 Product decisions the current build leaves unresolved

| # | Question | Why it is open |
|---|---|---|
| 12.1.1 | **Is Pro a real product?** Every gate, overlay, limit and CTA exists and works, but the purchase step is an unverified local boolean. Should the rebuild ship real IAP, or ship fully unlocked and keep the gating code dormant? | Determines whether §10.6.1–10.6.2 are blockers |
| 12.1.2 | **Are accounts a real feature?** Sign-in collects an email and nothing else — no password, no verification, no server. Should the rebuild implement real auth, or delete the account layer and treat the app as device-local? | Determines §10.6.3–10.6.4 and whether progress can ever move between devices |
| 12.1.3 | **Should progress sync?** The code is shaped for it (stable ids, an account object, a `session` marker) but nothing exists. Without it, a user who clears site data loses everything and there is currently no backup UI | This is the single largest gap between the app's promise and its behaviour |
| 12.1.4 | **Should `exportData()` / `importData()` be re-exposed?** They still work; the Backup drawer box was deliberately removed. Re-exposing them is the cheapest path to native migration (§10.2.2) | |
| 12.1.5 | **Should the AI-enrichment code survive?** `enrichWords`, `maybeEnrichAhead`, `backgroundFill`, `enrichBulk` and `saveKey` are all live code that can never run, because no UI writes `dutch5k-apikey`. Delete, or re-enable behind Pro? | Affects §5.11, §6.2 key 3, §9.2.3 and §10.6.6 |
| 12.1.6 | **Should Midnight follow the OS dark-mode setting?** There is no `prefers-color-scheme` query anywhere; dark mode is a manual theme choice only | |
| 12.1.7 | **Should the app have real routing?** Today the browser Back button exits the site and nothing below the root is linkable | Native needs a back stack regardless (§10.1.10) |

### 12.2 Undocumented or unverifiable specifics

| # | Item | What is unknown |
|---|---|---|
| 12.2.1 | **The exact hex palette of the badge artwork.** The bicycle badge is a raster asset only. The navy, orange, red and pale-blue used in it are not defined anywhere in code and could not be sampled in this environment (no image library available) | Sample them from `icon-512.png`, or obtain the source art |
| 12.2.2 | **The source artwork for the icons is not in the repository.** `make_icons.py` references an absolute path outside the repo (`/root/.claude/uploads/…`). Only rasterised outputs are committed | The icons cannot currently be regenerated at higher resolution or re-cropped |
| 12.2.3 | **`scratchpad/make_icons.py` is stale.** It still carries the previous artwork's crop parameters (`CX=511, CY=284, R=210`) and the previous share-card copy (`"Learn Dutch,"` / `"5,000 words at a time"` / `"flashcards · examples · offline"`). The shipped `og-image.png` shows the bicycle badge with `"Dutch To Go"` / `"Vocab Trainer"` / `"Learn 5,000+ Dutch words — flashcards, examples, offline."` | **Re-running the committed script would not reproduce the shipped assets.** The script that actually produced them was not committed |
| 12.2.4 | **The exact fonts used in `og-image.png`.** The committed script uses DejaVu Sans Bold; the shipped image is clearly not DejaVu | |
| 12.2.5 | **Whether the deployed site is actually reachable** and at what hostname. The Worker is named `drop-a757014e-97c`; the public URL is not recorded in the repository | |
| 12.2.6 | **Whether FormSubmit has been activated.** The first live submission requires the owner to click a confirmation link. Whether that ever happened is unknown | If not, no contact message has ever been delivered |
| 12.2.7 | **Real-device verification.** No automated test suite exists (testing is described as ad-hoc jsdom scripts). None of the animation timings, haptics, TTS behaviour or notification behaviour in this document has been verified on a physical device in this session | |

### 12.3 Known inconsistencies in the current build (decide: preserve or fix)

| # | Inconsistency |
|---|---|
| 12.3.1 | **Two typographies for the same six source labels.** Legends and badges use an en dash (`A0–A2`); the filter dropdown uses an arrow (`A0 → A2`). Both are hard-coded literals |
| 12.3.2 | **`General` vs `General 5K`.** The About box uses a bare untranslated literal `General`; the source filter uses the translated key `General 5K` |
| 12.3.3 | **57 strings are English-only** — all of Contact, all of Pro, all of Profile/auth — while 157 others are translated into 10 languages. A user in Bulgarian sees a mixed-language Profile page |
| 12.3.4 | **The Contact `<option value>` is the translated label**, so the value posted to the email service changes with the UI language (§5.12.4) |
| 12.3.5 | **`recordLearned()` is guarded by `wasLearned` in `mark()` but not in `setWordStatus()`.** Re-marking an already-learned word from the Words detail card increments today's count again; doing it from the Learn card does not |
| 12.3.6 | **The manifest's `theme_color` is a static `#ffffff`** and does not track the chosen theme, while the `<meta name="theme-color">` tag does |
| 12.3.7 | **`favicon-32.png` is generated but never referenced** from the HTML |
| 12.3.8 | **`favicon.svg` is not a vector** — it is a 69 KB SVG wrapping a base64 PNG |
| 12.3.9 | **The `perfectie` source has no bucket in `computeFree()`** (only in `FREE_LIMITS`, where it is 0). Functionally identical today, but a future non-zero cap for it would silently do nothing |
| 12.3.10 | **The service worker never deletes old caches.** One cache accumulates per shipped version |
| 12.3.11 | **The service worker caches every 200 GET on every origin**, including cross-origin fonts, without any allowlist |
| 12.3.12 | **`README.md` is out of date.** It describes the app as "Dutch 5K" on "Cloudflare Pages" with an Export/Import backup and an API key entered on the Progress tab — none of which is current |
| 12.3.13 | **Dead code and dead CSS.** `chipsHtml()`, `shuffle()`, `toggleShuffle()`, `toggleNewOnly()`, `exportData()`, `importData()`, `saveKey()`, `enrichBulk()` and the `expanded` variable are all unreachable; `.filters`, `.wdetail`, `.chip`, `.posfilters`, `.modebar`, `.shuffle-btn` and `.filtersel` CSS blocks are unused |
| 12.3.14 | **31 entries are `rich` but have no meaning** (they gained an example without a gloss), so they render an example section under an empty meaning line |

### 12.4 Content quality caveats inherited from the data

| # | Caveat |
|---|---|
| 12.4.1 | Meanings originate from an automated dictionary (FreeDict NL-EN) plus lemmatisation, with roughly 264 hand-corrected homograph glosses layered on top. A mechanical audit fixed the cases where a gloss shared no word stem with its own example; **subtler mistranslations that pass that check remain** |
| 12.4.2 | The 10 content packs are machine-translated (Argos / CTranslate2). A corruption audit removed 2,247 mechanically-broken strings; Turkish has the weakest coverage at 9,201 of ~12,360 keys and falls back to English most often. Some second senses are simply mistranslated rather than corrupt (e.g. `tel` in uk/it/pl) |
| 12.4.3 | Regenerating the packs is fragile: CTranslate2 must run with `intra_threads = 1` **and** one language at a time (parallel processes on a 4-core box re-trigger nondeterministic token corruption even at one thread). Budget ~5 minutes per language, ~25 for Turkish |
| 12.4.4 | Textbook words from the A0–A2 band have a meaning and one example but no grammar forms or synonyms |
| 12.4.5 | No CEFR or spoken-frequency tag exists per word. The "level bands" are book membership, not a linguistic assessment of the word |

### 12.5 Provenance — must be understood before touching the data

The vocabulary lists derive from five commercial sources. The rule applied throughout, which
the rebuild must not break:

> **Only the Dutch headword, its `de`/`het` article, and (for verbs) the principal parts were
> taken from any book or dictionary. Every English meaning and every example sentence is
> original writing. No book sentence is reproduced anywhere in the app.**

- Four Coutinho NT2 textbooks supplied the four level bands. Two of them are scans with no
  text layer and were read by rendering vocabulary pages to images. **Their titles were
  deliberately removed from every user-visible string** and replaced with CEFR bands; the
  internal ids (`gang`, `actie`, `niveau`, `perfectie`) still carry the old names and must
  not be renamed (renaming would break stored progress).
- A commercial Teach Yourself dictionary supplied 484 Essential headwords. Its OCR is badly
  garbled with a systematic `a→o` substitution (`voetbal` → "voetbol", `aardappel` →
  "oardappel"), interleaved page columns and stray stress-mark apostrophes; every headword
  taken from it was hand-corrected. **Bulk import of that dictionary was deliberately
  rejected** on both quality and copyright grounds.
- **Coverage gap:** dictionary extraction covered a–h and v–z only. The letters **i–u were
  never extracted** — the PDF text layer stops at ~"haverklap". Finishing that range needs
  page-image rendering, as used for the scanned textbooks.

### 12.6 The 23 entries with no meaning and no examples

These are known extraction artifacts, deliberately left without invented content. A rebuild
may drop them, repair the headwords, or keep them as-is — but should decide consciously:

`taptap`, `met z’n (twintigen)`, `dezelfde` (with a stray U+0007 bell character),
`hersenen / hersens`, `Eigen vocabulaire`, `ruzie, de (met / over)`,
`invloed, de (‒ hebben (op))`, `lenen, zich ‒ voor`, `zowel ‒ als`,
`dwingen ‒ dwong ‒ gedwongen`, `ontvangen ‒ ontving ‒ ontvangen`,
`terugvragen ‒ vroeg terug ‒ terug-­`, `uitgaan ‒ ging uit ‒ is uitgegaan`,
`verdwijnen ‒ verdween ‒ is verdwenen`, `meegaan in / met`, `richten, (zich) ‒ op`,
`(zich) richten op`, `deelnemen ‒ nam deel ‒ deelgenomen`,
`insluipen ‒ sloop in ‒ is ingeslopen`, `klinken ‒ klonk ‒ geklonken`,
`opnemen ‒ nam op ‒ opgenomen`, `overslaan ‒ sloeg over ‒ overgeslagen`,
`schrikken ‒ schrok ‒ is geschrokken`.

Most are verb principal-part lines or cross-reference headers that were parsed as if they
were words. Two entries (`(zich) richten op` and `richten, (zich) ‒ op`) are the same lemma
in two formats.

### 12.7 Decisions this document deliberately does not make

1. Whether to keep three full themes natively, or ship one theme plus a light/dark pair.
   Three complete layouts is a large native cost that a web CSS file gets almost free.
2. Whether the six study modes all earn their place, or whether some should be merged.
3. Whether the Free limits (150 / 500 / 200 / 0 / 0 / 0) are the right commercial shape.
4. Whether the deck should be shipped whole or downloaded per level band.
5. Whether the app should keep the name "Dutch To Go" (internal identifiers still say
   `dutch5k` everywhere, on purpose).

---

## Appendix A — File manifest of the current build

| Path | Bytes | Role |
|---|---|---|
| `public/index.html` | 1,837,589 | The entire application: markup, CSS, JavaScript and all bundled data |
| `public/sw.js` | 1,061 | Service worker; holds the cache version tag |
| `public/site.webmanifest` | 605 | PWA manifest |
| `public/favicon.ico` | 8,569 | 16/32/48 multi-size icon |
| `public/favicon.svg` | 69,456 | SVG wrapper around a 180px PNG |
| `public/favicon-32.png` | 2,441 | Unreferenced |
| `public/apple-touch-icon.png` | 51,975 | 180×180 |
| `public/icon-192.png` | 57,639 | 192×192 |
| `public/icon-512.png` | 309,586 | 512×512 |
| `public/icon-maskable-512.png` | 226,278 | 512×512 maskable |
| `public/og-image.png` | 387,625 | 1200×630 share card |
| `public/i18n/{bg,de,es,fr,it,pl,pt,ru,tr,uk}.json` | 768,461 – 1,224,999 each | Content translation packs |
| `wrangler.jsonc` | 172 | Cloudflare Workers config |
| `CLAUDE.md` | 107,502 | The project's development history and conventions |
| `README.md` | 456 | Out of date (§12.3.12) |
| `scratchpad/make_icons.py` | — | Icon generator (stale, §12.2.3) |
| `scratchpad/i18n_extract.js`, `i18n_translate.py`, `i18n_check.py` | — | Translation-pack pipeline |
| `scratchpad/preview.py` | — | Local preview helper |

## Appendix B — Source structure of `index.html`

For anyone who needs to work against the original file rather than this document:

| Lines | Contents |
|---|---|
| 1–38 | `<head>`: title, metas, icon links, Google Fonts |
| 39–702 | The single `<style>` block: tokens, base, components, then the two theme blocks |
| 703–710 | The synchronous anti-flash theme script |
| 711–742 | `<body>` markup: topbar, header, nav, scrim, drawer, `<main>`, toast |
| 745–762 | The `Store` adapter |
| 766–1676 | Data blobs: `FREQ`, `SEED`, `TRANS`, `BOOKS`, `NIVEAU`, `PERFECTIE` |
| 1677–1770 | Module state, `FREE_LIMITS`, `THEMES`, `LANGS` |
| 1772–2537 | `UI` dictionaries and the six `UI_Vnn` merge blocks |
| 2539–2604 | `T`, `ct`, `langLocale`, `loadLangDict`, `applyNavLang`, `setLang`, goal helpers |
| 2605–2721 | `POS_LABELS`, `POS_FILTER`, `srcFilterOpts`, the dropdown registry and handlers, `posOf`, `bookTag`, `entryId` |
| 2723–7998 | `BOOKEX`, `GENEX`, `JUNK`, `ESSENTIAL` |
| 7999–8205 | `buildDeck`, `computeFree`, `isLocked`, `freeFirst`, `searchScore`, `bookChapters`, `inSource` |
| 8207–8296 | `migrate`, `init` |
| 8298–8345 | Spaced repetition |
| 8347–8475 | Queue, counting helpers, `SRC_ORDER` / `SRC_SHORT` / `SRC_COLORVAR` |
| 8477–8628 | Actions: `mark`, `flip`, `setTab`, `LEARN_MODES`, `setMode`, streak, plan, goal |
| 8630–8733 | Theme, drawer, `renderMenu` |
| 8734–8887 | Contact form, Pro |
| 8889–8983 | Menu open/close, reminders |
| 8985–9140 | AI enrichment (dormant), export/import (dormant) |
| 9142–9355 | Render helpers, word navigation, haptics, speech, answer checking |
| 9357–9612 | `renderWordList`, the Learn card renderers, `renderLearn` |
| 9614–9850 | `render` and the Progress tab |
| 9851–9962 | `goalBoxHtml`, `studyPlanHtml` |
| 9964–10160 | Profile, account actions, `renderProfile` |
| 10162–10181 | Service-worker registration and `init()` |

---

*End of specification. Revisions should amend numbered clauses in place and note the change
against the section number.*
