#!/bin/bash

# canvas-fit: zoom and center the canvas so the whole page fits the screen.
#
#   input/output:  Canvas  Canvas (declared by the caller)

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas

cat << EOF

    // fit the page inside the screen, less a margin, and center it
    let ${v}avail = vec2(
        (screen_width() - 2.0 * FIT_MARGIN).max(1.0),
        (screen_height() - 2.0 * FIT_MARGIN).max(1.0),
    );
    ${!canvas}.zoom = (${v}avail.x / PAGE_W)
        .min(${v}avail.y / PAGE_H)
        .clamp(ZOOM_MIN, ZOOM_MAX);
    ${!canvas}.offset = vec2(PAGE_W, PAGE_H) * 0.5
        - vec2(screen_width(), screen_height()) * 0.5 / ${!canvas}.zoom;

EOF
