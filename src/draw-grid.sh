#!/bin/bash

# draw-grid: the canvas's multi-level adaptive grid, in world space (call it
# with the world camera set).
#
#   input:  Canvas  Canvas
#
# Levels are GRID_SUBDIVS apart. The major level's lines are at least
# GRID_MIN_PX * GRID_SUBDIVS apart on screen, and the minor level between
# them fades out as zooming out packs its lines closer than GRID_MIN_PX.
# Lines stay the same thickness on screen at any zoom; the origin's axes are
# drawn darker.

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas

cat << EOF

    // the world rectangle on screen
    let ${v}view = Rect::new(
        ${!canvas}.offset.x,
        ${!canvas}.offset.y,
        screen_width() / ${!canvas}.zoom,
        screen_height() / ${!canvas}.zoom,
    );
    // the grid level whose spacing is GRID_MIN_PX on screen; the fractional
    // part says how far the minor level has faded
    let ${v}raw_level = (GRID_MIN_PX / ${!canvas}.zoom).log(GRID_SUBDIVS);
    let ${v}level = ${v}raw_level.floor();
    let ${v}fade = 1.0 - (${v}raw_level - ${v}level);
    let ${v}major_step = GRID_SUBDIVS.powf(${v}level) * GRID_SUBDIVS;
    let ${v}minor_step = ${v}major_step / GRID_SUBDIVS;

    // (spacing, thickness, color, whether to draw the axes): minor first, so
    // the major lines draw over it
    let mut ${v}layers: Vec<(f32, f32, Color, bool)> = vec![];
    if ${v}fade > 0.02 {
        ${v}layers.push((
            ${v}minor_step,
            1.0 / ${!canvas}.zoom,
            Color::new(GRID_MINOR.r, GRID_MINOR.g, GRID_MINOR.b, GRID_MINOR.a * ${v}fade),
            false,
        ));
    }
    ${v}layers.push((${v}major_step, 1.25 / ${!canvas}.zoom, GRID_MAJOR, true));

    for (spacing, thickness, color, axes) in ${v}layers {
        let mut x = (${v}view.x / spacing).floor() * spacing;
        while x <= ${v}view.x + ${v}view.w {
            let is_axis = axes && x.abs() < spacing * 0.01;
            if is_axis {
                draw_line(x, ${v}view.y, x, ${v}view.y + ${v}view.h, thickness * 1.5, GRID_AXIS);
            } else {
                draw_line(x, ${v}view.y, x, ${v}view.y + ${v}view.h, thickness, color);
            }
            x += spacing;
        }
        let mut y = (${v}view.y / spacing).floor() * spacing;
        while y <= ${v}view.y + ${v}view.h {
            let is_axis = axes && y.abs() < spacing * 0.01;
            if is_axis {
                draw_line(${v}view.x, y, ${v}view.x + ${v}view.w, y, thickness * 1.5, GRID_AXIS);
            } else {
                draw_line(${v}view.x, y, ${v}view.x + ${v}view.w, y, thickness, color);
            }
            y += spacing;
        }
    }

EOF
