#!/bin/bash

# draw-hud: the status line along the bottom, right of the folder tree, in
# screen space (call it with the default camera).
#
#   input:  Canvas  Canvas
#   input:  Title   &str, the open file's name

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas Title

cat << EOF

    // file, zoom and the world point under the mouse
    let ${v}mouse = ${!canvas}.offset + Vec2::from(mouse_position()) / ${!canvas}.zoom;
    draw_text(
        &format!(
            "{}  |  {:.0}%  |  ({:.0}, {:.0})  |  wheel: zoom, middle-drag or space+drag: pan, F: fit",
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
