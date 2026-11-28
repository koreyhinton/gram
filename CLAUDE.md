# gram

A diagram editor (activity and UML diagrams) in Rust with macroquad. `gram <folder>` opens a folder, lists its `.svg` files as a tree, draws them natively, and saves back to SVG. Text editing goes to an external editor such as emacs. The Rust source is generated: bash scripts print Rust code, assembled with [orc](https://github.com/koreyhinton/orc) (cloned at `../orc`).

The app is being ported from the old JS/PHP web app by replaying its history commit by commit. `PLAN.md` holds the steps and progress. The old repos are under `history/` (gitignored): `devbox`, `act.svg` (plus `act.svg_v0.*` branch checkouts), `featured`, `gitwebby` and `gram-www`.

## Build and run

```bash
./build.sh   # runs src/main.sh, formats with rustfmt, writes src/main.rs
cargo run -- diagrams     # a folder: its .svg files as a tree
cargo run -- docs/concave-fill.svg   # a file: its folder, with it open
```

- `src/main.rs` is generated and gitignored. Never edit it; edit the `.sh` files and run `./build.sh`.
- `build.sh` keeps the last good `main.rs` if rustfmt fails.
- `main.sh` prints `#![allow(non_snake_case)]` because orc names like `mn_join_Post` aren't snake case.
- `./test.sh` generates `tests/*.test.sh` into `tests/*.rs` (gitignored) and runs `cargo test`. Run `. ./orc-env.sh` before generating one test file by hand.
- `orc-env.sh` pins orc's core version (`0.1.0`), and CI checks out the matching tag (`ref: core/v0.1.0`). A different `../orc` stops the build. Bump both together to move to a newer orc.
- `tests/mutate.sh` checks that the tests fail when a snippet is missing or broken.
- `src/models.sh` prints the app's constants and types (Node, Doc, Selection, ...). `main.sh` and the tests both print it, so snippets compile against the same definitions everywhere.

## Assembling code with orc

- `src/main.sh` is the app. It prints the program and inlines snippets with backticks: `` ` ./hit-test.sh ${v}hit_ ` ``.
- Snippets (`src/*.sh`) print straight-line Rust that works anywhere it's inlined. Follow orc's rules in `../orc/CLAUDE.md`.
- `v` is the bash namespace variable. `main.sh` sets `v=${1:-mn_}`, and each snippet takes its namespace as `v=$1`.
- Map a snippet's inputs to Rust names in `main.sh` with exports (`export ${v}hit_Nodes=doc.nodes`). Inside the snippet, bind them with `. ${NSMAP}/bind ${v} Nodes Pos` and use them as `${!nodes}`, `${!pos}`.
- Outputs left unmapped get the namespaced name (`mn_join_Post`).
- App snippets don't need orc's interface header comment. That's only for reusable snippets added to the orc library.
- If an orc library is used, set its path and version in `orc-env.sh` and run its `models.sh` between heredocs in `main.sh`, so a version mismatch stops the build.

## Don't use `v` as a name

`bind` turns each name into a lowercase shell variable (`Vel` becomes `vel`). A bind name of `V` would create a shell variable `v` and overwrite the namespace, so later `${v}...` names in that snippet would come out wrong.

- Don't bind a name that lowercases to `v`, or to anything else the snippet uses in bash (`priv`, `bind_*`).
- Don't name a Rust variable `v`. Use a descriptive name such as `vel`, so it maps to a bind name that's safe.

## The model and SVG files

- A node is `{ tag, attrs: Vec<(String, String)>, text, bounds }`. Keep attributes as an ordered list, not typed fields, so unknown attributes and the original order survive a save.
- Parse with `quick-xml`. Serialization is hand-written, ported from the JS `nd2xml`/`nds2xml`.
- Selection is shown by recoloring (edit color `#CAFFB5` for the last selected node, `#C0D6FC` for the others). Only the drawing is recolored (`draw-doc.sh`); the node keeps its own color, so anything written to disk or handed to the editor has the real color, never the selection color.
- A node's `parent` is the index of its enclosing element (a `<g>`). Elements with no shape (`<g>`, `<defs>`, `<title>`) stay out of the R-tree and take no clicks.
- Groups: a **right-click** selects every shape inside the nearest `<g>` (`select-group.sh`), the clicked node last; each further right-click goes one `<g>` up, and a left click goes back to single nodes. A group is a selection, nothing more: every action (edit, map, and later move, copy, delete) works on the shapes, never on the `<g>`, and a `<g>` that ends up empty stays in the file. Shapes take a `<g>`'s styles (`INHERITED_ATTRS`) unless they set their own. `transform` isn't drawn; a page that uses it says so. When saving arrives, it must write the nesting back, not flatten it.
- Saves are atomic: write `<file>.tmp`, then rename it over the file.
- The document is a 750×750 page sheet at world (0, 0) on an infinite canvas (pan, zoom, adaptive grid). An R-tree (`rstar`) indexes node bounds; drawing culls through it but keeps document order. Text hit boxes use the JS per-character widths (`StartEndFrame.FromText`) until `PLAN.md` says otherwise, because tests depend on them.

## External editor

The app has no text-editing widgets. Text editing goes to the user's editor, the way git does.

- Pick the editor from `$GRAM_EDITOR`, then `$VISUAL`, then `$EDITOR`, then `xdg-open`. `emacsclient` is the fast path, but it needs a running Emacs server: open Emacs on its own first and run `M-x server-start`, then start gram with `GRAM_EDITOR=emacsclient`. Without a server, emacsclient exits at once with "can't find socket", and gram shows the failure in its banner. Finish each edit with `C-x #`, which is when emacsclient exits and gram applies the edit. Plain `GRAM_EDITOR=emacs` needs no server but starts a new Emacs for each edit.
- Node edit: **Enter** writes the last selected node's XML to a temp `node.xml` (not `.svg`: one element isn't a whole SVG, and Emacs opens `.svg` in `image-mode`, which shows a broken picture until `C-c C-c`) and spawns the editor (with `+line:col` when the cursor matters, such as a new text node's `?`). Never block the frame loop: check `try_wait()` each frame (`editor-poll.sh`). While the editor is open, lock the canvas (no select, keys or edits; pan and zoom still work) and show a banner. On exit: unchanged text does nothing. Changed text must parse as exactly one element; then apply it to the node (`node-apply.sh`: update or add attributes, never remove), map it onto the other selected nodes (`map.sh`), deselect all and mark the page dirty. If it fails, the banner shows why: **R** reopens the editor, **Esc** drops the edit.
- Full SVG: no in-app pane. The **edit** button at the end of the open page's tree row opens the page file itself in the editor. gram reloads the page on each save (`file-watch.sh`: modified time or length) and stops when the editor exits. An editor that returns at once (`xdg-open`, `emacsclient -n`) handed the file off, so gram keeps watching until **Esc**. A page with unsaved changes warns first: the file's text replaces them, so a second click within 5 seconds opens it.
- Selection: a left click on the canvas selects or deselects the node under it; the last selected is the one being edited. **Esc** deselects all. **0–9** set the mode, shown in the HUD and, for 3 seconds, in a notice at the top right ("0 => Select Mode", "1 => Line Mode", "N => Coming Soon" until a step gives that mode a job). In line mode (1, `add-line.sh`), a click starts a line and the next ends it; picking a mode or Esc drops a first click. A click on a text inside a shape picks the text. The hint line above the status line (`hud-hints.sh`) says what applies now: with a selection, that Enter edits the `<tag>` being edited, a second click deselects, and Esc deselects all. Keep it up to date as steps add keys and modes.
- Tests set `GRAM_EDITOR` to a script (e.g. `sed -i`) so editor round-trips run without a person, or pass the command straight to `editor-open.sh`.

## Folder tree

`gram <dir>` scans `<dir>` recursively for `.svg` files and shows a collapsible tree. `gram <file.svg>` opens the file's folder with the file open. This replaces the old web app's books, pages, add-page and clone. A new page is a new file in the selected folder, and clone copies a folder.

- The tree lists folders before files, each by name ignoring case. Hidden entries, folders with no `.svg` inside, and symlinked folders are left out.
- Each opened file is a `Page` in the `Workspace` (`src/models.sh`), kept while gram runs, so switching back finds it as it was left. Per-file state (canvas, selection, editor, unsaved changes) goes on the `Page`, never in globals.
- A file that can't be read or parsed opens as a page showing the error, and gram keeps running.
- The tree takes the mouse over its panel (`TREE_W`); the canvas takes it elsewhere.

## Native first

The target is a native desktop app. WASM is a nice-to-have: keep process spawning, file watching and filesystem code behind `cfg(not(target_arch = "wasm32"))`, but don't design for the web.

## Replaying history

Follow the method in `PLAN.md` for every step. In short:

- Read the old commit (`git -C history/<repo> show <hash>`) and its `doc/changelog` and `doc/changetask` notes.
- Port its tests first. A JS `TDD TEST N` becomes `#[test] fn tdd_NN_<slug>` in `tests/<area>.test.sh`. Drive input through stubbed macroquad functions, as in a scripted mouse, and assert on the model and the serialized SVG. Subtract the old frame offset `(750, 88)` from the JS `clientX`/`clientY` values.
- A test that changed in a later commit is changed at that later step, not before.
- Each `// TDDTEST N FTR` or `FIX` marker becomes a mutant in `tests/mutate.sh` ("missing" for FTR, "bug" for FIX).
- Web-only work (PHP, login, iframes, URL params, JS bundling) is skipped and noted in the commit body.
- Commit message: `replay <repo>@<hash> (<date>): <subject>`, with a body listing ported tests, skips and deviations. Tick the step in `PLAN.md`.
- Commits are paired with historical commits. The exception is work the browser did for free, such as parsing and drawing SVG. That goes in an unpaired `prep: <what>` commit that does only what the next paired step needs, and it gets its own row in `PLAN.md` first.
- The trunk is linear and keeps every feature in date order, including branches that never merged. If a later step conflicts with an earlier branch-only feature, stop and ask, then record the decision in `PLAN.md`.
