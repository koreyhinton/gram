#!/bin/bash

# page-error: why a page couldn't be opened, in screen space beside the
# tree (call it with the default camera).
#
#   input:  Title  &str, the page's file name
#   input:  Error  &str, why it couldn't be read or parsed
#
# Two lines in ERROR_TEXT: "can't open <title>", then the error.

v=$1
# maps
. ${NSMAP}/bind ${v} Title Error

cat << EOF

    // the error in place of the page, as a browser shows a bad svg
    draw_text(&format!("can't open {}", ${!title}), TREE_W + 24.0, 48.0, 24.0, ERROR_TEXT);
    draw_text(${!error}, TREE_W + 24.0, 76.0, 20.0, ERROR_TEXT);

EOF
