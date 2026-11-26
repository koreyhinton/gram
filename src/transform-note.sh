#!/bin/bash

# transform-note: whether a page uses transform, which gram doesn't draw.
#
#   input:   Doc   Doc
#   output:  Note  Option<String> (declared here), what to tell the user
#
# A transform (on a <g>, or on any element) moves, scales or turns what it
# holds. gram draws those elements, and takes their clicks, as if it weren't
# there, so the page says so.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Note

cat << EOF

    // the elements whose transform gram ignores
    let ${v}transformed = ${!doc}
        .nodes
        .iter()
        .filter(|node| node.attrs.iter().any(|(name, _)| name == "transform"))
        .count();
    let ${!note}: Option<String> = if ${v}transformed > 0 {
        Some(format!(
            "transform isn't supported yet: {} element{} drawn as if it weren't there",
            ${v}transformed,
            if ${v}transformed == 1 { "" } else { "s" }
        ))
    } else {
        None
    };

EOF
