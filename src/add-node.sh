#!/bin/bash

# add-node: the one-click nodes (the old issueClick in numMode 5, 6 and 7,
# devbox@01c476e). A click places the node centered on it.
#
#   input:         Pos    Vec2, the click in world units
#   input:         Mode   u8, the mode: 5, 6 or 7
#   input/output:  Nodes  Vec<Node>, the page's nodes
#
# Mode 5, a decision node: a diamond, <polyline points> from the left corner
# round to it again, DECISION_HALF from the click each way. Mode 6, an
# initial node: a filled <circle r=INITIAL_R>. Mode 7, a final node: a filled
# dot (r=FINAL_DOT_R) then a hollow ring (r=FINAL_RING_R) around it, the dot
# first so a click in the middle picks the dot and a click on the ring the
# ring. Other modes add nothing. The click is rounded to whole numbers.

v=$1
# maps
. ${NSMAP}/bind ${v} Pos Mode Nodes

cat << EOF

    // a node centered on the click
    // (+ 0.0 turns a -0 into 0)
    let ${v}at = ${!pos}.round() + Vec2::ZERO;
    let ${v}circle = |r: f32, fill: &str| Node {
        tag: "circle".to_string(),
        attrs: vec![
            ("cx".to_string(), format!("{}", ${v}at.x)),
            ("cy".to_string(), format!("{}", ${v}at.y)),
            ("r".to_string(), format!("{}", r)),
            ("fill".to_string(), fill.to_string()),
            ("stroke".to_string(), "black".to_string()),
            ("stroke-width".to_string(), "1".to_string()),
        ],
        text: String::new(),
        bounds: Rect::default(),
        parent: None,
        src: None,
    };
    match ${!mode} {
        5 => {
            let half = DECISION_HALF;
            let corners = [
                vec2(-half, 0.0),
                vec2(0.0, -half),
                vec2(half, 0.0),
                vec2(0.0, half),
                vec2(-half, 0.0),
            ];
            let points = corners
                .iter()
                .map(|corner| format!("{} {}", ${v}at.x + corner.x, ${v}at.y + corner.y))
                .collect::<Vec<String>>()
                .join(" ");
            ${!nodes}.push(Node {
                tag: "polyline".to_string(),
                attrs: vec![
                    ("points".to_string(), points),
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
        6 => ${!nodes}.push(${v}circle(INITIAL_R, "black")),
        7 => {
            ${!nodes}.push(${v}circle(FINAL_DOT_R, "black"));
            ${!nodes}.push(${v}circle(FINAL_RING_R, "transparent"));
        }
        _ => {}
    }

EOF
