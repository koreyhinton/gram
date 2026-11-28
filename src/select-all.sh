#!/bin/bash

# select-all: Ctrl-A, every shape on the page.
#
#   input:         Doc        Doc, the page
#   input/output:  Selection  Selection
#
# Selects every shape (SHAPE_TAGS: no <g>, <defs> or <title>) in document
# order, so the last one is the node being edited. It isn't a group selection.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Selection

cat << EOF

    // every shape, in document order
    ${!selection}.ids = ${!doc}
        .nodes
        .iter()
        .enumerate()
        .filter(|(_, node)| SHAPE_TAGS.contains(&node.tag.as_str()))
        .map(|(id, _)| id)
        .collect();
    ${!selection}.group = None;

EOF
