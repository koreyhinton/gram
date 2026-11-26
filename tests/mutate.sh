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

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo "Error, script must not be sourced. Run it without sourcing it" >&2
    return 1
fi

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
    node-apply map banner mode-notice hud-hints key-presses; do
    mutant missing "${snippet}.sh not written" "src/${snippet}.sh" '/^cat << EOF$/,/^EOF$/d'
done

# ---- loading ----
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
    's/let mut color_attr: Option<\&str> = None;/let mut color_attr: Option<\&str> = Some("stroke");/'
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
    's/        let text = if \${!mode} == 0 {/        let text = if true {/'

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
for i in "${!MT_NAMES[@]}"; do
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

echo "${#MT_NAMES[@]} mutants, $((${#MT_NAMES[@]} - RN_BAD)) killed, ${RN_BAD} not"
[[ ${RN_BAD} -eq 0 ]]
