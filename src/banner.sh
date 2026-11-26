#!/bin/bash

# banner: one line of news across the top of the canvas, in screen space
# (call it with the default camera).
#
#   input:  Text  &str, what to say
#
# White on BANNER_BG, starting right of the folder tree.

v=$1
# maps
. ${NSMAP}/bind ${v} Text

cat << EOF

    // the banner, sized to its text
    let ${v}size = measure_text(${!text}, None, 20, 1.0);
    draw_rectangle(TREE_W + 12.0, 10.0, ${v}size.width + 24.0, 34.0, BANNER_BG);
    draw_text(${!text}, TREE_W + 24.0, 33.0, 20.0, BANNER_TEXT);

EOF
