#!/bin/bash

# add-text: text mode (key 9). A click places a new text and opens it in the
# editor (the old issueClick in numMode 9, devbox@01c476e).
#
#   input:         Pos        Vec2, the click in world units
#   input/output:  Nodes      Vec<Node>, the page's nodes
#   input/output:  Selection  Selection
#   input/output:  Mode       u8, the mode
#   output:        Open       bool (declared here), whether to open the editor
#
# Appends <text x y fill="black">?</text>, placed TEXT_OFFSET from the click so
# the "?" sits under the cursor, and makes it the only node selected, as the
# old app did. Then back to select mode (0), with Open set: the caller opens
# the new text in the editor, as Enter does. The click is rounded to whole
# numbers.

v=$1
# maps
. ${NSMAP}/bind ${v} Pos Nodes Selection Mode Open

cat << EOF

    // a "?" to type over, selected and handed to the editor
    // (+ 0.0 turns a -0 into 0)
    let ${v}at = (${!pos}.round() + TEXT_OFFSET) + Vec2::ZERO;
    ${!nodes}.push(Node {
        tag: "text".to_string(),
        attrs: vec![
            ("x".to_string(), format!("{}", ${v}at.x)),
            ("y".to_string(), format!("{}", ${v}at.y)),
            ("fill".to_string(), "black".to_string()),
        ],
        text: "?".to_string(),
        bounds: Rect::default(),
        parent: None,
        src: None,
    });
    ${!selection} = Selection { ids: vec![${!nodes}.len() - 1], group: None };
    ${!mode} = 0;
    let ${!open} = true;

EOF
