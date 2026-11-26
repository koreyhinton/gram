#!/bin/bash

# tree-draw: the folder tree panel, in screen space (call it with the
# default camera, after the canvas so it draws on top).
#
#   input:  Entries    &[TreeEntry] (from tree-scan)
#   input:  Collapsed  &[std::path::PathBuf], the folded folders
#   input:  Scroll     f32, how far the tree is scrolled (from tree-click)
#   input:  Pages      &[Page], the pages opened so far
#   input:  Selected   Option<&std::path::Path>, the open page's file
#   input:  Font       Option<&Font>, None for macroquad's default font
#
# A TREE_W panel down the left. Each shown row is indented by its depth. A
# folder reads "+ name" when folded and "- name" when open. A file reads
# its name, with "*" after it when its page has unsaved changes, in
# ERROR_TEXT when its page couldn't be opened. The selected file's row is
# highlighted and ends in an "edit" button (TREE_BUTTON_W wide). A name too
# long for its row is cut short with "…".

v=$1
# maps
. ${NSMAP}/bind ${v} Entries Collapsed Scroll Pages Selected Font

cat << EOF

    // the panel
    draw_rectangle(0.0, 0.0, TREE_W, screen_height(), TREE_BG);
    draw_line(TREE_W, 0.0, TREE_W, screen_height(), 1.0, TREE_BORDER);

    // the rows shown: each entry not inside a folded folder
    let mut ${v}row = 0usize;
    let mut ${v}hide_below: Option<usize> = None;
    for entry in ${!entries}.iter() {
        let hidden = ${v}hide_below.is_some_and(|depth| entry.depth > depth);
        let folded = entry.is_dir && ${!collapsed}.contains(&entry.path);
        if !hidden {
            ${v}hide_below = None;
        }
        if !hidden && folded {
            ${v}hide_below = Some(entry.depth);
        }

        let top = TREE_PAD + ${v}row as f32 * TREE_ROW_H - ${!scroll};
        let in_view = top + TREE_ROW_H > 0.0 && top < screen_height();
        if !hidden && in_view {
            let page = ${!pages}.iter().find(|page| page.path == entry.path);
            let is_selected = ${!selected} == Some(entry.path.as_path());
            if is_selected {
                draw_rectangle(0.0, top, TREE_W, TREE_ROW_H, TREE_SELECTED);
            }
            let mut label = if entry.is_dir && folded {
                format!("+ {}", entry.name)
            } else if entry.is_dir {
                format!("- {}", entry.name)
            } else if page.is_some_and(|page| page.dirty) {
                format!("{}*", entry.name)
            } else {
                entry.name.clone()
            };
            let color = if page.is_some_and(|page| page.error.is_some()) {
                ERROR_TEXT
            } else {
                TREE_TEXT
            };

            // cut a long name short to fit the panel
            let x = TREE_PAD + entry.depth as f32 * TREE_INDENT;
            let button_w = if is_selected { TREE_BUTTON_W } else { 0.0 };
            let room = TREE_W - x - TREE_PAD - button_w;
            let mut cut = false;
            while !label.is_empty()
                && measure_text(&format!("{}{}", label, if cut { "…" } else { "" }), ${!font}, TREE_TEXT_PX, 1.0).width > room
            {
                label.pop();
                cut = true;
            }
            if cut {
                label.push('…');
            }

            draw_text_ex(
                &label,
                x,
                top + TREE_ROW_H * 0.72,
                TextParams {
                    font: ${!font},
                    font_size: TREE_TEXT_PX,
                    color,
                    ..Default::default()
                },
            );

            // the open page's edit button
            if is_selected {
                let left = TREE_W - TREE_BUTTON_W;
                draw_rectangle(left + 2.0, top + 3.0, TREE_BUTTON_W - 6.0, TREE_ROW_H - 6.0, TREE_BG);
                draw_rectangle_lines(left + 2.0, top + 3.0, TREE_BUTTON_W - 6.0, TREE_ROW_H - 6.0, 1.0, TREE_BORDER);
                draw_text_ex(
                    TREE_BUTTON_LABEL,
                    left + 7.0,
                    top + TREE_ROW_H * 0.68,
                    TextParams {
                        font: ${!font},
                        font_size: TREE_TEXT_PX - 2,
                        color: TREE_TEXT,
                        ..Default::default()
                    },
                );
            }
        }
        if !hidden {
            ${v}row += 1;
        }
    }

EOF
