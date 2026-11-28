#!/bin/bash

# Mutation tests: checks that the tests fail when the app is broken or
# missing, not just that they pass when it works.
#
# Each mutant is a copy of the repo's scripts with one sed edit to one or
# more files, then the tests are generated and run against that copy:
#   missing   the whole snippet prints nothing, as before it was written (the
#             test-first state). Killed by any failure, a compile error too.
#   bug       one behavior broken. It must still compile, and killed only by
#             a failing test (a compile error is BROKEN: fix the sed).
# A mutant survives (bad) when every test passes. Exits 1 unless every mutant
# is killed.
#
# When a replay step ports a JS test whose code carries a "// TDDTEST N FTR"
# or "FIX" marker, add a mutant here for it: "missing" for FTR, "bug" for FIX.
#
# Mutants are built in target/mutants/crate, a copy of the crate that is kept
# between runs so cargo only recompiles test files a mutant changed. It
# shares the repo's target directory, so the dependencies aren't built twice,
# under its own package name (gram-mutant) so it never touches the real
# crate's test binaries.
#
# Usage: tests/mutate.sh [--changed[=<ref>]] [--name <pattern>] [--list]
#   (no options)      every mutant, then the pairing check: every test must
#                     kill at least one mutant, or it is reported UNPAIRED and
#                     the run fails. This is what CI runs.
#   --changed[=<ref>] only the mutants your changes against <ref> (default
#                     main, committed or not, new files too) can affect: those
#                     on a changed src/ file, those on a snippet a changed
#                     test file inlines, and those added or edited in this
#                     file. A quick local check; run the full suite before a PR.
#   --name <pattern>  only the mutants whose name matches the pattern (an
#                     extended regex, any case).
#   --list            print the mutants the other options pick, and stop.
# With either option the pairing check is skipped, since most mutants don't run.

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error, script must not be sourced. Run it without sourcing it" >&2
    return 1
fi

RN_CHANGED=""
RN_NAME=""
RN_LIST=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --changed) RN_CHANGED="main" ;;
        --changed=*) RN_CHANGED="${1#--changed=}" ;;
        --name)
            [[ $# -ge 2 ]] || { echo "--name needs a pattern" >&2; exit 2; }
            RN_NAME="$2"
            shift
            ;;
        --name=*) RN_NAME="${1#--name=}" ;;
        --list) RN_LIST=1 ;;
        -h | --help)
            sed -n '/^# Usage:/,/^# With either option/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "unknown option: $1 (see --help)" >&2
            exit 2
            ;;
    esac
    shift
done

RN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${RN_DIR}" || exit 1
. ./orc-env.sh || exit 1

RN_CRATE="${RN_DIR}/target/mutants/crate"
RN_LOGS="$(mktemp -d)"
trap 'rm -rf "${RN_LOGS}"' EXIT
export CARGO_TARGET_DIR="${RN_DIR}/target"

# mutants: a kind (missing or bug), a name, the files to edit (relative to
# the repo, space-separated), and the sed script to apply to each
MT_KINDS=()
MT_NAMES=()
MT_FILES=()
MT_SEDS=()
mutant() { MT_KINDS+=("$1"); MT_NAMES+=("$2"); MT_FILES+=("$3"); MT_SEDS+=("$4"); }

# ---- not implemented: each snippet the tests inline ----
for snippet in svg-load spatial-index canvas-update canvas-fit draw-grid draw-page \
    draw-doc draw-hud workspace-args tree-scan tree-click tree-draw page-error \
    editor-pick editor-open editor-poll file-watch mouse-rects hit-test select node-xml \
    node-apply map banner mode-notice hud-hints key-presses select-group transform-note \
    add-line history-push history-step select-all ctrl-keys; do
    mutant missing "${snippet}.sh not written" "src/${snippet}.sh" '/^cat << EOF$/,/^EOF$/d'
done

# ---- loading ----
mutant bug "invalid xml loads without an error" src/svg-load.sh \
    's/^\( *\)\${!error} = Some(format!($/\1let _ = Some(format!(/'
mutant bug "a broken attribute loads without an error" src/svg-load.sh \
    's/\${!error} = Some(format!("invalid attribute in/let _ = Some(format!("invalid attribute in/'
mutant bug "a file without an <svg> root loads without an error" src/svg-load.sh \
    's/    if \${!error}\.is_none() \&\& !\${v}seen_root {/    if false {/'
mutant bug "entities are dropped from text" src/svg-load.sh \
    "/\.text\.push('&');/d"
mutant bug "text boxes ignore the character widths" src/mouse-rects.sh \
    "s/'?' | 'A'..='B' | 'M'..='O' | 'R' | 'T' | 'V' => 11.0,/'?' | 'A'..='B' | 'M'..='O' | 'R' | 'T' | 'V' => 8.0,/"
mutant bug "text boxes aren't truncated like parseInt" src/mouse-rects.sh \
    's/min_x = x\.trunc() - 3\.0;/min_x = x - 3.0;/'
mutant bug "a rect box ignores its stroke" src/mouse-rects.sh \
    's/min_x = x - stroke_w;/min_x = x;/'
mutant bug "numbers with units are read as 0" src/models.sh \
    's/    text\[\.\.number_end\]\.parse::<f64>()\.unwrap_or(0\.0)/    text.trim().parse::<f64>().unwrap_or(0.0)/'
mutant bug "an exponent is ignored" src/models.sh \
    's/number_end = exp_end;/exp_end += 0;/'
mutant bug "the root's attributes are lost" src/svg-load.sh \
    '/\.root_attrs = attrs;/d'
mutant bug "a node's parent is lost" src/svg-load.sh \
    's/parent: \${v}open\.last()\.copied()\.flatten(),/parent: None,/'
mutant bug "an end tag doesn't close its element" src/svg-load.sh \
    '/\${v}open\.pop();/d'
mutant bug "elements with no shape are clickable" src/spatial-index.sh \
    's/if SHAPE_TAGS\.contains(\&\${v}node\.tag\.as_str()) {/if true {/'
mutant bug "the index skips the first node" src/spatial-index.sh \
    's/\.nodes\.iter()\.enumerate()/.nodes.iter().enumerate().skip(1)/'

# ---- the canvas ----
mutant bug "zoom isn't anchored at the cursor" src/canvas-update.sh \
    '/\.offset = \${v}world_before - /d'
mutant bug "zoom isn't clamped" src/canvas-update.sh \
    's/\.clamp(ZOOM_MIN, ZOOM_MAX);/;/'
mutant bug "a pan ignores the zoom" src/canvas-update.sh \
    's/last_mouse) \/ \${!canvas}\.zoom;/last_mouse);/'
mutant bug "a plain left drag pans" src/canvas-update.sh \
    's/(is_key_down(KeyCode::Space) \&\& is_mouse_button_down(MouseButton::Left))/is_mouse_button_down(MouseButton::Left)/'
mutant bug "a new drag jumps from the last mouse position" src/canvas-update.sh \
    's/if \${v}pan_held \&\& \${!canvas}\.panning {/if ${v}pan_held {/'
mutant bug "fit ignores the tree panel" src/canvas-fit.sh \
    's/vec2(\${!left} + (screen_width() - \${!left}) \* 0\.5,/vec2(screen_width() * 0.5,/'
mutant bug "fit doesn't center the page" src/canvas-fit.sh \
    's/\.offset = vec2(PAGE_W, PAGE_H) \* 0\.5/.offset = Vec2::ZERO * 0.5/'

# ---- the grid ----
mutant bug "the grid draws past the view" src/draw-grid.sh \
    's/        while x <= \${v}view\.x + \${v}view\.w {/        while x <= ${v}view.x + ${v}view.w * 3.0 {/'
mutant bug "the minor grid never fades" src/draw-grid.sh \
    's/GRID_MINOR\.a \* \${v}fade/GRID_MINOR.a/'
mutant bug "the minor grid never goes" src/draw-grid.sh \
    's/if \${v}fade > 0\.02 {/if true {/'
mutant bug "grid lines thicken as you zoom in" src/draw-grid.sh \
    's/1\.0 \/ \${!canvas}\.zoom,/1.0,/'
mutant bug "no axes" src/draw-grid.sh \
    's/let is_axis = axes \&\& /let is_axis = false \&\& /'

# ---- drawing ----
mutant bug "polylines fan like convex shapes" src/draw-doc.sh \
    's/if node\.tag != "polyline" {/if true {/'
mutant bug "an ear may hold another point" src/draw-doc.sh \
    's/if !holds_point {/if true {/'
mutant bug "transparent fills are drawn black" src/draw-doc.sh \
    's/paint = Some(None);/paint = None;/'
mutant bug "#rrggbb colors are ignored" src/draw-doc.sh \
    's/} else if hex\.len() == 6 /} else if hex.len() == 99 /'
mutant bug "nothing is culled" src/draw-doc.sh \
    's/\.locate_in_envelope_intersecting(rstar::AABB::from_corners(\${v}view_min, \${v}view_max))/.iter()/'
mutant bug "document order is lost" src/draw-doc.sh \
    '/\${v}ids\.sort_unstable();/d'
mutant bug "dashes are ignored" src/draw-doc.sh \
    's/let dashed = pattern\.iter()\.sum::<f32>() > 0\.0;/let dashed = false;/'
mutant bug "dashes restart at each segment" src/draw-doc.sh \
    's/^\( *\)let len = from\.distance(to);/\1let len = from.distance(to);\n\1dash_i = 0; dash_left = pattern.first().copied().unwrap_or(0.0); dash_on = true;/'
mutant bug "rounded corners are square" src/draw-doc.sh \
    's/if corner_x > 0\.0 \&\& corner_y > 0\.0 {/if false {/'
mutant bug "text shows its entities" src/draw-doc.sh \
    '/\.replace("&amp;", "&")/d'
mutant bug "font-size is ignored" src/draw-doc.sh \
    '/"font-size" => size_spec = /d'
mutant bug "text is rasterized at its world size" src/draw-doc.sh \
    's/let font_step = (screen_px\.log2()/let font_step = (text_size.log2()/'
mutant bug "every zoom level rasterizes its own glyph size" src/draw-doc.sh \
    's/let font_px = 2f32/let font_px = screen_px.min(TEXT_MAX_PX).round() + 0.0 * 2f32/'
mutant bug "glyphs are rasterized smaller than on screen" src/draw-doc.sh \
    's/let font_step = (screen_px\.log2() \* TEXT_PX_STEPS - 1e-3)\.ceil();/let font_step = (screen_px.log2() * TEXT_PX_STEPS).floor();/'
mutant bug "line-through is ignored" src/draw-doc.sh \
    's/let strike = decoration\.contains("line-through");/let strike = false;/'
mutant bug "underline is ignored" src/draw-doc.sh \
    's/let underline = decoration\.contains("underline");/let underline = false;/'
mutant bug "tiny text draws glyphs" src/draw-doc.sh \
    's/if screen_px < TEXT_LOD_PX {/if false {/'
mutant bug "the page border scales with zoom" src/draw-page.sh \
    's/2\.0 \/ \${!canvas}\.zoom/2.0/'
mutant bug "the HUD's mouse point ignores the zoom" src/draw-hud.sh \
    's/Vec2::from(mouse_position()) \/ \${!canvas}\.zoom/Vec2::from(mouse_position())/'

# ---- the workspace and the folder tree ----
mutant bug "a folder opens with itself as the open page" src/workspace-args.sh \
    's/^                \${!root} = path;$/                ${!open} = Some(path.clone()); ${!root} = path;/'
mutant bug "a click on a file row doesn't report it" src/tree-click.sh \
    's/            \${!clicked} = Some(entry\.path\.clone());/            let _ = \&entry.path;/'
mutant bug "clicks right of the tree panel act on it" src/tree-click.sh \
    's/let \${v}over = \${v}mouse\.x >= 0\.0 \&\& \${v}mouse\.x < TREE_W;/let ${v}over = ${v}mouse.x >= 0.0;/'
mutant bug "an .svg file opens nothing" src/workspace-args.sh \
    '/\${!open} = Some(path);/d'
mutant bug "any file is accepted" src/workspace-args.sh \
    's/} else if path\.is_file() \&\& is_svg {/} else if path.is_file() {/'
mutant bug "files sort before folders" src/tree-scan.sh \
    's/key\.push((is_file, name\.to_lowercase(), name\.clone()));/key.push((!is_file, name.to_lowercase(), name.clone()));/'
mutant bug "the sort minds case" src/tree-scan.sh \
    's/key\.push((is_file, name\.to_lowercase(), name\.clone()));/key.push((is_file, name.clone(), name.clone()));/'
mutant bug "hidden entries are listed" src/tree-scan.sh \
    "s/let hidden = item\.file_name()\.to_string_lossy()\.starts_with('\.');/let hidden = false;/"
mutant bug "symlinked folders are followed" src/tree-scan.sh \
    's/Ok(kind) => (kind\.is_dir(), kind\.is_symlink()),/Ok(kind) => (item.path().is_dir(), kind.is_symlink()),/'
mutant bug "a folded folder's rows still take clicks" src/tree-click.sh \
    's/if !hidden \&\& entry\.is_dir \&\& \${!collapsed}\.contains(\&entry\.path) {/if false {/'
mutant bug "a folder click reports the folder" src/tree-click.sh \
    's/} else if entry\.is_dir {/} else if false {/'
mutant bug "scrolling isn't clamped" src/tree-click.sh \
    '/\${!scroll} = \${!scroll}\.clamp(/d'
mutant bug "clicks ignore the scroll" src/tree-click.sh \
    's/(\${v}mouse\.y + \${!scroll} - TREE_PAD)/(${v}mouse.y - TREE_PAD)/'
mutant bug "the wheel scrolls the tree from the canvas" src/tree-click.sh \
    's/if \${v}over \&\& \${v}wheel_y != 0\.0 {/if ${v}wheel_y != 0.0 {/'
mutant bug "a folded folder's rows are drawn" src/tree-draw.sh \
    's/if !hidden \&\& folded {/if false {/'
mutant bug "the open page isn't highlighted" src/tree-draw.sh \
    's/let is_selected = \${!selected} == Some(entry\.path\.as_path());/let is_selected = false;/'
mutant bug "the edit button opens the file instead" src/tree-click.sh \
    's/        } else if on_button {/        } else if false {/'
mutant bug "a changed page has no star" src/tree-draw.sh \
    's/} else if page\.is_some_and(|page| page\.dirty) {/} else if false {/'
mutant bug "a failed page isn't red" src/tree-draw.sh \
    's/let color = if page\.is_some_and(|page| page\.error\.is_some()) {/let color = if false {/'
mutant bug "long names run off the panel" src/tree-draw.sh \
    's/while !label\.is_empty()/while false \&\& !label.is_empty()/'
mutant bug "rows are drawn ignoring the scroll" src/tree-draw.sh \
    's/\* TREE_ROW_H - \${!scroll};/* TREE_ROW_H;/'
mutant bug "the error isn't said" src/page-error.sh \
    '/draw_text(\${!error},/d'

# ---- the external editor ----
mutant bug "the editor fallback order is wrong" src/editor-pick.sh \
    's/\["GRAM_EDITOR", "VISUAL", "EDITOR"\]/["GRAM_EDITOR", "EDITOR", "VISUAL"]/'
mutant bug "a blank editor variable is used" src/editor-pick.sh \
    '/\.find(|value| !value\.trim()\.is_empty())/s/!value\.trim()\.is_empty()/true/'
mutant bug "a path with spaces splits" src/editor-open.sh \
    's/format!("{} \\"\\$1\\"", /format!("{} \\$1", /'
mutant bug "a failed editor isn't reported" src/editor-poll.sh \
    's/if !status\.success() {/if false {/'
mutant bug "the editor stays after it exits" src/editor-poll.sh \
    '/^    if \${!exited} {$/,/^    }$/d'
mutant bug "the reload misses a length-only change" src/file-watch.sh \
    's/\.map(|time| (time, meta\.len()))/.map(|time| (time, 0))/'
mutant bug "the watch never takes a new stamp" src/file-watch.sh \
    '/\${!stamp} = \${v}now;/d'

# ---- selecting and editing (step 3) ----
mutant bug "a click misses the box's edge" src/hit-test.sh \
    's/\.locate_all_at_point(\[\${!pos}\.x, \${!pos}\.y\])/.locate_all_at_point([${!pos}.x + 0.5, ${!pos}.y + 0.5])/'
mutant bug "overlaps give the last node, not the first" src/hit-test.sh \
    's/\.min_by_key(|id| (\${!doc}\.nodes\[\*id\]\.tag != "text", \*id));/.min_by_key(|id| (${!doc}.nodes[*id].tag != "text", usize::MAX - *id));/'
mutant bug "a second click doesn't deselect" src/select.sh \
    's/\${!selection}\.ids\.retain(|other| \*other != id);/let _ = id;/'
mutant bug "a new selection isn't the one being edited" src/select.sh \
    's/\${!selection}\.ids\.push(id);/${!selection}.ids.insert(0, id);/'
mutant bug "the selection colors are swapped" src/draw-doc.sh \
    's/let shown = Some(if last { EDIT_COLOR } else { SEL_COLOR });/let shown = Some(if last { SEL_COLOR } else { EDIT_COLOR });/'
mutant bug "a node with no stroke is recolored" src/draw-doc.sh \
    's/let mut inherited_color_attr: Option<\&str> = None;/let mut inherited_color_attr: Option<\&str> = Some("stroke");/'
mutant bug "node XML loses attribute order" src/node-xml.sh \
    's/for (name, value) in \${!node}\.attrs\.iter() {/for (name, value) in ${!node}.attrs.iter().rev() {/'
mutant bug "an edit removes the attributes it leaves out" src/node-apply.sh \
    's/\${!target}\.tag = \${!edited}\.tag\.clone();/${!target}.tag = ${!edited}.tag.clone(); ${!target}.attrs.clear();/'
mutant bug "an edit keeps the old tag" src/node-apply.sh \
    '/\${!target}\.tag = \${!edited}\.tag\.clone();/d'
mutant bug "map ignores y" src/map.sh \
    's/let \${v}dy = \${v}spots\[1\]\.1 - \${v}spots\[0\]\.1;/let ${v}dy = 0.0f64;/'
mutant bug "map skips polylines" src/map.sh \
    's/if maps \&\& is_polyline \&\& name == "points" {/if false {/'
mutant bug "map ignores stroke-width" src/map.sh \
    's/if widens \&\& name == "stroke-width" {/if false {/'
mutant bug "a circle's anchor is read as x, y" src/map.sh \
    's/let (x_name, y_name) = if node\.tag == "circle" { ("cx", "cy") } else { ("x", "y") };/let (x_name, y_name) = ("x", "y");/'

# ---- text nodes (step 4) ----
mutant bug "a label loses the click to its box" src/hit-test.sh \
    's/\.min_by_key(|id| (\${!doc}\.nodes\[\*id\]\.tag != "text", \*id));/.min_by_key(|id| (false, *id));/'
mutant bug "a selected text isn't recolored" src/draw-doc.sh \
    's/let colors_it = name == "stroke" || (name == "fill" \&\& node\.tag == "text");/let colors_it = name == "stroke";/'
mutant bug "node XML drops a text's text" src/node-xml.sh \
    's/    if \${!node}\.tag == "text" {/    if false {/'
mutant bug "a text edit keeps the old text" src/node-apply.sh \
    's/    if \${!target}\.tag == "text" {/    if false {/'
mutant bug "nodes of the same kind don't follow" src/map.sh \
    's/let maps = \${v}kinds\.contains(\&\${!after}\.tag\.as_str()) \&\& \${v}kinds\.contains(\&dest\.tag\.as_str());/let maps = ${v}kinds.contains(\&${!after}.tag.as_str()) \&\& ${v}kinds.contains(\&dest.tag.as_str()) \&\& ${!after}.tag != dest.tag;/'
mutant bug "text doesn't follow" src/map.sh \
    's/let \${v}kinds = \["rect", "circle", "polyline", "text"\];/let ${v}kinds = ["rect", "circle", "polyline"];/'
mutant bug "text pairs carry the stroke change" src/map.sh \
    's/let widens = maps \&\& \${!after}\.tag != "text" \&\& dest\.tag != "text";/let widens = maps;/'
mutant bug "the mode notice never goes away" src/mode-notice.sh \
    's/    if \${!since} < MODE_NOTICE_SECS {/    if true {/'
mutant bug "every mode says Select Mode" src/mode-notice.sh \
    's/        let text = match \${!mode} {/        let text = match 0u8 {/'

# ---- the status line's hints ----
mutant bug "the hints name the first selected, not the one being edited" src/hud-hints.sh \
    's/        \.last()$/        .first()/'
mutant bug "the HUD leaves out the hints" src/draw-hud.sh \
    '/    draw_text(\${!hints}, /d'

# ---- keys after the editor ----
mutant bug "a key after a lost release stays a repeat" src/key-presses.sh \
    's/if !repeat || after_lost_release {/if !repeat {/'
mutant bug "holding a key repeats its press" src/key-presses.sh \
    's/if !repeat || after_lost_release {/if true {/'
mutant bug "a lost key stays lost" src/key-presses.sh \
    '/^                \${!lost}\.retain(|held| \*held != key);$/d'

# ---- the old app's TDD tests (devbox@ed1a227) ----
# TDDTEST0 FIX: the old smartMap moved a rect's label through points, which
# a text doesn't have, so the label stayed put
mutant bug "a rect's edit moves its label through points" src/map.sh \
    's/let is_polyline = dest\.tag == "polyline";/let is_polyline = dest.tag == "polyline" || (dest.tag == "text" \&\& ${!after}.tag == "rect");/'
# TDDTEST1 FIX: the old 12 px a character made a label's box reach past its
# text, so a click beside it took the label, not its box
mutant bug "a label's box is 12 px a character" src/mouse-rects.sh \
    's/                max_x = x\.trunc() + width;/                max_x = x.trunc() + 12.0 * ${v}node.text.chars().count() as f32;/'
# TDDTEST2 FTR (line mode) is the missing add-line.sh above
mutant bug "a line's ends aren't rounded" src/add-line.sh \
    's/let \${v}at = \${!pos}\.round() + Vec2::ZERO;/let ${v}at = ${!pos} + Vec2::ZERO;/'
mutant bug "a line's first click stays after it's drawn" src/add-line.sh \
    's/    match \${!from}\.take() {/    match ${!from} {/'
mutant bug "a drawn line goes inside the first node" src/add-line.sh \
    's/                parent: None,/                parent: Some(0),/'
mutant bug "line mode says Coming Soon" src/mode-notice.sh \
    '/            1 => "1 => Line Mode"\.to_string(),/d'
mutant bug "line mode's hints say how to select" src/hud-hints.sh \
    's/        _ if \${!mode} == 1 => {/        _ if false => {/'

# ---- undo, redo and select all (step 5a) ----
mutant bug "a new change keeps redo" src/history-push.sh \
    '/^    \${!history}\.redo\.clear();$/d'
mutant bug "the history keeps every change" src/history-push.sh \
    's/    if \${!history}\.undo\.len() > UNDO_LIMIT {/    if false {/'
mutant bug "the history drops the newest change" src/history-push.sh \
    's/        \${!history}\.undo\.remove(0);/        ${!history}.undo.pop();/'
mutant bug "undo doesn't keep the page for redo" src/history-step.sh \
    's/                \${v}to\.push(std::mem::replace(\&mut \${!doc}, snapshot));/                let _ = \&${v}to; ${!doc} = snapshot;/'
mutant bug "undo and redo are swapped" src/history-step.sh \
    's/        let (\${v}from, \${v}to) = if \${!back} {/        let (${v}from, ${v}to) = if !${!back} {/'
mutant bug "dirty isn't worked out after a step" src/history-step.sh \
    's/        \${!dirty} = \${!doc} != \${!saved};/        let _ = \&${!saved};/'
mutant bug "nothing to undo still sets dirty" src/history-step.sh \
    's/    if \${!stepped} {/    if true {/'
mutant bug "select all takes elements with no shape" src/select-all.sh \
    's/        \.filter(|(_, node)| SHAPE_TAGS\.contains(\&node\.tag\.as_str()))/        .filter(|_| true)/'
mutant bug "select all keeps the group" src/select-all.sh \
    '/^    \${!selection}\.group = None;$/d'
mutant bug "Ctrl-Shift-Z undoes" src/ctrl-keys.sh \
    '/                KeyCode::Z if \${!shift} => /d'
mutant bug "Ctrl-Y does nothing" src/ctrl-keys.sh \
    '/                KeyCode::Y => /d'
mutant bug "Ctrl-A does nothing" src/ctrl-keys.sh \
    '/                KeyCode::A => /d'
mutant bug "the Ctrl chords work without Ctrl" src/ctrl-keys.sh \
    's/    if \${!ctrl} {/    if true {/'
mutant bug "the hints never say Ctrl-Z" src/hud-hints.sh \
    's/let \${!hints} = if \${!undo} {/let ${!hints} = if false {/'

# ---- <g> groups ----
mutant bug "a right-click outside any group selects the clicked node" src/select-group.sh \
    's/^    if let Some(group) = \${v}target {$/    if ${v}target.is_none() { ${!selection}.ids = ${!hit}.into_iter().collect(); } if let Some(group) = ${v}target {/'
mutant bug "a right-click doesn't go up from the selected group" src/select-group.sh \
    's/let mut \${v}from: Option<usize> = if \${v}inside_group {/let mut ${v}from: Option<usize> = if false {/'
mutant bug "empty space doesn't count as inside the group" src/select-group.sh \
    's/\${v}inside_group = \${v}inside_group || \${!hit}\.is_none();/let _ = 0;/'
mutant bug "a group's nested shapes are left out" src/select-group.sh \
    's/                inside = inside || at == group;/                inside = inside || (at == group \&\& node.parent == Some(group));/'
mutant bug "the clicked node isn't the one edited" src/select-group.sh \
    's/if inside \&\& SHAPE_TAGS\.contains(\&node\.tag\.as_str()) \&\& Some(id) != \${v}base {/if inside \&\& SHAPE_TAGS.contains(\&node.tag.as_str()) {/'
mutant bug "a group selection takes non-shapes" src/select-group.sh \
    's/if inside \&\& SHAPE_TAGS\.contains(\&node\.tag\.as_str()) \&\& Some(id) != \${v}base {/if inside \&\& Some(id) != ${v}base {/'
mutant bug "the group isn't remembered" src/select-group.sh \
    's/\${!selection}\.group = Some(group);/let _ = group;/'
mutant bug "a left click keeps the group" src/select.sh \
    's/\${!selection}\.group = None;/let _ = 0;/'
mutant bug "groups pass down no styles" src/draw-doc.sh \
    's/if INHERITED_ATTRS\.contains(\&name\.as_str()) {/if false {/'
mutant bug "a group's styles beat the node's own" src/draw-doc.sh \
    's/        for (name, value) in node\.attrs\.iter() {$/        for (name, value) in node.attrs.iter().filter(|_| false) {/'
mutant bug "a group's stroke beats a text's own fill for the selection color" src/draw-doc.sh \
    's/\&\& let Some(attr) = own_color_attr\.or(inherited_color_attr)/\&\& let Some(attr) = inherited_color_attr.or(own_color_attr)/'
mutant bug "transforms go unnoticed" src/transform-note.sh \
    's/let \${!note}: Option<String> = if \${v}transformed > 0 {/let ${!note}: Option<String> = if false {/'

# copy <from> <to>: the repo's scripts and crate files the tests need
copy_repo() {
    mkdir -p "$2/src" "$2/tests"
    cp "$1"/*.sh "$1/Cargo.toml" "$1/Cargo.lock" "$2/"
    # its own package name, so its builds never overwrite the real crate's in
    # the shared target directory (same name, same version, same hashes)
    sed -i 's/^name = "gram"$/name = "gram-mutant"/' "$2/Cargo.toml"
    rm -f "$2/src/"*.sh
    cp "$1/src/"*.sh "$2/src/"
    cp "$1/tests/"*.test.sh "$2/tests/"
    # cargo needs the bin target to exist; the tests don't compile it
    [[ -f "$2/src/main.rs" ]] || echo 'fn main() {}' > "$2/src/main.rs"
}

# run_tests <log>: generate every test into the mutant crate (rewriting a file
# only if it changed, so cargo skips the rest) and run them all
run_tests() {
    local f name out
    for f in "${RN_CRATE}/tests/"*.test.sh; do
        name=$(basename "${f}" .test.sh)
        out="${RN_CRATE}/tests/${name//-/_}.rs"
        "${f}" > "${out}.new" 2>> "$1" || return 3
        if cmp -s "${out}.new" "${out}"; then rm "${out}.new"; else mv "${out}.new" "${out}"; fi
    done
    (cd "${RN_CRATE}" && cargo test --test '*' --no-run -q) >> "$1" 2>&1 || return 2
    (cd "${RN_CRATE}" && cargo test --test '*' --no-fail-fast -q) >> "$1" 2>&1 || return 1
    return 0
}

# ---- which mutants run ----
RN_SELECTED=("${!MT_NAMES[@]}")
if [[ -n "${RN_CHANGED}" ]]; then
    git rev-parse --verify -q "${RN_CHANGED}" > /dev/null || {
        echo "--changed: no such ref: ${RN_CHANGED}" >&2
        exit 2
    }
    # files changed against the ref (committed, staged or not), and new ones
    rn_files=$( (git diff --name-only "${RN_CHANGED}" -- && git ls-files --others --exclude-standard) | sort -u)
    # the files a mutant can touch: changed snippets, and the snippets each
    # changed test file inlines
    rn_touched=$(echo "${rn_files}" | grep -E '^src/.*\.sh$')
    for test_file in $(echo "${rn_files}" | grep -E '^tests/.*\.test\.sh$'); do
        [[ -f "${test_file}" ]] || continue
        rn_touched+=$'\n'$(grep -o '` \./[a-z0-9-]*\.sh' "${test_file}" | sed 's/^` \.\//src\//' | sort -u)
    done
    # mutants added or edited in this file, by name, and the snippets added to
    # the "not written" list
    rn_new_names=""
    if echo "${rn_files}" | grep -qx 'tests/mutate.sh'; then
        rn_added=$(git diff "${RN_CHANGED}" -- tests/mutate.sh | grep '^+' | grep -v '^+++')
        rn_new_names=$(echo "${rn_added}" | sed -n 's/^+mutant [a-z]* "\([^"]*\)".*/\1/p')
        # the "not written" list's lines: only snippet names, maybe with the
        # loop's "for snippet in" or "; do", or a trailing backslash
        for snippet in $(echo "${rn_added}" | grep -E '^\+( *for snippet in)? *[a-z0-9 -]+( \\|; do)?$' |
            sed -e 's/^+//' -e 's/for snippet in//' -e 's/; do$//' -e 's/\\$//'); do
            [[ -f "src/${snippet}.sh" ]] && rn_new_names+=$'\n'"${snippet}.sh not written"
        done
    fi
    RN_SELECTED=()
    for i in "${!MT_NAMES[@]}"; do
        hit=0
        for file in ${MT_FILES[$i]}; do
            echo "${rn_touched}" | grep -qx "${file}" && hit=1
        done
        echo "${rn_new_names}" | grep -qxF -- "${MT_NAMES[$i]}" && hit=1
        [[ ${hit} -eq 1 ]] && RN_SELECTED+=("${i}")
    done
fi
if [[ -n "${RN_NAME}" ]]; then
    rn_kept=()
    for i in "${RN_SELECTED[@]}"; do
        echo "${MT_NAMES[$i]}" | grep -qiE -- "${RN_NAME}" && rn_kept+=("${i}")
    done
    RN_SELECTED=("${rn_kept[@]}")
fi
if [[ ${RN_LIST} -eq 1 ]]; then
    for i in "${RN_SELECTED[@]}"; do
        printf '%-8s %s  (%s)\n' "${MT_KINDS[$i]}" "${MT_NAMES[$i]}" "${MT_FILES[$i]}"
    done
    echo "${#RN_SELECTED[@]} of ${#MT_NAMES[@]} mutants"
    exit 0
fi
RN_FILTERED=0
[[ -n "${RN_CHANGED}${RN_NAME}" ]] && RN_FILTERED=1
if [[ ${RN_FILTERED} -eq 1 ]]; then
    echo "running ${#RN_SELECTED[@]} of ${#MT_NAMES[@]} mutants${RN_CHANGED:+ (changed against ${RN_CHANGED})}${RN_NAME:+ (name matching ${RN_NAME})}"
    if [[ ${#RN_SELECTED[@]} -eq 0 ]]; then
        echo "no mutants to run"
        exit 0
    fi
fi

# the real code must pass first, or every mutant would look killed
copy_repo "${RN_DIR}" "${RN_CRATE}"
run_tests "${RN_LOGS}/baseline.log"
if [[ $? -ne 0 ]]; then
    cat "${RN_LOGS}/baseline.log" >&2
    echo "baseline: the unmutated app fails its tests, fix that first" >&2
    exit 1
fi
echo "baseline: passes"

RN_BAD=0
RN_KILLERS=""
for i in "${RN_SELECTED[@]}"; do
    kind="${MT_KINDS[$i]}"
    name="${MT_NAMES[$i]}"
    log="${RN_LOGS}/mutant-${i}.log"
    copy_repo "${RN_DIR}" "${RN_CRATE}"

    changed=0
    for file in ${MT_FILES[$i]}; do
        sed -i "${MT_SEDS[$i]}" "${RN_CRATE}/${file}"
        cmp -s "${RN_DIR}/${file}" "${RN_CRATE}/${file}" || changed=1
    done
    # a sed that no longer matches would test the real code
    if [[ ${changed} -eq 0 ]]; then
        echo "STALE     ${name}: its sed no longer changes ${MT_FILES[$i]}"
        RN_BAD=$((RN_BAD + 1))
        continue
    fi

    run_tests "${log}"
    ec=$?
    # cargo prints "---- <test> stdout ----" before each failing test's output
    killers=$(sed -n 's/^---- \([a-z0-9_]*\) stdout ----$/\1/p' "${log}" | sort -u | paste -sd ',' | sed 's/,/, /g')
    RN_KILLERS+=$'\n'$(sed -n 's/^---- \([a-z0-9_]*\) stdout ----$/\1/p' "${log}")
    if [[ ${ec} -eq 1 ]]; then
        echo "killed    ${name}"
        echo "              by: ${killers}"
    elif [[ ${ec} -eq 2 && ${kind} == missing ]]; then
        echo "killed    ${name}"
        echo "              by: compile error (tests can't build without it)"
    elif [[ ${ec} -eq 0 ]]; then
        echo "SURVIVED  ${name}: no test caught it"
        RN_BAD=$((RN_BAD + 1))
    else
        echo "BROKEN    ${name}: the mutant doesn't build or generate"
        grep -E '^error' "${log}" | head -5 | sed 's/^/              /'
        RN_BAD=$((RN_BAD + 1))
    fi
done

# leave the crate as the real code, for the next run's baseline
copy_repo "${RN_DIR}" "${RN_CRATE}"

echo "${#RN_SELECTED[@]} mutants, $((${#RN_SELECTED[@]} - RN_BAD)) killed, ${RN_BAD} not"

# ---- pairing: every test kills at least one mutant (full runs only) ----
# A test no mutant can fail isn't known to catch anything. Kills by a compile
# error name no test, so they don't count here.
if [[ ${RN_FILTERED} -eq 0 ]]; then
    rn_unpaired=0
    for test_name in $(grep -h -A1 '^#\[test\]' tests/*.test.sh | sed -n 's/^fn \([a-z0-9_]*\)().*/\1/p' | sort -u); do
        if ! echo "${RN_KILLERS}" | grep -qx "${test_name}"; then
            echo "UNPAIRED  ${test_name}: no mutant makes it fail"
            rn_unpaired=$((rn_unpaired + 1))
        fi
    done
    echo "pairing: ${rn_unpaired} unpaired test(s)"
    RN_BAD=$((RN_BAD + rn_unpaired))
fi
[[ ${RN_BAD} -eq 0 ]]
