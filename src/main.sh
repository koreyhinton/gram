#!/bin/bash

v=${1:-mn_}
# maps
export ${v}args_Arg=\&args[0]
export ${v}args_Root=root
export ${v}args_Open=open
export ${v}args_Error=arg_error

export ${v}scan_Root=root.as_path\(\)
export ${v}scan_Entries=entries

export ${v}click_Entries=ws.entries
export ${v}click_Collapsed=ws.collapsed
export ${v}click_Scroll=ws.scroll
export ${v}click_Clicked=clicked

export ${v}load_Text=svg_text
export ${v}load_Doc=doc
export ${v}load_Error=load_error

export ${v}index_Doc=doc
export ${v}index_Index=index

export ${v}fit_Canvas=page.canvas
export ${v}fit_Left=TREE_W
export ${v}pan_Canvas=page.canvas
export ${v}grid_Canvas=page.canvas
export ${v}page_Canvas=page.canvas
export ${v}draw_Doc=page.doc
export ${v}draw_Index=page.index
export ${v}draw_Canvas=page.canvas
export ${v}draw_Font=font.as_ref\(\)
export ${v}err_Title=name
export ${v}err_Error=error
export ${v}hud_Canvas=page.canvas
export ${v}hud_Title=title

export ${v}tree_Entries=ws.entries
export ${v}tree_Collapsed=ws.collapsed
export ${v}tree_Scroll=ws.scroll
export ${v}tree_Pages=ws.pages
export ${v}tree_Selected=selected
export ${v}tree_Font=font.as_ref\(\)

cat << EOF

    #![allow(non_snake_case)]

    use macroquad::prelude::*;
    use std::sync::Mutex;

EOF

# the app's constants and types (Node, Doc, Canvas, Page, Workspace, ...)
./models.sh

cat << EOF

    const USAGE: &str = "usage: gram <folder | file.svg>";

    // where gram opens, worked out before the window opens: (the folder
    // whose tree is shown, the page to open first)
    static START: Mutex<Option<(std::path::PathBuf, Option<std::path::PathBuf>)>> = Mutex::new(None);

    // Runs before the window opens, so a bad argument is reported without
    // flashing a window. Titles the window after the folder.
    fn window_conf() -> Conf {
        let args: Vec<String> = std::env::args().skip(1).collect();
        if args.len() != 1 || args[0] == "-h" || args[0] == "--help" {
            eprintln!("{}", USAGE);
            std::process::exit(2);
        }

        ` ./workspace-args.sh ${v}args_ `

        if let Some(err) = arg_error {
            eprintln!("gram: {}: {}", args[0], err);
            std::process::exit(1);
        }
        let folder = root
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_else(|| root.display().to_string());
        *START.lock().unwrap() = Some((root, open));

        Conf {
            window_title: format!("{} - gram", folder),
            window_width: 1280,
            window_height: 900,
            high_dpi: true,
            sample_count: 4,
            ..Default::default()
        }
    }

    #[macroquad::main(window_conf)]
    async fn main() {
        let (root, open) = START.lock().unwrap().take().expect("window_conf sets where gram opens");
        // Liberation Serif: the same metrics as Times New Roman, the serif
        // font the diagrams' text was laid out in
        let font = load_ttf_font_from_bytes(include_bytes!("../assets/LiberationSerif-Regular.ttf")).ok();

        ` ./tree-scan.sh ${v}scan_ `

        // the page to open first: the file gram was given, else the tree's
        // first file
        let mut to_open: Option<std::path::PathBuf> =
            open.or_else(|| entries.iter().find(|entry| !entry.is_dir).map(|entry| entry.path.clone()));
        let mut ws = Workspace {
            root,
            entries,
            collapsed: vec![],
            scroll: 0.0,
            pages: vec![],
            open: None,
        };

        loop {
            // the tree takes its clicks first; a file clicked there opens
            ` ./tree-click.sh ${v}click_ `
            if clicked.is_some() {
                to_open = clicked;
            }

            // open a page: one opened before comes back as it was left; a new
            // one is read, parsed and indexed, keeping any error to show
            if let Some(path) = to_open.take() {
                match ws.pages.iter().position(|page| page.path == path) {
                    Some(i) => ws.open = Some(i),
                    None => {
                        let (svg_text, read_error) = match std::fs::read_to_string(&path) {
                            Ok(text) => (text, None),
                            Err(err) => (String::new(), Some(err.to_string())),
                        };

                        ` ./svg-load.sh ${v}load_ `
                        ` ./spatial-index.sh ${v}index_ `

                        ws.pages.push(Page {
                            path,
                            doc,
                            index,
                            canvas: Canvas {
                                offset: Vec2::ZERO,
                                zoom: 1.0,
                                panning: false,
                                last_mouse: Vec2::from(mouse_position()),
                            },
                            error: read_error.or(load_error),
                            dirty: false,
                            fitted: false,
                        });
                        ws.open = Some(ws.pages.len() - 1);
                    }
                }
            }

            clear_background(CANVAS_BG);

            if let Some(i) = ws.open {
                let page = &mut ws.pages[i];
                let name = page
                    .path
                    .file_name()
                    .map(|name| name.to_string_lossy().to_string())
                    .unwrap_or_default();

                // fit once the window has its real size, and on F or Home
                let sized = screen_width() > 0.0 && screen_height() > 0.0;
                if sized && !page.fitted || is_key_pressed(KeyCode::F) || is_key_pressed(KeyCode::Home) {
                    ` ./canvas-fit.sh ${v}fit_ `
                    page.fitted = true;
                }

                // pan and zoom from the canvas, not the tree (a pan that
                // started on the canvas carries on over the tree)
                if mouse_position().0 >= TREE_W || page.canvas.panning {
                    ` ./canvas-update.sh ${v}pan_ `
                }

                // world space: the camera shows the canvas's view, y down like svg
                let view_w = screen_width() / page.canvas.zoom;
                let view_h = screen_height() / page.canvas.zoom;
                set_camera(&Camera2D {
                    target: page.canvas.offset + vec2(view_w, view_h) * 0.5,
                    zoom: vec2(2.0 / view_w, 2.0 / view_h),
                    ..Default::default()
                });

                ` ./draw-grid.sh ${v}grid_ `
                if page.error.is_none() {
                    ` ./draw-page.sh ${v}page_ `
                    ` ./draw-doc.sh ${v}draw_ `
                }

                // screen space
                set_default_camera();

                if let Some(error) = page.error.as_deref() {
                    ` ./page-error.sh ${v}err_ `
                }
                // the page's path in the folder, * when it has unsaved changes
                let relative = page.path.strip_prefix(&ws.root).unwrap_or(&page.path);
                let title = format!("{}{}", relative.display(), if page.dirty { "*" } else { "" });

                ` ./draw-hud.sh ${v}hud_ `
            } else {
                set_default_camera();
                draw_text(
                    &format!("no .svg files under {}", ws.root.display()),
                    TREE_W + 24.0,
                    48.0,
                    24.0,
                    HUD_TEXT,
                );
            }

            // the tree, over the canvas
            let selected: Option<&std::path::Path> = ws.open.map(|i| ws.pages[i].path.as_path());

            ` ./tree-draw.sh ${v}tree_ `

            next_frame().await
        }
    }

EOF
