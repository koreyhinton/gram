#!/bin/bash

# copy-ready: whether a copy waiting for the clipboard can go to it now.
#
#   input:   Pending  bool, whether a copy is waiting
#   input:   Ctrl     bool, whether a Ctrl key is down
#   input:   C        bool, whether C is down
#   input:   X        bool, whether X is down
#   output:  Ready    bool (declared here)
#
# macroquad's built-in UI sets the clipboard to its own (empty) selection on
# every frame that Ctrl and C, or Ctrl and X, are down (ui.rs key_down, run
# from begin_frame), even in an app that never draws its UI. A copy made
# while the chord is still held is overwritten at once, so it waits until
# the chord is let go: Ctrl up, or both C and X up.

v=$1
# maps
. ${NSMAP}/bind ${v} Pending Ctrl C X Ready

cat << EOF

    // the clipboard is safe from macroquad once the Ctrl chord is let go
    let ${!ready} = ${!pending} && !(${!ctrl} && (${!c} || ${!x}));

EOF
