#!/bin/bash

# ctrl-keys: what this frame's Ctrl chord asks for.
#
#   input:   Presses  Vec<KeyCode>, this frame's key presses (key-presses.sh)
#   input:   Ctrl     bool, whether a Ctrl key is down
#   input:   Shift    bool, whether a Shift key is down
#   output:  Action   Option<CtrlAction> (declared here)
#
# With Ctrl down: Z undoes, Shift+Z and Y redo, A selects all, S saves, and
# Shift+C copies the whole page (plain C is left for copying the selection,
# step 19). Without Ctrl, or for any other key, Action is None.

v=$1
# maps
. ${NSMAP}/bind ${v} Presses Ctrl Shift Action

cat << EOF

    // a Ctrl chord pressed this frame
    let mut ${!action}: Option<CtrlAction> = None;
    if ${!ctrl} {
        for key in ${!presses}.iter() {
            match key {
                KeyCode::Z if ${!shift} => ${!action} = Some(CtrlAction::Redo),
                KeyCode::Z => ${!action} = Some(CtrlAction::Undo),
                KeyCode::Y => ${!action} = Some(CtrlAction::Redo),
                KeyCode::A => ${!action} = Some(CtrlAction::SelectAll),
                KeyCode::S => ${!action} = Some(CtrlAction::Save),
                KeyCode::C if ${!shift} => ${!action} = Some(CtrlAction::CopyPage),
                _ => {}
            }
        }
    }

EOF
