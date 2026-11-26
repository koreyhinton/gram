# Port plan: replay gram's history as a native Rust + macroquad app

## Why

gram began as devbox's `www/svg/ActSvg*`, became act.svg, and then gram-www. It is a browser SVG diagram editor: JS, plus a PHP server for books and pages. The goal is a native Rust + macroquad app that:

- draws the shapes itself, and still reads and writes `.svg` files on disk;
- opens a folder from the command line (`gram ~/diagram_root`) and shows its `.svg` files as an IDE-style tree, instead of flat book/page dropdowns;
- hands text editing to a real editor such as emacs, the way git does;
- is built the everkeep way: bash snippets print Rust, assembled with orc (see `CLAUDE.md`).

The port replays every gram/act.svg commit in date order, starting from devbox's first `www/svg` commit. That includes branches that never reached main: the v0.2 button-bar branch, v0.3 and v0.4. Each commit's added or changed tests are ported into Rust at the step where they appeared.

`CLAUDE.md` holds the lasting rules: the model, the external editor, the folder tree, and the per-step method. This file holds the steps and progress.

## Where the history lives

| repo (`history/…`) | what | used for |
|---|---|---|
| `devbox` | `www/svg/ActSvg*`, 2022-06 to 2022-11, plus one late change in 2024-11 | steps 1, 3–12, 48 (`-- www/svg` only) |
| `act.svg` | all act.svg branches (`origin/mainb/*`) | steps 13–46, 49, 51, 53 |
| `act.svg_v0.0` … `act.svg_v0.4` | checkouts of each branch | browsing a version's files |
| `gitwebby` | a re-home of v0.2 under `src/lib/act-frame` | step 47 |
| `featured` | Selenium tests run against several versions | steps 50, 52 |
| `gram-www` | v0.2 plus the 2026 gram commits | steps 54–59 |

How the branches relate: v0.3, v0.4 and the 2026 gram commits each branch from `8bbe93d` (the v0.2 merge). The button-bar branch comes from `b2e4ba3`. None of them merged into the others.

## Method for each step

1. **Read** the commit: `git -C history/<repo> show <hash>`, plus `doc/changelog`, `doc/changetask/<CT#>` and `doc/changeboard` when present. For devbox, add `-- www/svg`.
2. **Tests first.** Port every `TDD TEST N` the diff adds or changes into `tests/<area>.test.sh` as `#[test] fn tdd_NN_<slug>`. Drive the mouse, keys and frames through stubbed macroquad functions, as in everkeep's `tests/drag-select.test.sh`. Assert on the model and on the serialized SVG string; "stroke is editColor" becomes a check on selection state and the serialized color. Subtract the JS frame offset `(750, 88)` from the JS `clientX`/`clientY` values.
3. **Implement** or change snippets until `./test.sh` passes.
4. **Mutants.** Turn each `// TDDTEST N FTR` or `FIX` marker into a `tests/mutate.sh` mutant. This replaces the JS `test/test` toggle list (`5 35 57 58 75 76 77 78 80 81 82 83 84`).
5. **Commit:** `replay <repo>@<hash> (<date>): <subject>`, with a body listing the tests ported, what was skipped and any deviation. Tick the step below.

**Paired and unpaired commits.** Almost every gram commit is paired: it matches one historical commit, or a group of them, and uses the `replay` message. A few steps have no historical match because the browser did the work for free, such as parsing and drawing SVG. Those are unpaired steps (`unpaired` in the table). They use the message `prep: <what>` and do only what the next paired step needs. Step 0 (scaffold) and step 2 (render) are unpaired. Add another only when a paired step can't be done without it, and add it to the table first.

Steps with no JS tests still get a Rust test when they add behavior, such as a load/save round-trip, a tree scan or an editor round-trip.

Merge commits are only checked for conflict resolutions; the actual changes are ported at their original commits. Web-only work is skipped: PHP, login, iframe `postMessage`, URL params, JS bundling (saxophone, fast-xml-parser, browserify), nightwatch, playwright and Selenium plumbing.

## Target layout

```
build.sh  test.sh  orc-env.sh
src/main.sh        the app: window, frame loop, wiring
src/models.sh      Node, Doc, Selection, Mode, colors, canvas size
src/*.sh           snippets, added as the replay reaches them:
                   svg-load, svg-save, draw-doc, hit-test, issue-click,
                   select, rect-select, move, snap, map, vertex-resize,
                   cmd-parse, clipboard, editor, text-pane, tree, save
tests/*.test.sh    generated into tests/*.rs
tests/mutate.sh
```

Crates: `macroquad`, `quick-xml` and `rstar`, plus a clipboard crate if macroquad's clipboard isn't enough (step 30). Text uses the bundled `assets/LiberationSerif-Regular.ttf` (SIL OFL, `assets/Liberation-LICENSE.txt`), which has Times New Roman's metrics. The old app's CSS set Courier New on the page body, but the diagrams' boxes and the `StartEndFrame.FromText` widths (narrow `i`/`l`/`t`, wide `H`/`W`) were sized for a proportional serif font, which is how a browser shows the `.svg` files. Liberation Mono overflowed the boxes.

## Decisions log

Record here any conflict between a later step and an earlier branch-only feature, along with how it was resolved.

- Steps 0–2 (pre-parity): the canvas goes beyond the browser with an infinite canvas, adaptive grid and R-tree. Hit-testing at step 3 should query the R-tree, then apply the JS ordering (`sortedSvgNodes`: text first, swimlanes and classes last).
- Step 54 (gram-www@10fa0f8, the book mockup) comes before step 3, out of date order. The folder tree and per-page state are what every later step builds on: selection, the editor process, undo and the save path all live on a `Page`, so building them first saves retrofitting steps 3–53 onto a one-file app. The mockup doesn't depend on any earlier step: its dropdowns become the tree, and its `*` (unsaved changes) becomes `Page.dirty`, which nothing sets until step 3 edits a node. Its PHP login, title and font changes are web-only.
- Steps 0–2: CI comes before its paired step (15), as an agreed exception to pairing, because the pre-parity commit already has tests. `.github/workflows/rust.yml` mirrors everkeep's: it checks out gram and orc side by side (`../orc`), then runs `./test.sh` and `tests/mutate.sh`.
- Steps 0–2: three samples (`diagrams/act (15).svg`, `act(1).svg`, `act(2).svg`) are truncated: each stops right after the first `stroke="` or `fill="` whose value was a hex color. The old "save to file" button (`js/xml-buttons.js`, step 16) built `'data:image/svg+xml,' + encodeURI(xml)`, and `encodeURI` leaves `#` alone, so the browser took the first `#` as the start of a URL fragment and saved only what came before it. The rest is lost. gram opens each as a page showing the parse error instead of the drawing, as a browser would, and keeps running. At step 16, gram writes the file directly, so the bug doesn't carry over; note it in that step's commit body.

## Steps

⑂ marks a branch that never merged into main. T lists the JS tests added or changed. Bare hashes are in `act.svg` unless another repo is named.

| ✓ | # | date | commits | what | T |
|---|---|---|---|---|---|
| [x] | 0 | — | scaffold | Cargo, macroquad, quick-xml, `build.sh`/`test.sh`/`orc-env.sh`/`mutate.sh`, empty window, `gram <path>` argument, `.gitignore` | — |
| [x] | 1 | 2022-06-18 | devbox@8ea4b82 | `svgdecode` TODO stub, pseudocode only. It went with `adm/bin/stage-scratch`, which kept Scratch projects in git as readable source (unzipped `.sb3`, formatted `project.json`, costume `.svg` files run through `xmlindent`). Costumes can hold `<image>` embeds as base64 `data:` URIs, one unreadable line each; `svgdecode` planned to decode an embedded SVG and inline it as a nested `<svg>`, so each costume stayed one file but read and diffed as XML. Unrelated to the editor, so no code. Worth revisiting if gram ever reads `<image>` with a `data:` URI | — |
| [x] | 2 | — | unpaired | render: `gram <file.svg>` parses the SVG into the model and draws the supported elements (line, polyline, rect with rx/ry, circle, text; fill, stroke, dasharray, font-size, text-decoration) as macroquad shapes. The browser did this for free, so no historical commit matches it. Beyond the browser: an infinite canvas (pan, cursor-anchored zoom, fit), a multi-level adaptive grid and an R-tree (`rstar`) for culling | — |
| [x] | 2a | — | unpaired | external editor: pick the editor (`$GRAM_EDITOR`, `$VISUAL`, `$EDITOR`, `xdg-open`), spawn it on a file, poll it each frame with `try_wait()`, and watch the file for saves (modified time and length). The browser's textareas did this for free; step 3's node edit and the file's edit button need it | — |
| [ ] | 3 | 2022-09-03 | devbox@c702432 | select by click (selection colors); node edit via the external editor; read-only full SVG pane. Selection, the editor process and the pane belong to the `Page`; an edit sets `Page.dirty`. Decide here: the old `getscal` returned -999 for a missing attribute, so a rect without `stroke-width` had a click box 999 larger all round; gram's boxes read a missing number as 0 | — |
| [ ] | 4 | 2022-09-04 | devbox@8c8c666 | follow-ups | — |
| [ ] | 5 | 2022-09-05 | devbox@ed1a227 | | 0, 1, 2 |
| [ ] | 6 | 2022-09-07 | devbox@8faf51d | | 3–7 |
| [ ] | 7 | 2022-09-08 | devbox@01c476e | | 8–14 |
| [ ] | 8 | 2022-10-08 | devbox@805fd51 | | 0, 15, 16 |
| [ ] | 9 | 2022-10-09 | devbox@8a8a291 | | 17 |
| [ ] | 10 | 2022-10-29 | devbox@11b5deb | move | 18 |
| [ ] | 11 | 2022-11-08 | devbox@716c2d6 | | — |
| [ ] | 12 | 2022-11-11 | devbox@c8a9616 | template (swim3) | — |
| [ ] | 13 | 2022-11-12 | 56bb48b | copy into act.svg. Diff against step 12 and port only what changed | check 0–18 |
| [ ] | 14 | 2022-11-13 | 254fa71 | README | — |
| [ ] | 15 | 2022-11-17 | 2adf2a0, 9a5a1d4, 1f4f0e7, c912cfa, b5f2608 | CI: test runner and a GitHub workflow that runs `./test.sh`. The workflow already exists (added early, see the decisions log), so this step only ports what else these commits changed, such as the force-fail test and its removal | 0, 2, 7, 18 |
| [ ] | 16 | 2022-11-19 | e1fd4b7, df9a465 | XML buttons: open, copy, save to file | 19, 20 |
| [ ] | 17 | 2022-11-20 | 4353b84 | node management: rect select, drag | 21–24 |
| [ ] | 18 | 2022-11-24 | ce35ebe, de3c340 | node management, XML buttons | 21–27 |
| [ ] | 19 | 2022-11-25..29 | 31af1e4, e1d6cc2, d74e2ad, 7e85b1a, f7da138 | ids, cut/copy, focus on a new text node (editor `+line:col`) | 28–31 |
| [ ] | 20 | 2022-12-16 | e4cea0f | cleanup UI | — |
| [ ] | 21 | 2022-12-17..23 | a1a4829, 895b960, 31e25cf | add-on palettes: swim3, pins, connectors, collab, decision | — |
| [ ] | 22 | 2022-12-26..27 | 606a68a, a8e194d, 5d570e9 | fix draw tests | 0, 2–4, 7, 9, 15, 16, 18, 23–26 |
| [ ] | 23 | 2022-12-29..31 | 8fcef75, 05ff419 | node mappings | 32–37 |
| [ ] | 24 | 2023-01-01..05 | b5717ba, fbc4dc3, 0e046f2, 62df140, 1079359 | | 38–41 |
| [ ] | 25 | 2023-01-07..08 | 39009e2, 89f5337 | node movement | 18, 33, 42 |
| [ ] | 26 | 2023-01-15..16 | 0f89672, 0aea5c6 | nearest-edge select, right-click | 43, 44 |
| [ ] | 27 | 2023-01-28 | bcea0a4 | node movement | 32, 45, 46 |
| [ ] | 28 | 2023-02-05 | 4fb7de7 | node movement | 47 |
| [ ] | 29 | 2023-02-11..12 | 78cb2bb, faa10f3 | text bounds | 1, 48–50 |
| [ ] | 30 | 2023-02-18..19 | 6669c7c, 1266eb6 | paste from the clipboard | 51–55 |
| [ ] | 31 | 2023-02-26 | 3388b6d (merge e2d76eb) | palettes; end of v0.1 | — |
| [ ] | 32 | 2023-03-04..25 | 5d7d83a, 469c073, d920b80, b2e4ba3 | start of v0.2 | 35, 36 |
| [ ] | 33 | 2023-03-26 | 0df10e6 | node command | 56 |
| [ ] | 34 | 2023-04-01 | 2d7f062 | XML editing (the JS xeEditor). In gram this is the external-editor flow | — |
| [ ] | 35 | 2023-04-02..09 | 5ee0b47, 3232039, 51b0eae | node drawing (drag to draw) | 56–58 |
| [ ] | 36 | 2023-04-09..23 | f73c402, 340b5a4, 0a3c390 | node command `setx`/`incx`/`setw`/… | 56, 59–67 |
| [ ] | 37 | 2023-04-22..29 | 17b61ec, a87866e | XML editing | 50, 68–72 |
| [ ] | 38 | 2023-05-20..28 | 8f10aca, 3d2c9c4, b1e236a, b248857 | resize by vertex | 35, 57, 58, 73–75 |
| [ ] | 39 ⑂ | 2023-06-03 | 43efa52 | button bar (branch only) | — |
| [ ] | 40 | 2023-06-03 | a4a55bd, e966f26 | node drawing, inverse-y vertex fix | 57, 77, 78 |
| [ ] | 41 | 2023-06-03 | 41b4335, fe89505 (octopus 3961775, 29fb30d, d5d92f8, 2dbc830) | node-mapping patch. Check the merges for conflict resolutions only | 45, 46, 76 |
| [ ] | 42 | 2023-06-03..24 | 4ed152b, 1164899, ac04003, e7f512e, b4f31fb (merge 8bbe93d) | end of v0.2 | 5, 79–84 |
| [ ] | 43 ⑂ | 2023-07-01..02 | 9201cc4, ef9cd19, 10b1939, bec110d | v0.3: async test placeholders; refactor of node select/delete | 18, 21–24, 30, 33, 37, 39, 50 |
| [ ] | 44 ⑂ | 2023-07-08..09 | 19ef414, b5409cf | v0.3: app mode and app key; save/next for main and sub-selection | 6, 18, 25, 28, 30, 50, 52, 53, 73 |
| [ ] | 45 ⑂ | 2023-07-15..16 | 274ae1f, 2890339, 65d14cf | v0.3: more drawing-mode buttons; decorator-pattern selection; mini selection icons | 6 |
| [ ] | 46 ⑂ | 2023-07-29..08-13 | 7c6233d, 183b866, 7345e5e, db710e5 | v0.3: save flow for full and part XML (Alt-s), mapped onto the editor | 3, 17, 28, 32, 37 |
| [ ] | 47 | 2024-09-29 | gitwebby@ee5d53e | re-home of v0.2. Diff it; probably no-op | — |
| [ ] | 48 | 2024-11-16 | devbox@5ed26d5 | late devbox-only change to `ActSvg.js`: a rect-select prototype (empty-space click, `lastX`/`lastY`, `mousemove`), committed alongside unrelated admin notes. act.svg had rect select since step 17, so compare the two and port only what differs | — |
| [ ] | 49 ⑂ | 2024-12-14..15 | b6a459b, 1d04079, 26c4540 | v0.4: game-flow type, svg script, example template | 85 |
| [ ] | 50 | 2024-12-21..2025-01-19 | featured@d5b9570 … d571113 | featured tests: port test-000 (select with one click) and test-001 (two-point draw for modes 1, 2, 3, 4, 8) as Rust tests | se-000, se-001 |
| [ ] | 51 ⑂ | 2025-01-26..02-09 | 10538c3, f80f0f0 | v0.4: game-flow rect; resize of action nodes | — |
| [ ] | 52 | 2025-02-14 | featured@0fe02e4 | featured tests reorganized as data-driven | — |
| [ ] | 53 ⑂ | 2025-02-15..16 | b42e917, e81c929 | v0.4: palettes and theme switching | — |
| [x] | 54 | 2026-01-08 | gram-www@10fa0f8 | book mockup. In gram this is the folder tree from `gram <dir>` (or `gram <file.svg>`, opening its folder), per-page state (`Page`, `Workspace`), load errors shown on the page, and the `*` for unsaved changes. Done before step 3 (see the decisions log). Its `+` (add page) and clone buttons had no behavior yet, so they come when a later step gives them one | — |
| [ ] | 55 | 2026-01-24 | gram-www@50d3c88 | Ctrl-S save and save indicator (atomic write) | — |
| [ ] | 56 | 2026-02-15 | gram-www@6480380 | refresh cache on save, narrower vertex, more accurate text selection. Revisit the text widths here | 1 |
| [ ] | 57 | 2026-02-21 | gram-www@70fc11b | fix line drawing in class diagrams | — |
| [ ] | 58 | 2026-02-21 | gram-www@dc3ce33 | alive poller. In gram this is a "changed on disk" indicator and reload | — |
| [ ] | 59 | 2026-03-28 | gram-www@8acc090 | featured tests in-repo, including test-002 (text width). PHP test plugs skipped | 1, 8, se-002 |

## Verification

- `./test.sh` passes at every step, and `tests/mutate.sh` kills every mutant.
- Round-trip: load each file in `diagrams/*.svg`, save it, and diff. Only whitespace may change.
- By hand: `cargo run -- ~/diagram_root` shows the tree. With `GRAM_EDITOR=emacsclient`, editing a node in emacs updates the canvas. A saved file looks the same in a browser.
