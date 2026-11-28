#!/bin/bash

# arrow-delta: how far this frame's arrow key presses move the selection.
#
#   input:   Events  &[KeyEvent], this frame's raw key events
#   output:  Delta   Vec2 (declared here), in world units
#
# Each arrow key's down event moves 1 that way (Left -x, Right +x, Up -y,
# Down +y), repeats included, so holding a key keeps moving.

v=$1
# maps
. ${NSMAP}/bind ${v} Events Delta

cat << EOF

    // each arrow press, held repeats too, moves 1 its way
    let mut ${!delta} = Vec2::ZERO;
    for event in ${!events}.iter() {
        if let KeyEvent::Down { key, .. } = *event {
            ${!delta} += match key {
                KeyCode::Left => vec2(-1.0, 0.0),
                KeyCode::Right => vec2(1.0, 0.0),
                KeyCode::Up => vec2(0.0, -1.0),
                KeyCode::Down => vec2(0.0, 1.0),
                _ => Vec2::ZERO,
            };
        }
    }

EOF
