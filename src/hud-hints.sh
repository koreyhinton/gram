#!/bin/bash

# hud-hints: the keys and clicks that apply right now, for the status line.
#
#   input:   Doc        Doc
#   input:   Selection  Selection
#   input:   Mode       u8, the mode (0-9)
#   input:   Undo       bool, whether the page has a change to undo
#   input:   Editing    bool, whether an edit is open in the editor
#   output:  Hints      String (declared here)
#
# With nothing selected: how to pan, zoom, fit, select and select a group.
# With a selection: that Enter edits the node being edited (the last one
# selected, named by its tag), that a second click deselects a node, and
# that Esc deselects all. With a group selected: that Enter moves the group
# and a right-click goes to the group above. In a two-click mode (1 line, 2
# arrow, 3 rect, 4 rounded rect, 8 fork/join bar): that two clicks draw one;
# in a one-click mode (5 decision, 6 initial, 7 final node, 9 text): that a
# click places one; either way, how to get back to select mode. With
# something to undo, they end with ", Ctrl-Z: undo". While an edit is open in
# the editor, only how to finish or drop it (the canvas is locked).

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Selection Mode Undo Editing Hints

cat << EOF

    // what the user can do next
    let ${v}editing_tag: Option<&str> = ${!selection}
        .ids
        .last()
        .and_then(|id| ${!doc}.nodes.get(*id))
        .map(|node| node.tag.as_str());
    let ${!hints} = match (${v}editing_tag, ${!selection}.group) {
        _ if ${!editing} => "finish the edit in your editor, or Esc twice: drop it".to_string(),
        _ if [1, 2, 3, 4, 8].contains(&${!mode}) => format!(
            "click twice: draw {}, Esc: drop the first click, 0: select mode, wheel: zoom, middle-drag or space+drag: pan, F: fit",
            match ${!mode} {
                1 => "a line",
                2 => "an arrow",
                3 => "a rect",
                4 => "a rounded rect",
                _ => "a fork/join bar",
            }
        ),
        _ if [5, 6, 7, 9].contains(&${!mode}) => format!(
            "click: place {}, 0: select mode, wheel: zoom, middle-drag or space+drag: pan, F: fit",
            match ${!mode} {
                5 => "a decision node",
                6 => "an initial node",
                7 => "a final node",
                _ => "a text (it opens in your editor)",
            }
        ),
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
    // undo, once there is something to undo (not while editing: it's locked)
    let ${!hints} = if ${!undo} && !${!editing} { format!("{}, Ctrl-Z: undo", ${!hints}) } else { ${!hints} };

EOF
