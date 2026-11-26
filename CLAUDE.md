# gram

A diagram editor (activity and UML diagrams) in Rust with macroquad. `gram <folder>` opens a folder, lists its `.svg` files as a tree, draws them natively, and saves back to SVG. Text editing goes to an external editor such as emacs. The Rust source is generated: bash scripts print Rust code, assembled with [orc](https://github.com/koreyhinton/orc) (cloned at `../orc`).

The app is being ported from the old JS/PHP web app by replaying its history commit by commit. `PLAN.md` holds the steps and progress. The old repos are under `history/` (gitignored): `devbox`, `act.svg` (plus `act.svg_v0.*` branch checkouts), `featured`, `gitwebby` and `gram-www`.

## Build and run

```bash
./build.sh   # runs src/main.sh, formats with rustfmt, writes src/main.rs
cargo run -- ~/diagram_root
```

- `src/main.rs` is generated and gitignored. Never edit it; edit the `.sh` files and run `./build.sh`.
- `build.sh` keeps the last good `main.rs` if rustfmt fails.
- `main.sh` prints `#![allow(non_snake_case)]` because orc names like `mn_join_Post` aren't snake case.
- `./test.sh` generates `tests/*.test.sh` into `tests/*.rs` (gitignored) and runs `cargo test`. Run `. ./orc-env.sh` before generating one test file by hand.
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
- Selection is shown by recoloring (edit color `#CAFFB5` for the last selected node, `#C0D6FC` for the others), with the original color cached. Anything written to disk or handed to the editor uses the cached color, never the selection color.
- Saves are atomic: write `<file>.tmp`, then rename it over the file.
- The document is a 750×750 page sheet at world (0, 0) on an infinite canvas (pan, zoom, adaptive grid). An R-tree (`rstar`) indexes node bounds; drawing culls through it but keeps document order. Text hit boxes use the JS per-character widths (`StartEndFrame.FromText`) until `PLAN.md` says otherwise, because tests depend on them.

## External editor

The app has no text-editing widgets. Text editing goes to the user's editor, the way git does.

- Pick the editor from `$GRAM_EDITOR`, then `$VISUAL`, then `$EDITOR`, then `xdg-open`. `emacsclient` with a running daemon is the fast path.
- Node edit: write the node's XML to a temp `node.svg` and spawn the editor (with `+line:col` when the cursor matters, such as a new text node's `?`). Never block the frame loop: check `try_wait()` each frame. While the editor is open, lock the canvas and show a banner. On exit, re-parse. If that fails, show the error and offer to reopen; if it succeeds, apply the edit to the node and map it onto the other selected nodes.
- Full SVG: shown read-only in the app. A key opens the page file itself in the editor, and the app reloads it when it changes on disk.
- Tests set `GRAM_EDITOR` to a script (e.g. `sed -i`) so editor round-trips run without a person.

## Folder tree

`gram <dir>` scans `<dir>` recursively for `.svg` files and shows a collapsible tree. This replaces the old web app's books, pages, add-page and clone. A new page is a new file in the selected folder, and clone copies a folder.

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
