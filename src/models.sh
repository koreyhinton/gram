#!/bin/bash

# The app's constants and types, printed by main.sh and by the tests, so both
# compile the snippets against the same definitions. Prints Rust items only
# (no imports); it uses macroquad's Vec2, Rect and Color, and rstar's traits.

cat << 'EOF'

// the document is a 750x750 page (the old web app's svg frame) at world (0, 0)
const PAGE_W: f32 = 750.0;
const PAGE_H: f32 = 750.0;

// svg text with no font-size: 16px, in the browser's default serif font
// (Times New Roman), which the diagrams' boxes were sized for. The bundled
// Liberation Serif has the same metrics.
const TEXT_SIZE: f32 = 16.0;
// below this many screen pixels, text is drawn as a bar instead of glyphs
const TEXT_LOD_PX: f32 = 4.0;
// the biggest glyph size rasterized; zooming further scales the glyphs
const TEXT_MAX_PX: f32 = 512.0;
// glyph sizes rasterized per doubling: text is rasterized at the next of
// these sizes up from its size on screen, as macroquad caches every glyph at
// every size it's drawn at and never frees them
const TEXT_PX_STEPS: f32 = 4.0;

// the infinite canvas
const ZOOM_MIN: f32 = 0.05;
const ZOOM_MAX: f32 = 25.0;
const ZOOM_STEP: f32 = 1.12; // per wheel notch
const FIT_MARGIN: f32 = 40.0; // screen pixels around the page after a fit

// the adaptive grid: each level is GRID_SUBDIVS times the one below it, and
// the minor level fades out as its lines get closer than GRID_MIN_PX
const GRID_SUBDIVS: f32 = 5.0;
const GRID_MIN_PX: f32 = 35.0;

// light theme: the page is white, as the diagrams were drawn for a browser
const CANVAS_BG: Color = Color::new(0.90, 0.91, 0.93, 1.0);
const GRID_MINOR: Color = Color::new(0.78, 0.80, 0.84, 0.55);
const GRID_MAJOR: Color = Color::new(0.70, 0.73, 0.78, 0.90);
const GRID_AXIS: Color = Color::new(0.50, 0.55, 0.65, 0.95);
const PAGE_BG: Color = Color::new(1.0, 1.0, 1.0, 1.0);
const PAGE_BORDER: Color = Color::new(0.60, 0.63, 0.68, 1.0);
const HUD_TEXT: Color = Color::new(0.25, 0.27, 0.30, 1.0);
const ERROR_TEXT: Color = Color::new(0.70, 0.12, 0.12, 1.0);

// the folder tree, a panel down the left of the window (screen pixels)
const TREE_W: f32 = 260.0;
const TREE_ROW_H: f32 = 22.0;
const TREE_INDENT: f32 = 14.0;
const TREE_PAD: f32 = 8.0;
const TREE_TEXT_PX: u16 = 15;
const TREE_SCROLL_ROWS: f32 = 3.0; // rows per wheel notch
// the open page's row ends in an "edit" button, which opens the page's file
// in the editor
const TREE_BUTTON_W: f32 = 40.0;
const TREE_BUTTON_LABEL: &str = "edit";
const TREE_BG: Color = Color::new(0.97, 0.97, 0.98, 1.0);
const TREE_BORDER: Color = Color::new(0.75, 0.77, 0.81, 1.0);
const TREE_TEXT: Color = Color::new(0.15, 0.16, 0.18, 1.0);
const TREE_SELECTED: Color = Color::new(0.80, 0.86, 0.96, 1.0);
const BANNER_BG: Color = Color::new(0.16, 0.18, 0.22, 0.92);
const BANNER_TEXT: Color = Color::new(1.0, 1.0, 1.0, 1.0);
// the mode notice (the old setNumMode's notifyMsg): green, top right
const NOTICE_BG: Color = Color::new(0.0, 1.0, 0.0, 0.6);
const NOTICE_TEXT: Color = Color::new(1.0, 1.0, 1.0, 1.0);
const NOTICE_PX: u16 = 64;
const MODE_NOTICE_SECS: f64 = 3.0;
// how many changes a page can undo; older ones are dropped
const UNDO_LIMIT: usize = 100;

// selection is shown by recoloring a node's stroke: the node being edited
// (the last one selected) in EDIT_COLOR (#CAFFB5), the others in SEL_COLOR
// (#C0D6FC). Only the drawing is recolored; the node keeps its color.
const SEL_COLOR: Color = Color::new(192.0 / 255.0, 214.0 / 255.0, 252.0 / 255.0, 1.0);
const EDIT_COLOR: Color = Color::new(202.0 / 255.0, 255.0 / 255.0, 181.0 / 255.0, 1.0);

// the elements gram draws and can click; anything else (g, defs, title, ...)
// has no click box and stays out of the R-tree
const SHAPE_TAGS: [&str; 5] = ["line", "polyline", "rect", "circle", "text"];

// the attributes a <g> passes down to the elements inside it, unless they
// set their own (svg's inherited presentation attributes that gram draws)
const INHERITED_ATTRS: [&str; 6] = ["fill", "stroke", "stroke-width", "stroke-dasharray", "font-size", "text-decoration"];

// drawing (devbox@8faf51d): an arrow's end within this of its start on an
// axis takes the start's value there, so near-straight arrows come out
// straight (world units)
const STRAIGHTEN: f32 = 11.0;
// an arrowhead's arms: at 45 degrees from the shaft, ARROW_ARM long (the old
// app's straight-arrow head, 10 back and 10 across)
const ARROW_ARM: f32 = 14.142136;
// a rect whose click box is wider and higher than this is a swimlane: it
// comes after every other shape when a click picks one (until step 26)
const SWIMLANE_W: f32 = 200.0;
const SWIMLANE_H: f32 = 300.0;
// Esc twice drops an open edit: the second Esc must come within this many
// seconds of the first
const DROP_CONFIRM_SECS: f64 = 3.0;
// after an edit is dropped, how long the banner says so
const DROPPED_NOTE_SECS: f64 = 5.0;
// the one-click nodes (devbox@01c476e): a decision node's diamond reaches
// this far from the click each way (14 by 14; CT/58's standard size is still
// to be decided), an initial node's circle, and a final node's dot and ring
const DECISION_HALF: f32 = 7.0;
const INITIAL_R: f32 = 10.0;
const FINAL_DOT_R: f32 = 6.0;
const FINAL_RING_R: f32 = 10.0;
// a new text's "?" sits this far from the click, so it lands under the cursor
const TEXT_OFFSET: Vec2 = vec2(-7.0, 3.0);

// an editor that exits within this many seconds of starting handed the file
// to another program (xdg-open, emacsclient -n): gram keeps watching the file
const HANDOFF_SECS: f64 = 2.0;

// the two arm ends of an arrowhead at tip, for a shaft coming from from: each
// ARROW_ARM back along the shaft, turned 45 degrees to either side, rounded
// to whole numbers. The first arm is the one a downward arrow has on its left.
fn arrow_head(from: Vec2, tip: Vec2) -> (Vec2, Vec2) {
    let shaft = tip - from;
    if shaft.length() == 0.0 {
        return (tip, tip);
    }
    let back = -shaft.normalize() * ARROW_ARM;
    let turn = |degrees: f32| {
        let (sin, cos) = degrees.to_radians().sin_cos();
        // (+ 0.0 turns a -0 into 0)
        (tip + vec2(back.x * cos - back.y * sin, back.x * sin + back.y * cos)).round() + Vec2::ZERO
    };
    (turn(-45.0), turn(45.0))
}

// a number as the old web app read it (JS parseFloat): the longest number at
// the start, after any whitespace, so "10px" is 10 and "1.5e1" is 15. A value
// with no number at the start is 0 (JS gave NaN, or -999 for a missing
// attribute; see PLAN.md's decisions log).
fn js_parse_float(text: &str) -> f64 {
    let text = text.trim_start();
    let bytes = text.as_bytes();
    let mut end = 0usize;
    let mut number_end = 0usize;
    let mut has_digits = false;
    if end < bytes.len() && (bytes[end] == b'+' || bytes[end] == b'-') {
        end += 1;
    }
    while end < bytes.len() && bytes[end].is_ascii_digit() {
        end += 1;
        has_digits = true;
        number_end = end;
    }
    if end < bytes.len() && bytes[end] == b'.' {
        end += 1;
        while end < bytes.len() && bytes[end].is_ascii_digit() {
            end += 1;
            has_digits = true;
            number_end = end;
        }
    }
    // an exponent only counts with digits after it ("1e" is 1)
    if has_digits && end < bytes.len() && (bytes[end] == b'e' || bytes[end] == b'E') {
        let mut exp_end = end + 1;
        if exp_end < bytes.len() && (bytes[exp_end] == b'+' || bytes[exp_end] == b'-') {
            exp_end += 1;
        }
        while exp_end < bytes.len() && bytes[exp_end].is_ascii_digit() {
            exp_end += 1;
            number_end = exp_end;
        }
    }
    text[..number_end].parse::<f64>().unwrap_or(0.0)
}

// svg color keywords the diagrams use, plus the common ones
const NAMED_COLORS: [(&str, [u8; 3]); 28] = [
    ("black", [0, 0, 0]),
    ("white", [255, 255, 255]),
    ("gray", [128, 128, 128]),
    ("grey", [128, 128, 128]),
    ("silver", [192, 192, 192]),
    ("lightgray", [211, 211, 211]),
    ("lightgrey", [211, 211, 211]),
    ("darkgray", [169, 169, 169]),
    ("darkgrey", [169, 169, 169]),
    ("red", [255, 0, 0]),
    ("green", [0, 128, 0]),
    ("lightgreen", [144, 238, 144]),
    ("darkgreen", [0, 100, 0]),
    ("lime", [0, 255, 0]),
    ("blue", [0, 0, 255]),
    ("lightblue", [173, 216, 230]),
    ("navy", [0, 0, 128]),
    ("yellow", [255, 255, 0]),
    ("gold", [255, 215, 0]),
    ("orange", [255, 165, 0]),
    ("brown", [165, 42, 42]),
    ("pink", [255, 192, 203]),
    ("purple", [128, 0, 128]),
    ("violet", [238, 130, 238]),
    ("cyan", [0, 255, 255]),
    ("magenta", [255, 0, 255]),
    ("tan", [210, 180, 140]),
    ("maroon", [128, 0, 0]),
];

// One svg element. Attributes keep their file order and their raw (still
// escaped) values, and text keeps its raw contents, so a save can write the
// element back as it was read. bounds is the click box, by the old web app's
// rules (setMouseRects). parent is the enclosing element's index in
// Doc.nodes (a <g>), or None for an element right under the root <svg>.
#[derive(Clone, Debug, PartialEq)]
struct Node {
    tag: String,
    attrs: Vec<(String, String)>,
    text: String,
    bounds: Rect,
    parent: Option<usize>,
}

// the selected nodes, by index in Doc.nodes, in the order they were picked.
// The last one is the node being edited (shown in EDIT_COLOR). group is the
// <g> whose shapes a right-click selected (select-group.sh); None when nodes
// were picked one by one.
#[derive(Clone, Debug, Default, PartialEq)]
struct Selection {
    ids: Vec<usize>,
    group: Option<usize>,
}

// a page's undo history: snapshots of its Doc, the newest last. A change
// pushes the page as it was onto undo and clears redo (history-push.sh);
// undo and redo move the page between the two (history-step.sh). nudge is
// the selection an arrow-key run is moving (nudge.sh): its presses share one
// snapshot, and any other change, an undo or a redo ends the run.
#[derive(Clone, Debug, Default, PartialEq)]
struct History {
    undo: Vec<Doc>,
    redo: Vec<Doc>,
    nudge: Option<Vec<usize>>,
}

// what a Ctrl key chord asks for (ctrl-keys.sh)
#[derive(Clone, Copy, Debug, PartialEq)]
enum CtrlAction {
    Undo,
    Redo,
    SelectAll,
}

// what a node edit's file says this frame (node-edit-check.sh)
#[derive(Clone, Debug, PartialEq)]
enum NodeEditOutcome {
    // nothing to do yet
    Wait,
    // the editor finished without changing it
    Unchanged,
    // the edited XML, to apply
    Apply(String),
    // the file couldn't be read
    Failed(String),
}

// what an open editor is editing
#[derive(Clone, Copy, Debug, PartialEq)]
enum EditKind {
    // the selected node, as XML in a temp file
    Node,
    // the page's own file
    File,
}

// an editor gram started, checked each frame
struct EditJob {
    kind: EditKind,
    // the page being edited (index in Workspace.pages)
    page: usize,
    // the file in the editor: the temp node file, or the page's file
    path: std::path::PathBuf,
    // the editor while it runs
    child: Option<std::process::Child>,
    // a node edit: the XML handed to the editor, and the node as it was
    written: String,
    before: Option<Node>,
    // a file edit: the file's modified time and length when last seen
    stamp: Option<(std::time::SystemTime, u64)>,
    // why the editor or its result was refused, shown in the banner
    error: Option<String>,
    // when the editor started (get_time): a file edit whose editor returns
    // at once (xdg-open, emacsclient -n) handed the file off, so gram keeps
    // watching it
    started: f64,
    // when Esc was first pressed while the editor was open (edit-escape.sh):
    // a second Esc soon after drops the edit
    warned_at: Option<f64>,
    // a node edit whose editor handed the file off and returned at once:
    // gram watches node.xml for a save instead (node-edit-check.sh)
    watching: bool,
}

// one svg file: the root <svg> element's attributes, then its elements in
// document order (later ones paint over earlier ones)
#[derive(Clone, Debug, PartialEq, Default)]
struct Doc {
    root_attrs: Vec<(String, String)>,
    nodes: Vec<Node>,
}

// the view onto the infinite canvas: offset is the world point at the
// screen's top-left corner, zoom is screen pixels per world unit
#[derive(Clone, Copy, Debug, PartialEq)]
struct Canvas {
    offset: Vec2,
    zoom: f32,
    panning: bool,
    last_mouse: Vec2,
}

// one row of the folder tree: a folder, or an .svg file (a page). depth is
// how far it sits below the root (0 for the root's own entries).
#[derive(Clone, Debug, PartialEq)]
struct TreeEntry {
    path: std::path::PathBuf,
    name: String,
    depth: usize,
    is_dir: bool,
}

// an opened .svg file, kept while gram runs so switching back finds it as
// it was left (view, and later selection and unsaved edits)
struct Page {
    path: std::path::PathBuf,
    doc: Doc,
    index: rstar::RTree<SpatialEntry>,
    canvas: Canvas,
    // why the file couldn't be read or parsed; the page then draws nothing
    error: Option<String>,
    // changed since it was loaded or saved (shown as * in the tree)
    dirty: bool,
    // fitted to the window once it had its real size
    fitted: bool,
    selection: Selection,
    // line, arrow or rect mode's first click (world units), waiting for the
    // second
    draw_from: Option<Vec2>,
    // what can be undone and redone (history-push.sh, history-step.sh)
    history: History,
    // the page as last loaded or saved: undoing back to it clears dirty
    saved: Doc,
}

// the folder gram opened: its tree, which folders are folded, how far the
// tree is scrolled, and the pages opened so far
struct Workspace {
    root: std::path::PathBuf,
    entries: Vec<TreeEntry>,
    collapsed: Vec<std::path::PathBuf>,
    scroll: f32,
    pages: Vec<Page>,
    open: Option<usize>,
    // the draw mode, keys 0-9 (0 is select, 1 is line; the others come with
    // later steps)
    mode: u8,
    // the editor gram started, if one is open
    edit: Option<EditJob>,
}

// a raw key event, as macroquad replays it to an input subscriber
#[derive(Clone, Copy, Debug, PartialEq)]
enum KeyEvent {
    Down { key: KeyCode, repeat: bool },
    Up { key: KeyCode },
}

// collects a frame's raw key events (macroquad::input::utils
// repeat_all_miniquad_input), for keys whose release can go missing (see
// key-presses.sh)
#[derive(Default)]
struct KeyEvents {
    events: Vec<KeyEvent>,
}

impl macroquad::miniquad::EventHandler for KeyEvents {
    fn update(&mut self) {}

    fn draw(&mut self) {}

    fn key_down_event(&mut self, key: KeyCode, _mods: macroquad::miniquad::KeyMods, repeat: bool) {
        self.events.push(KeyEvent::Down { key, repeat });
    }

    fn key_up_event(&mut self, key: KeyCode, _mods: macroquad::miniquad::KeyMods) {
        self.events.push(KeyEvent::Up { key });
    }
}

// a node's bounds in the R-tree; id is its index in Doc.nodes
#[derive(Clone, Copy, Debug, PartialEq)]
struct SpatialEntry {
    id: usize,
    min: [f32; 2],
    max: [f32; 2],
}

impl rstar::RTreeObject for SpatialEntry {
    type Envelope = rstar::AABB<[f32; 2]>;

    fn envelope(&self) -> Self::Envelope {
        rstar::AABB::from_corners(self.min, self.max)
    }
}

impl rstar::PointDistance for SpatialEntry {
    fn distance_2(&self, point: &[f32; 2]) -> f32 {
        rstar::Envelope::distance_2(&rstar::RTreeObject::envelope(self), point)
    }

    fn contains_point(&self, point: &[f32; 2]) -> bool {
        rstar::Envelope::contains_point(&rstar::RTreeObject::envelope(self), point)
    }
}

EOF
