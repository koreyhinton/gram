#!/bin/bash

# canvas-update: pan and zoom the canvas from this frame's mouse and keys.
#
#   input/output:  Canvas  Canvas (declared by the caller)
#
# Pan: middle-drag, or Space + left-drag. Zoom: the wheel, keeping the world
# point under the cursor in place.

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas

cat << EOF

    // pan: drag the world along with the mouse
    let ${v}mouse = Vec2::from(mouse_position());
    let ${v}pan_held = is_mouse_button_down(MouseButton::Middle)
        || (is_key_down(KeyCode::Space) && is_mouse_button_down(MouseButton::Left));
    if ${v}pan_held && ${!canvas}.panning {
        ${!canvas}.offset -= (${v}mouse - ${!canvas}.last_mouse) / ${!canvas}.zoom;
    }
    ${!canvas}.panning = ${v}pan_held;
    ${!canvas}.last_mouse = ${v}mouse;

    // zoom by a fixed factor per wheel notch, anchored at the cursor
    let (_, ${v}wheel_y) = mouse_wheel();
    if ${v}wheel_y != 0.0 {
        let ${v}world_before = ${!canvas}.offset + ${v}mouse / ${!canvas}.zoom;
        let ${v}factor = if ${v}wheel_y > 0.0 { ZOOM_STEP } else { 1.0 / ZOOM_STEP };
        ${!canvas}.zoom = (${!canvas}.zoom * ${v}factor).clamp(ZOOM_MIN, ZOOM_MAX);
        ${!canvas}.offset = ${v}world_before - ${v}mouse / ${!canvas}.zoom;
    }

EOF
