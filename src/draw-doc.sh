#!/bin/bash

# draw-doc: draw a Doc's elements that are in view, in world space (call it
# with the world camera set), in document order so later elements paint over
# earlier ones.
#
#   input:  Doc     Doc
#   input:  Index   rstar::RTree<SpatialEntry> (from spatial-index)
#   input:  Canvas  Canvas
#   input:  Font    Option<&Font>, None for macroquad's default font
#   input:  Selection  Selection; a selected node's stroke is drawn in
#                   EDIT_COLOR (the last selected) or SEL_COLOR, when it has a
#                   stroke attribute (the old setcolor changed only that). A
#                   text's color is its fill, or its stroke if that comes
#                   first, as setcolor took the first of the two.
#
# Supports line, polyline, rect (rx/ry), circle and text: fill and stroke
# (svg defaults: fill black, stroke none), stroke-width, stroke-dasharray,
# font-size (px, smaller, larger; or in style) and text-decoration
# (underline, line-through). An element inside a <g> takes those styles
# (INHERITED_ATTRS) from it unless it sets its own. transform isn't
# supported. Other elements are skipped.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Index Canvas Font Selection

cat << EOF

    // the nodes whose bounds touch the view, padded a little because a
    // polyline's bounds leave out its stroke
    let ${v}pad = 10.0 + 4.0 / ${!canvas}.zoom;
    let ${v}view_min = [${!canvas}.offset.x - ${v}pad, ${!canvas}.offset.y - ${v}pad];
    let ${v}view_max = [
        ${!canvas}.offset.x + screen_width() / ${!canvas}.zoom + ${v}pad,
        ${!canvas}.offset.y + screen_height() / ${!canvas}.zoom + ${v}pad,
    ];
    let mut ${v}ids: Vec<usize> = ${!index}
        .locate_in_envelope_intersecting(rstar::AABB::from_corners(${v}view_min, ${v}view_max))
        .map(|entry| entry.id)
        .collect();
    // document order: the tree returns them in its own order
    ${v}ids.sort_unstable();

    for ${v}id in ${v}ids {
        let node = &${!doc}.nodes[${v}id];

        // the element's attributes; a missing or unreadable one keeps its
        // svg default
        let mut fill: Option<Color> = Some(BLACK);
        let mut stroke: Option<Color> = None;
        let mut stroke_w = 1.0f32;
        let mut dashes: Vec<f32> = vec![];
        let mut size_spec: Option<String> = None;
        let mut decoration = String::new();
        let (mut x, mut y, mut w, mut h) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let (mut rx, mut ry): (Option<f32>, Option<f32>) = (None, None);
        let (mut cx, mut cy, mut r) = (0.0f32, 0.0f32, 0.0f32);
        let (mut x1, mut y1, mut x2, mut y2) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let mut points: Vec<f32> = vec![];
        // the attribute that shows selection: stroke, or a text's fill,
        // whichever of the two comes first among the node's own attributes
        // (as setcolor did); only a node with neither uses one from its <g>
        let mut own_color_attr: Option<&str> = None;
        let mut inherited_color_attr: Option<&str> = None;
        // the styles the enclosing <g>s pass down (outermost first), then
        // the node's own, which win
        let mut ancestors: Vec<usize> = vec![];
        let mut up = node.parent;
        while let Some(at) = up {
            ancestors.push(at);
            up = ${!doc}.nodes[at].parent;
        }
        let mut styled: Vec<(&String, &String)> = vec![];
        for at in ancestors.iter().rev() {
            for (name, value) in ${!doc}.nodes[*at].attrs.iter() {
                if INHERITED_ATTRS.contains(&name.as_str()) {
                    styled.push((name, value));
                }
            }
        }
        let inherited_count = styled.len();
        for (name, value) in node.attrs.iter() {
            styled.push((name, value));
        }
        for (place, (name, value)) in styled.iter().copied().enumerate() {
            let num = value.trim().trim_end_matches("px").parse::<f32>().ok();
            let colors_it = name == "stroke" || (name == "fill" && node.tag == "text");
            let own = place >= inherited_count;
            if colors_it && own && own_color_attr.is_none() {
                own_color_attr = Some(name.as_str());
            }
            if colors_it && !own && inherited_color_attr.is_none() {
                inherited_color_attr = Some(name.as_str());
            }
            match name.as_str() {
                "fill" | "stroke" => {
                    // a color: none, transparent, #rgb, #rrggbb or a keyword
                    let lower = value.trim().to_ascii_lowercase();
                    let hex = lower.strip_prefix('#').unwrap_or("");
                    let mut paint: Option<Option<Color>> = None;
                    if lower == "none" || lower == "transparent" {
                        paint = Some(None);
                    } else if hex.len() == 6 && u32::from_str_radix(hex, 16).is_ok() {
                        let rgb = u32::from_str_radix(hex, 16).unwrap_or(0);
                        paint = Some(Some(Color::from_rgba(
                            (rgb >> 16) as u8,
                            (rgb >> 8) as u8,
                            rgb as u8,
                            255,
                        )));
                    } else if hex.len() == 3 && u32::from_str_radix(hex, 16).is_ok() {
                        let rgb = u32::from_str_radix(hex, 16).unwrap_or(0);
                        paint = Some(Some(Color::from_rgba(
                            ((rgb >> 8) & 0xf) as u8 * 17,
                            ((rgb >> 4) & 0xf) as u8 * 17,
                            (rgb & 0xf) as u8 * 17,
                            255,
                        )));
                    } else if let Some((_, rgb)) = NAMED_COLORS.iter().find(|(key, _)| *key == lower) {
                        paint = Some(Some(Color::from_rgba(rgb[0], rgb[1], rgb[2], 255)));
                    }
                    if let Some(paint) = paint {
                        if name == "fill" {
                            fill = paint;
                        } else {
                            stroke = paint;
                        }
                    }
                }
                "stroke-width" => stroke_w = num.unwrap_or(stroke_w),
                "stroke-dasharray" => {
                    dashes = value
                        .split(|c: char| c == ',' || c.is_whitespace())
                        .filter(|part| !part.is_empty())
                        .map(|part| part.parse::<f32>().unwrap_or(0.0).max(0.0))
                        .collect();
                }
                "font-size" => size_spec = Some(value.trim().to_string()),
                "style" => {
                    for decl in value.split(';') {
                        if let Some((key, spec)) = decl.split_once(':')
                            && key.trim() == "font-size"
                        {
                            size_spec = Some(spec.trim().to_string());
                        }
                    }
                }
                "text-decoration" => decoration = value.clone(),
                "x" => x = num.unwrap_or(0.0),
                "y" => y = num.unwrap_or(0.0),
                "width" => w = num.unwrap_or(0.0),
                "height" => h = num.unwrap_or(0.0),
                "rx" => rx = num,
                "ry" => ry = num,
                "cx" => cx = num.unwrap_or(0.0),
                "cy" => cy = num.unwrap_or(0.0),
                "r" => r = num.unwrap_or(0.0),
                "x1" => x1 = num.unwrap_or(0.0),
                "y1" => y1 = num.unwrap_or(0.0),
                "x2" => x2 = num.unwrap_or(0.0),
                "y2" => y2 = num.unwrap_or(0.0),
                "points" => {
                    points = value
                        .split(|c: char| c == ',' || c.is_whitespace())
                        .filter(|part| !part.is_empty())
                        .map(|part| part.parse::<f32>().unwrap_or(0.0))
                        .collect();
                }
                _ => {}
            }
        }
        // selection: the node being edited (the last selected) in
        // EDIT_COLOR, the others in SEL_COLOR, on the stroke it has
        let picked = ${!selection}.ids.iter().position(|id| *id == ${v}id);
        if let Some(place) = picked
            && let Some(attr) = own_color_attr.or(inherited_color_attr)
        {
            let last = place + 1 == ${!selection}.ids.len();
            let shown = Some(if last { EDIT_COLOR } else { SEL_COLOR });
            if attr == "fill" {
                fill = shown;
            } else {
                stroke = shown;
            }
        }
        // font-size: px (with or without the unit), or relative to the
        // default as browsers scale it (1.2 per step)
        let mut text_size = TEXT_SIZE;
        if let Some(spec) = size_spec {
            text_size = match spec.as_str() {
                "smaller" => TEXT_SIZE / 1.2,
                "larger" => TEXT_SIZE * 1.2,
                _ => spec.trim_end_matches("px").trim().parse::<f32>().unwrap_or(TEXT_SIZE),
            };
        }

        // the shape as an outline; closed shapes join the last point back to
        // the first
        let mut outline: Vec<Vec2> = vec![];
        let mut closed = false;
        match node.tag.as_str() {
            "line" => outline = vec![vec2(x1, y1), vec2(x2, y2)],
            "polyline" => {
                outline = points.chunks_exact(2).map(|pair| vec2(pair[0], pair[1])).collect();
            }
            "rect" => {
                if w > 0.0 && h > 0.0 {
                    // a lone rx or ry sets both, and neither passes half a side
                    let corner_x = rx.or(ry).unwrap_or(0.0).max(0.0).min(w / 2.0);
                    let corner_y = ry.or(rx).unwrap_or(0.0).max(0.0).min(h / 2.0);
                    if corner_x > 0.0 && corner_y > 0.0 {
                        // each corner's arc, more steps the bigger it is on screen
                        let steps = ((corner_x.max(corner_y) * ${!canvas}.zoom).sqrt() * 2.0)
                            .clamp(2.0, 24.0) as usize;
                        let centers = [
                            (vec2(x + w - corner_x, y + corner_y), -90.0f32),
                            (vec2(x + w - corner_x, y + h - corner_y), 0.0f32),
                            (vec2(x + corner_x, y + h - corner_y), 90.0f32),
                            (vec2(x + corner_x, y + corner_y), 180.0f32),
                        ];
                        for (center, start) in centers {
                            for step in 0..=steps {
                                let angle = (start + 90.0 * step as f32 / steps as f32).to_radians();
                                outline.push(center + vec2(angle.cos() * corner_x, angle.sin() * corner_y));
                            }
                        }
                    } else {
                        outline = vec![vec2(x, y), vec2(x + w, y), vec2(x + w, y + h), vec2(x, y + h)];
                    }
                    closed = true;
                }
            }
            "circle" => {
                if r > 0.0 {
                    let steps = (r * ${!canvas}.zoom * 0.5).clamp(16.0, 128.0) as usize;
                    for step in 0..steps {
                        let angle = std::f32::consts::TAU * step as f32 / steps as f32;
                        outline.push(vec2(cx + angle.cos() * r, cy + angle.sin() * r));
                    }
                    closed = true;
                }
            }
            _ => {}
        }

        // fill (svg fills an open polyline as if it were closed). rects and
        // circles are convex, so a fan from the first point covers them. A
        // polyline can be concave (a notched arrowhead, an L), so it's cut
        // into triangles by ear clipping: keep cutting off a corner that
        // turns the polygon's way and holds no other point. A polyline that
        // crosses itself may run out of ears; the rest is fanned.
        if let Some(color) = fill
            && node.tag != "line"
            && outline.len() >= 3
        {
            if node.tag != "polyline" {
                for i in 1..outline.len() - 1 {
                    draw_triangle(outline[0], outline[i], outline[i + 1], color);
                }
            } else {
                // drop repeated points, including a last point that closes
                // back onto the first
                let mut poly: Vec<Vec2> = vec![];
                for point in outline.iter().copied() {
                    if poly.last().is_none_or(|last| last.distance(point) > 1e-4) {
                        poly.push(point);
                    }
                }
                while poly.len() > 1 && poly[0].distance(poly[poly.len() - 1]) <= 1e-4 {
                    poly.pop();
                }
                // which way the polygon winds (shoelace); 0 means no area
                let mut twice_area = 0.0f32;
                for i in 0..poly.len() {
                    twice_area += poly[i].perp_dot(poly[(i + 1) % poly.len()]);
                }
                let turn = twice_area.signum();
                let mut left: Vec<usize> = (0..poly.len()).collect();
                while left.len() >= 3 && twice_area.abs() > 1e-4 {
                    let count = left.len();
                    // the first corner to cut: (its place in left, whether
                    // it has area to draw)
                    let mut cut: Option<(usize, bool)> = None;
                    let mut i = 0usize;
                    while cut.is_none() && i < count {
                        let a = poly[left[(i + count - 1) % count]];
                        let b = poly[left[i]];
                        let c = poly[left[(i + 1) % count]];
                        let corner = (b - a).perp_dot(c - b) * turn;
                        // a straight run (or a spike back on itself): drop the
                        // point, there's no area to draw
                        let straight = corner.abs() <= 1e-4;
                        if straight {
                            cut = Some((i, false));
                        }
                        // a corner that turns the polygon's way
                        if !straight && corner > 0.0 {
                            let holds_point = left.iter().any(|&other| {
                                let p = poly[other];
                                p.distance(a) > 1e-4
                                    && p.distance(b) > 1e-4
                                    && p.distance(c) > 1e-4
                                    && (b - a).perp_dot(p - a) * turn >= 0.0
                                    && (c - b).perp_dot(p - b) * turn >= 0.0
                                    && (a - c).perp_dot(p - c) * turn >= 0.0
                            });
                            if !holds_point {
                                cut = Some((i, true));
                            }
                        }
                        i += 1;
                    }
                    match cut {
                        Some((i, draw)) => {
                            if draw {
                                draw_triangle(
                                    poly[left[(i + count - 1) % count]],
                                    poly[left[i]],
                                    poly[left[(i + 1) % count]],
                                    color,
                                );
                            }
                            left.remove(i);
                        }
                        None => {
                            for i in 1..count - 1 {
                                draw_triangle(poly[left[0]], poly[left[i]], poly[left[i + 1]], color);
                            }
                            left.clear();
                        }
                    }
                }
            }
        }

        // stroke: each segment, cut into dashes when there's a dasharray. The
        // list alternates dash and gap, so stepping through a list of odd
        // length flips which entries are dashes on each pass, which is svg's
        // rule of repeating it to make it even. Zero-length dashes draw
        // nothing (svg's default butt caps). The pattern carries on from one
        // segment to the next.
        if let Some(color) = stroke
            && stroke_w > 0.0
            && outline.len() >= 2
        {
                // never thinner than a screen pixel or so, so it never vanishes
                let thickness = stroke_w.max(0.75 / ${!canvas}.zoom);
                let mut segments: Vec<(Vec2, Vec2)> =
                    outline.windows(2).map(|pair| (pair[0], pair[1])).collect();
                if closed {
                    segments.push((outline[outline.len() - 1], outline[0]));
                }
                let pattern = &dashes;
                let dashed = pattern.iter().sum::<f32>() > 0.0;
                let mut dash_i = 0usize;
                let mut dash_left = pattern.first().copied().unwrap_or(0.0);
                let mut dash_on = true;
                for (from, to) in segments {
                    let len = from.distance(to);
                    if !dashed {
                        draw_line(from.x, from.y, to.x, to.y, thickness, color);
                    } else if len > 0.0 {
                        let dir = (to - from) / len;
                        let mut pos = 0.0f32;
                        while pos < len {
                            let step = dash_left.min(len - pos);
                            if dash_on && step > 0.0 {
                                let start = from + dir * pos;
                                let end = from + dir * (pos + step);
                                draw_line(start.x, start.y, end.x, end.y, thickness, color);
                            }
                            pos += step;
                            dash_left -= step;
                            if dash_left <= 1e-4 {
                                dash_i = (dash_i + 1) % pattern.len();
                                dash_left = pattern[dash_i];
                                dash_on = !dash_on;
                            }
                        }
                    }
                }
            }

        // text: x, y is the baseline's start, as in svg
        if node.tag == "text"
            && let Some(color) = fill
        {
                // decode entities for display only; the node keeps them
                let mut decoded = String::new();
                let mut rest = node.text.as_str();
                while let Some(start) = rest.find("&#") {
                    decoded.push_str(&rest[..start]);
                    let after = &rest[start + 2..];
                    if let Some(end) = after.find(';') {
                        let digits = &after[..end];
                        let code = match digits.strip_prefix('x').or(digits.strip_prefix('X')) {
                            Some(hex) => u32::from_str_radix(hex, 16).ok(),
                            None => digits.parse::<u32>().ok(),
                        };
                        match code.and_then(char::from_u32) {
                            Some(ch) => decoded.push(ch),
                            None => decoded.push_str(&rest[start..start + 2 + end + 1]),
                        }
                        rest = &after[end + 1..];
                    } else {
                        decoded.push_str(&rest[start..]);
                        rest = "";
                    }
                }
                decoded.push_str(rest);
                // svg collapses runs of whitespace and trims the ends
                let display = decoded
                    .replace("&lt;", "<")
                    .replace("&gt;", ">")
                    .replace("&quot;", "\"")
                    .replace("&apos;", "'")
                    .replace("&amp;", "&")
                    .split_whitespace()
                    .collect::<Vec<&str>>()
                    .join(" ");

                let screen_px = text_size * ${!canvas}.zoom;
                if screen_px < TEXT_LOD_PX {
                    // too small to read: a faint bar where the text is
                    // (Times New Roman averages about 0.45em a character)
                    let bar_w = display.chars().count() as f32 * text_size * 0.45;
                    draw_line(
                        x,
                        y - text_size * 0.3,
                        x + bar_w,
                        y - text_size * 0.3,
                        text_size * 0.5,
                        Color::new(color.r, color.g, color.b, color.a * 0.35),
                    );
                } else {
                    // glyphs rasterized at their size on screen, rounded up to
                    // the next of a few fixed sizes (TEXT_PX_STEPS), so they
                    // stay crisp at any zoom without caching a new size each
                    // frame of a zoom, then scaled back to world units
                    let font_step = (screen_px.log2() * TEXT_PX_STEPS - 1e-3).ceil();
                    let font_px = 2f32
                        .powf(font_step / TEXT_PX_STEPS)
                        .round()
                        .min(TEXT_MAX_PX)
                        .max(1.0);
                    let font_scale = text_size / font_px;
                    draw_text_ex(
                        &display,
                        x,
                        y,
                        TextParams {
                            font: ${!font},
                            font_size: font_px as u16,
                            font_scale,
                            color,
                            ..Default::default()
                        },
                    );
                    let underline = decoration.contains("underline");
                    let strike = decoration.contains("line-through");
                    if underline || strike {
                        let text_w = measure_text(&display, ${!font}, font_px as u16, font_scale).width;
                        // both can be set ("underline line-through")
                        let mut line_ys: Vec<f32> = vec![];
                        if underline {
                            line_ys.push(y + text_size * 0.12);
                        }
                        if strike {
                            line_ys.push(y - text_size * 0.3);
                        }
                        for line_y in line_ys {
                            draw_line(x, line_y, x + text_w, line_y, text_size / 16.0, color);
                        }
                    }
                }
            }
    }

EOF
