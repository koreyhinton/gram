#!/bin/bash

# select: a click on a node selects or deselects it (the old web app's
# issueSelection).
#
#   input/output:  Selection  Selection (declared by the caller)
#   input:         Hit        Option<usize>, the clicked node (from hit-test)
#
# An unselected node joins the end of the selection, so it becomes the node
# being edited and the one before it goes back to the selected color. A
# selected node leaves the selection. A click on empty space changes
# nothing.

v=$1
# maps
. ${NSMAP}/bind ${v} Selection Hit

cat << EOF

    // toggle the clicked node in the selection
    let ${v}was_selected = ${!hit}.is_some_and(|id| ${!selection}.ids.contains(&id));
    if let Some(id) = ${!hit}
        && ${v}was_selected
    {
        ${!selection}.ids.retain(|other| *other != id);
    }
    if let Some(id) = ${!hit}
        && !${v}was_selected
    {
        ${!selection}.ids.push(id);
    }

EOF
