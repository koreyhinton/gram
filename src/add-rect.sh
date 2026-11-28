#!/bin/bash

# add-rect: rect mode (key 3). A click sets one corner; the next click sets
# the opposite one (the old issueClick in numMode 3, devbox@8faf51d).
#
#   input:         Pos    Vec2, the click in world units
#   input/output:  From   Option<Vec2> (declared by the caller), the first
#                         click while it waits for the other corner
#   input/output:  Nodes  Vec<Node>, the page's nodes
#
# The first click sets From. The second appends, at the top level,
# <rect rx="0" ry="0" x y width height stroke="black" fill="transparent"
# stroke-width="1"/> between the two clicks. It can be drawn in any direction:
# x and y are the smaller corner, so width and height are never negative (the
# old app wrote a negative size, which svg doesn't draw). Clicks are rounded to
# whole numbers.

v=$1
# maps
. ${NSMAP}/bind ${v} Pos From Nodes

cat << EOF

    // a rect between the first click and this one
    // (+ 0.0 turns a -0 into 0)
    let ${v}at = ${!pos}.round() + Vec2::ZERO;
    match ${!from}.take() {
        None => ${!from} = Some(${v}at),
        Some(start) => {
            let ${v}corner = start.min(${v}at);
            let ${v}size = (start - ${v}at).abs();
            ${!nodes}.push(Node {
                tag: "rect".to_string(),
                attrs: vec![
                    ("rx".to_string(), "0".to_string()),
                    ("ry".to_string(), "0".to_string()),
                    ("x".to_string(), format!("{}", ${v}corner.x)),
                    ("y".to_string(), format!("{}", ${v}corner.y)),
                    ("width".to_string(), format!("{}", ${v}size.x)),
                    ("height".to_string(), format!("{}", ${v}size.y)),
                    ("stroke".to_string(), "black".to_string()),
                    ("fill".to_string(), "transparent".to_string()),
                    ("stroke-width".to_string(), "1".to_string()),
                ],
                text: String::new(),
                bounds: Rect::default(),
                parent: None,
            });
        }
    }

EOF
