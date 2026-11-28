#!/bin/bash

# add-arrow: arrow mode (key 2). A click starts an arrow; the next click ends
# it (the old issueClick in numMode 2, devbox@8faf51d).
#
#   input:         Pos    Vec2, the click in world units
#   input/output:  From   Option<Vec2> (declared by the caller), the first
#                         click while it waits for its end
#   input/output:  Nodes  Vec<Node>, the page's nodes
#
# The first click sets From. The second appends, at the top level,
# <polyline points="x1 y1 x2 y2 a1x a1y x2 y2 a2x a2y" stroke="black"
# fill="transparent" stroke-width="1"/>: the shaft, then the head's two arms
# (arrow_head) each drawn out from the tip and back. An end within STRAIGHTEN
# of the start on an axis takes the start's value there, so a nearly level
# or upright arrow comes out exactly so. Clicks are rounded to whole numbers.

v=$1
# maps
. ${NSMAP}/bind ${v} Pos From Nodes

cat << EOF

    // an arrow from the first click to this one
    // (+ 0.0 turns a -0 into 0)
    let mut ${v}at = ${!pos}.round() + Vec2::ZERO;
    match ${!from}.take() {
        None => ${!from} = Some(${v}at),
        Some(start) => {
            // nearly straight comes out straight
            if (${v}at.x - start.x).abs() < STRAIGHTEN {
                ${v}at.x = start.x;
            }
            if (${v}at.y - start.y).abs() < STRAIGHTEN {
                ${v}at.y = start.y;
            }
            let (${v}arm1, ${v}arm2) = arrow_head(start, ${v}at);
            let ${v}points = [start, ${v}at, ${v}arm1, ${v}at, ${v}arm2]
                .iter()
                .map(|point| format!("{} {}", point.x, point.y))
                .collect::<Vec<String>>()
                .join(" ");
            ${!nodes}.push(Node {
                tag: "polyline".to_string(),
                attrs: vec![
                    ("points".to_string(), ${v}points),
                    ("stroke".to_string(), "black".to_string()),
                    ("fill".to_string(), "transparent".to_string()),
                    ("stroke-width".to_string(), "1".to_string()),
                ],
                text: String::new(),
                bounds: Rect::default(),
                parent: None,
                src: None,
            });
        }
    }

EOF
