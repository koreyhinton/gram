#!/bin/bash

# draw-page: the document's white page and its border, in world space.
#
#   input:  Canvas  Canvas (for a border one screen pixel wide)

v=$1
# maps
. ${NSMAP}/bind ${v} Canvas

cat << EOF

    // the page the diagram was drawn on, as it looked in the browser
    draw_rectangle(0.0, 0.0, PAGE_W, PAGE_H, PAGE_BG);
    draw_rectangle_lines(0.0, 0.0, PAGE_W, PAGE_H, 2.0 / ${!canvas}.zoom, PAGE_BORDER);

EOF
