#!/bin/bash

# nudge: the arrow keys move the selection (the old issueKeyName, devbox@11b5deb,
# as live moves: each press moves at once, the way gh-19 later made it).
#
#   input/output:  History    History, the page's undo history
#   input/output:  Doc        Doc, the page
#   input:         Selection  Selection
#   input:         Delta      Vec2, the move in world units
#
# Every selected node moves by Delta: x, y for a rect or a text; cx, cy for
# a circle; both ends of a line; every point of a polyline. Anything else
# (a <g>) stays. Only attributes a node already has change; numbers are read
# as JS parseFloat read them and written as JS wrote them, as map.sh does.
#
# Undo: a run of presses on the same selection is one change. The first
# press of a run snapshots the page (as history-push.sh does) and marks the
# run in History.nudge; later presses on the same selection don't. A new
# selection, any other change (history-push.sh), an undo or a redo
# (history-step.sh) ends the run.

v=$1
# maps
. ${NSMAP}/bind ${v} History Doc Selection Delta

cat << EOF

    // a run of arrow presses on one selection undoes as one
    if ${!history}.nudge.as_ref() != Some(&${!selection}.ids) {
        ${!history}.undo.push(${!doc}.clone());
        if ${!history}.undo.len() > UNDO_LIMIT {
            ${!history}.undo.remove(0);
        }
        ${!history}.redo.clear();
        ${!history}.nudge = Some(${!selection}.ids.clone());
    }

    // move each selected node by its own coordinates, x then y
    let (${v}dx, ${v}dy) = (${!delta}.x as f64, ${!delta}.y as f64);
    for &id in ${!selection}.ids.iter() {
        let Some(node) = ${!doc}.nodes.get_mut(id) else { continue };
        let names: &[(&str, bool)] = match node.tag.as_str() {
            "rect" | "text" => &[("x", true), ("y", false)],
            "circle" => &[("cx", true), ("cy", false)],
            "line" => &[("x1", true), ("y1", false), ("x2", true), ("y2", false)],
            _ => &[],
        };
        let is_polyline = node.tag == "polyline";
        for (name, value) in node.attrs.iter_mut() {
            if let Some(&(_, is_x)) = names.iter().find(|(have, _)| have == name) {
                let shift = if is_x { ${v}dx } else { ${v}dy };
                *value = format!("{}", js_parse_float(value) + shift);
            }
            if is_polyline && name == "points" {
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
