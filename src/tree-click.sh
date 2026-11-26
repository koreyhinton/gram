#!/bin/bash

# tree-click: this frame's mouse in the folder tree panel.
#
#   input:         Entries    &[TreeEntry] (from tree-scan)
#   input/output:  Collapsed  Vec<std::path::PathBuf>, the folded folders
#                             (declared by the caller)
#   input/output:  Scroll     f32, how far the tree is scrolled, in screen
#                             pixels (declared by the caller)
#   output:        Clicked    Option<std::path::PathBuf> (declared here), the
#                             file clicked this frame, to open
#
# Only acts with the mouse over the panel (x < TREE_W). The wheel scrolls
# TREE_SCROLL_ROWS rows a notch, kept between the top and the last row. A
# left click on a folder folds or unfolds it; on a file, reports the file.
# Rows under a folded folder are hidden and take no space.

v=$1
# maps
. ${NSMAP}/bind ${v} Entries Collapsed Scroll Clicked

cat << EOF

    // the rows shown: each entry not inside a folded folder
    let mut ${v}rows: Vec<usize> = vec![];
    let mut ${v}hide_below: Option<usize> = None;
    for (i, entry) in ${!entries}.iter().enumerate() {
        let hidden = ${v}hide_below.is_some_and(|depth| entry.depth > depth);
        if !hidden {
            ${v}hide_below = None;
            ${v}rows.push(i);
        }
        if !hidden && entry.is_dir && ${!collapsed}.contains(&entry.path) {
            ${v}hide_below = Some(entry.depth);
        }
    }

    let mut ${!clicked}: Option<std::path::PathBuf> = None;
    let ${v}mouse = Vec2::from(mouse_position());
    let ${v}over = ${v}mouse.x >= 0.0 && ${v}mouse.x < TREE_W;

    // the wheel scrolls; scrolling stops at the top and at the last row
    let (_, ${v}wheel_y) = mouse_wheel();
    if ${v}over && ${v}wheel_y != 0.0 {
        ${!scroll} -= ${v}wheel_y.signum() * TREE_SCROLL_ROWS * TREE_ROW_H;
    }
    let ${v}content_h = ${v}rows.len() as f32 * TREE_ROW_H + 2.0 * TREE_PAD;
    ${!scroll} = ${!scroll}.clamp(0.0, (${v}content_h - screen_height()).max(0.0));

    // a click: fold or unfold a folder, or open a file
    let ${v}row = ((${v}mouse.y + ${!scroll} - TREE_PAD) / TREE_ROW_H).floor();
    if ${v}over
        && is_mouse_button_pressed(MouseButton::Left)
        && ${v}row >= 0.0
        && (${v}row as usize) < ${v}rows.len()
    {
        let entry = &${!entries}[${v}rows[${v}row as usize]];
        let folded = ${!collapsed}.contains(&entry.path);
        if entry.is_dir && folded {
            ${!collapsed}.retain(|path| path != &entry.path);
        } else if entry.is_dir {
            ${!collapsed}.push(entry.path.clone());
        } else {
            ${!clicked} = Some(entry.path.clone());
        }
    }

EOF
