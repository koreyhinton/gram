# GRAM

Diagram tool (wip, being rebuilt as a linux native application)

gram opens a folder of `.svg` diagrams as a tree, draws them natively, and hands text editing to your own editor. It's written in Rust with [macroquad](https://github.com/not-fl3/macroquad), and its source is generated from bash scripts with [orc](https://github.com/koreyhinton/orc).

## Setup

- Rust 1.88 or newer.
- orc cloned next to this repo, at the version gram is pinned to:

  ```bash
  git clone https://github.com/koreyhinton/orc ../orc
  git -C ../orc checkout core/v0.1.0
  ```

## Build and run

```bash
./build.sh                             # generates src/main.rs from src/*.sh
cargo run -- docs                      # a folder: its .svg files as a tree
cargo run -- docs/concave-fill.svg     # a file: its folder, with the file open
```

Run `./build.sh` again after changing any `src/*.sh`. `src/main.rs` is generated: never edit it.

## Editing with Emacs

gram edits text in your editor: `$GRAM_EDITOR`, else `$VISUAL`, else `$EDITOR`, else `xdg-open`. With Emacs, run the two side by side:

1. Start Emacs on its own and run `M-x server-start`.
2. Start gram, pointed at that Emacs:

   ```bash
   GRAM_EDITOR=emacsclient cargo run -- docs
   ```

3. In gram, select a node and press **Enter**. It opens in Emacs as XML. Edit it and finish with `C-x #` (or kill the buffer with `C-x k`). gram applies the edit when emacsclient returns.

Without `M-x server-start`, emacsclient fails at once with "can't find socket", and gram shows that in its banner. `GRAM_EDITOR=emacs` needs no server, but starts a new Emacs for every edit, which you quit to finish (`C-x C-c`).

## Using gram

| | |
|---|---|
| click a file in the tree | open it |
| click a folder in the tree | fold or unfold it |
| **edit** button (the open file's row) | open the page's own file in the editor; gram reloads it on each save |
| click a node | select it, or deselect it if it's selected; the last one selected (green) is the one Enter edits |
| **Enter** | edit the green node in the editor; the change carries over to the other selected nodes |
| **Esc** | deselect all, or drop a refused edit |
| **R** | reopen a refused edit in the editor |
| **0**–**9** | pick the mode (only 0, select, does anything yet) |
| wheel | zoom about the cursor (over the tree: scroll it) |
| middle-drag, or Space + drag | pan |
| **F** or **Home** | fit the page to the window |

The line above the status bar lists what applies right now. A `*` beside a file means unsaved changes; saving comes in a later step of the port (see `PLAN.md`).

## Tests

```bash
./test.sh          # generates tests/*.rs from tests/*.test.sh, then cargo test
tests/mutate.sh    # breaks each feature in turn; a test must catch every break
```

## The port

gram replaces the old JS/PHP web app by replaying its history commit by commit. `PLAN.md` has the steps and progress, and `CLAUDE.md` the lasting rules.
