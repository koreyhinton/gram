#!/bin/bash

# add-line: line mode (key 1). A click starts a line; the next click ends
# it (the old issueClick in numMode 1, devbox@ed1a227).
#
#   input:         Pos    Vec2, the click in world units
#   input/output:  From   Option<Vec2> (declared by the caller), the first
#                         click while it waits for its end
#   input/output:  Nodes  Vec<Node>, the page's nodes
#
# The first click sets From. The second appends, at the top level,
# <line x1 y1 x2 y2 stroke="black" stroke-width="1"/> and clears From. The
# ends are rounded to whole numbers, as the browser's clicks were. The
# caller marks the page dirty and rebuilds its click boxes when Nodes grew.

v=$1
# maps
. ${NSMAP}/bind ${v} Pos From Nodes

cat << EOF

    // a line from the first click to this one
    // (+ 0.0 turns a -0 into 0)
    let ${v}at = ${!pos}.round() + Vec2::ZERO;
    match ${!from}.take() {
        None => ${!from} = Some(${v}at),
        Some(start) => {
            ${!nodes}.push(Node {
                tag: "line".to_string(),
                attrs: vec![
                    ("x1".to_string(), format!("{}", start.x)),
                    ("y1".to_string(), format!("{}", start.y)),
                    ("x2".to_string(), format!("{}", ${v}at.x)),
                    ("y2".to_string(), format!("{}", ${v}at.y)),
                    ("stroke".to_string(), "black".to_string()),
                    ("stroke-width".to_string(), "1".to_string()),
                ],
                text: String::new(),
                bounds: Rect::default(),
                parent: None,
            });
        }
    }

EOF
