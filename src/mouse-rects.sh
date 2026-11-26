#!/bin/bash

# mouse-rects: each node's click box (the old web app's setMouseRects).
#
#   input/output:  Nodes  Vec<Node>; each node's bounds is set
#
# Run it after svg-load, and again after anything changes a node's
# attributes (an edit, a reload). The rules, in world units:
#   rect     x, y, width, height, padded by stroke-width all round
#   circle   cx, cy, r, padded by stroke-width
#   line     x1, y1, x2, y2, padded by 1
#   polyline the points' extent, not padded
#   text     StartEndFrame.FromText: x and y truncated (parseInt), from x - 3
#            to x + the per-character widths, from y - 17 to y + 4
# Numbers are read as JS parseFloat read them (js_parse_float).

v=$1
# maps
. ${NSMAP}/bind ${v} Nodes

cat << EOF

    // each node's click box, by the old web app's rules (setMouseRects and
    // StartEndFrame.FromText). A missing or unreadable number counts as 0.
    // Elements gram doesn't draw keep an empty box.
    for ${v}node in ${!nodes}.iter_mut() {
        let (mut x, mut y, mut w, mut h, mut stroke_w) = (0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let (mut cx, mut cy, mut r) = (0.0f32, 0.0f32, 0.0f32);
        let (mut x1, mut y1, mut x2, mut y2) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let mut points: Vec<f32> = vec![];
        for (name, value) in ${v}node.attrs.iter() {
            // each number as the old web app read it (js_parse_float);
            // points holds several, split on commas and spaces
            let nums: Vec<f32> = if name == "points" {
                value
                    .split(|c: char| c == ',' || c.is_whitespace())
                    .filter(|part| !part.is_empty())
                    .map(|part| js_parse_float(part) as f32)
                    .collect()
            } else {
                vec![js_parse_float(value) as f32]
            };
            let num = nums.first().copied().unwrap_or(0.0);
            match name.as_str() {
                "x" => x = num,
                "y" => y = num,
                "width" => w = num,
                "height" => h = num,
                "stroke-width" => stroke_w = num,
                "cx" => cx = num,
                "cy" => cy = num,
                "r" => r = num,
                "x1" => x1 = num,
                "y1" => y1 = num,
                "x2" => x2 = num,
                "y2" => y2 = num,
                "points" => points = nums,
                _ => {}
            }
        }
        let (mut min_x, mut min_y, mut max_x, mut max_y) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        match ${v}node.tag.as_str() {
            "circle" => {
                min_x = cx - r - stroke_w;
                max_x = cx + r + stroke_w;
                min_y = cy - r - stroke_w;
                max_y = cy + r + stroke_w;
            }
            "polyline" => {
                // even entries are x, odd are y; no stroke padding
                let xs: Vec<f32> = points.iter().step_by(2).copied().collect();
                let ys: Vec<f32> = points.iter().skip(1).step_by(2).copied().collect();
                if !xs.is_empty() && !ys.is_empty() {
                    min_x = xs.iter().copied().fold(f32::MAX, f32::min);
                    max_x = xs.iter().copied().fold(f32::MIN, f32::max);
                    min_y = ys.iter().copied().fold(f32::MAX, f32::min);
                    max_y = ys.iter().copied().fold(f32::MIN, f32::max);
                }
            }
            "rect" => {
                min_x = x - stroke_w;
                max_x = x + w + stroke_w;
                min_y = y - stroke_w;
                max_y = y + h + stroke_w;
            }
            "line" => {
                min_x = x1.min(x2) - 1.0;
                max_x = x1.max(x2) + 1.0;
                min_y = y1.min(y2) - 1.0;
                max_y = y1.max(y2) + 1.0;
            }
            "text" => {
                // the old per-character widths (in px at 16px), over the raw
                // text as the browser's innerHTML gave it; x and y were read
                // with parseInt, so they're truncated
                let mut width = 0.0f32;
                for ch in ${v}node.text.chars() {
                    width += match ch {
                        'H' | 'W' => 12.0,
                        '?' | 'A'..='B' | 'M'..='O' | 'R' | 'T' | 'V' => 11.0,
                        'C'..='E' | 'G' | 'I' | 'P'..='Q' | 'U' | 'Y'..='Z' => 10.0,
                        'F' | 'J'..='L' | 'S' | 'X' | 'w' => 9.0,
                        'a'..='h' | 'k' | 'm'..='s' | 'u'..='v' | 'x'..='z' => 8.0,
                        'i'..='j' | 'l' | 't' => 7.0,
                        _ => 6.5,
                    };
                }
                min_x = x.trunc() - 3.0;
                min_y = y.trunc() - 17.0;
                max_x = x.trunc() + width;
                max_y = y.trunc() + 4.0;
            }
            _ => {}
        }
        ${v}node.bounds = Rect::new(min_x, min_y, max_x - min_x, max_y - min_y);
    }

EOF
