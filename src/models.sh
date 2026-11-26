#!/bin/bash

# The app's constants and types, printed by main.sh and by the tests, so both
# compile the snippets against the same definitions. Prints Rust items only
# (no imports); it uses macroquad's Vec2, Rect and Color, and rstar's traits.

cat << 'EOF'

// the document is a 750x750 page (the old web app's svg frame) at world (0, 0)
const PAGE_W: f32 = 750.0;
const PAGE_H: f32 = 750.0;

// svg text with no font-size: 16px, in Courier New (the old web app's body
// font, which inline svg text inherited). The bundled Liberation Mono has
// the same metrics.
const TEXT_SIZE: f32 = 16.0;
// below this many screen pixels, text is drawn as a bar instead of glyphs
const TEXT_LOD_PX: f32 = 4.0;
// the biggest glyph size rasterized; zooming further scales the glyphs
const TEXT_MAX_PX: f32 = 512.0;

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
// rules (setMouseRects).
#[derive(Clone, Debug, PartialEq)]
struct Node {
    tag: String,
    attrs: Vec<(String, String)>,
    text: String,
    bounds: Rect,
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
