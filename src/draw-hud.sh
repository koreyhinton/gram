#!/bin/bash

# draw-hud: the status line along the bottom, right of the folder tree, with
# the hints on a line above it, in screen space (call it with the default
# camera).
#
#   input:  Canvas  Canvas
#   input:  Title   &str, the open file's name
#   input:  Hints   &str, what the user can do next (from hud-hints)

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas Title Hints

cat << EOF

    // the hints, then file, zoom and the world point under the mouse
    draw_text(${!hints}, TREE_W + 12.0, screen_height() - 38.0, 20.0, HUD_TEXT);
    let ${v}mouse = ${!canvas}.offset + Vec2::from(mouse_position()) / ${!canvas}.zoom;
    draw_text(
        &format!(
            "{}  |  {:.0}%  |  ({:.0}, {:.0})",
            ${!title},
            ${!canvas}.zoom * 100.0,
            ${v}mouse.x,
            ${v}mouse.y
        ),
        TREE_W + 12.0,
        screen_height() - 12.0,
        20.0,
        HUD_TEXT,
    );

EOF
