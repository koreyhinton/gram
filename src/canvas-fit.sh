#!/bin/bash

# canvas-fit: zoom and center the canvas so the whole page fits the part of
# the screen it's shown in.
#
#   input/output:  Canvas  Canvas (declared by the caller)
#   input:         Left    f32, screen pixels at the left covered by a panel
#                          (the folder tree), so not part of the view
#
# The page fits the screen right of Left, less FIT_MARGIN all round, and is
# centered there.

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas Left

cat << EOF

    // fit the page inside the screen right of the panel, less a margin, and
    // center it there
    let ${v}avail = vec2(
        (screen_width() - ${!left} - 2.0 * FIT_MARGIN).max(1.0),
        (screen_height() - 2.0 * FIT_MARGIN).max(1.0),
    );
    ${!canvas}.zoom = (${v}avail.x / PAGE_W)
        .min(${v}avail.y / PAGE_H)
        .clamp(ZOOM_MIN, ZOOM_MAX);
    let ${v}view_center = vec2(${!left} + (screen_width() - ${!left}) * 0.5, screen_height() * 0.5);
    ${!canvas}.offset = vec2(PAGE_W, PAGE_H) * 0.5 - ${v}view_center / ${!canvas}.zoom;

EOF
