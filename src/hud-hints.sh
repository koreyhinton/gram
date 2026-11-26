#!/bin/bash

# hud-hints: the keys and clicks that apply right now, for the status line.
#
#   input:   Doc        Doc
#   input:   Selection  Selection
#   output:  Hints      String (declared here)
#
# With nothing selected: how to pan, zoom, fit, select and select a group.
# With a selection: that Enter edits the node being edited (the last one
# selected, named by its tag), that a second click deselects a node, and
# that Esc deselects all. With a group selected: that Enter moves the group
# and a right-click goes to the group above.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Selection Hints

cat << EOF

    // what the user can do next
    let ${v}editing_tag: Option<&str> = ${!selection}
        .ids
        .last()
        .and_then(|id| ${!doc}.nodes.get(*id))
        .map(|node| node.tag.as_str());
    let ${!hints} = match (${v}editing_tag, ${!selection}.group) {
        (Some(tag), Some(_)) => format!(
            "Enter: edit the <{}> (the group moves with it), right-click: the group above, Esc: deselect all",
            tag
        ),
        (Some(tag), None) => format!(
            "Enter: edit the <{}>, click again: deselect, right-click: its group, Esc: deselect all",
            tag
        ),
        (None, _) => {
            "click: select, right-click: its group, wheel: zoom, middle-drag or space+drag: pan, F: fit"
                .to_string()
        }
    };

EOF
