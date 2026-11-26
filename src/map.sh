#!/bin/bash

# map: carry an edit of one node over to the other selected nodes (the old
# web app's smartMap).
#
#   input:         Before  &Node, the edited node before the edit (cacheNd)
#   input:         After   &Node, the edited node after it
#   input:         Others  &[usize], the other selected nodes (indexes in
#                          Nodes)
#   input/output:  Nodes   Vec<Node>
#
# Each node sits at an anchor: x, y for a rect or a text; cx, cy for a
# circle; the first point for a polyline. The edit's change of anchor moves
# each other node (a polyline moves every point), and, between shapes that
# aren't text, its change of stroke-width is added to theirs. Any pair among
# rect, circle, polyline and text maps, the same kind included; any other
# node is left alone. Numbers are read as JS
# parseFloat read them and written as JS wrote them, and only attributes a
# node already has are changed.

v=$1
# maps
. ${NSMAP}/bind ${v} Before After Others Nodes

cat << EOF

    // where the edited node sat and how wide its stroke was, before and
    // after: (x, y, stroke-width)
    let mut ${v}spots: Vec<(f64, f64, f64)> = vec![];
    for node in [${!before}, ${!after}] {
        let (mut x, mut y, mut stroke_w) = (0.0f64, 0.0f64, 0.0f64);
        let (x_name, y_name) = if node.tag == "circle" { ("cx", "cy") } else { ("x", "y") };
        for (name, value) in node.attrs.iter() {
            if name == x_name {
                x = js_parse_float(value);
            }
            if name == y_name {
                y = js_parse_float(value);
            }
            if name == "stroke-width" {
                stroke_w = js_parse_float(value);
            }
            if name == "points" && node.tag == "polyline" {
                let first: Vec<f64> = value
                    .split(|c: char| c == ',' || c.is_whitespace())
                    .filter(|part| !part.is_empty())
                    .take(2)
                    .map(js_parse_float)
                    .collect();
                x = first.first().copied().unwrap_or(0.0);
                y = first.get(1).copied().unwrap_or(0.0);
            }
        }
        ${v}spots.push((x, y, stroke_w));
    }
    let ${v}dx = ${v}spots[1].0 - ${v}spots[0].0;
    let ${v}dy = ${v}spots[1].1 - ${v}spots[0].1;
    let ${v}dstroke = ${v}spots[1].2 - ${v}spots[0].2;

    // move each other selected node by the same change
    let ${v}kinds = ["rect", "circle", "polyline", "text"];
    for &id in ${!others}.iter() {
        let dest = &mut ${!nodes}[id];
        let maps = ${v}kinds.contains(&${!after}.tag.as_str()) && ${v}kinds.contains(&dest.tag.as_str());
        // text has no stroke to widen, either way
        let widens = maps && ${!after}.tag != "text" && dest.tag != "text";
        let (x_name, y_name) = if dest.tag == "circle" { ("cx", "cy") } else { ("x", "y") };
        let is_polyline = dest.tag == "polyline";
        for (name, value) in dest.attrs.iter_mut() {
            if widens && name == "stroke-width" {
                *value = format!("{}", js_parse_float(value) + ${v}dstroke);
            }
            if maps && !is_polyline && name == x_name {
                *value = format!("{}", js_parse_float(value) + ${v}dx);
            }
            if maps && !is_polyline && name == y_name {
                *value = format!("{}", js_parse_float(value) + ${v}dy);
            }
            if maps && is_polyline && name == "points" {
                let moved: Vec<String> = value
                    .split(|c: char| c == ',' || c.is_whitespace())
                    .filter(|part| !part.is_empty())
                    .enumerate()
                    .map(|(i, part)| {
                        let shift = if i % 2 == 0 { ${v}dx } else { ${v}dy };
                        format!("{}", js_parse_float(part) + shift)
                    })
                    .collect();
                *value = moved.join(" ");
            }
        }
    }

EOF
