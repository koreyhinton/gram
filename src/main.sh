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
export ${v}click_Selected=open_path.as_deref\(\)
export ${v}click_Clicked=clicked
export ${v}click_EditFile=edit_file

# a file read from disk (a page opening, a page reloading, a node edit)
export ${v}load_Text=svg_text
export ${v}load_Doc=doc
export ${v}load_Error=load_error
export ${v}rects_Nodes=doc.nodes
export ${v}index_Doc=doc
export ${v}index_Index=index

# the editor
export ${v}pick_Editor=editor
export ${v}open_Editor=\&editor
export ${v}open_Path=path.as_path\(\)
export ${v}open_Child=child
export ${v}open_Error=open_error
export ${v}poll_Child=job.child
export ${v}poll_Exited=exited
export ${v}poll_Failed=failed
export ${v}watch_Path=job.path.as_path\(\)
export ${v}watch_Stamp=job.stamp
export ${v}watch_Changed=changed

# a node edit: the node out as XML, the edit back in, carried over to the
# other selected nodes, then the page's boxes and R-tree again
export ${v}xml_Node=\(\&page.doc.nodes[edit_id]\)
export ${v}xml_Xml=xml
export ${v}apply_Edited=\(\&doc.nodes[0]\)
export ${v}apply_Target=page.doc.nodes[edit_id]
export ${v}map_Before=\(\&before\)
export ${v}map_After=\(\&after\)
export ${v}map_Others=\(\&others\)
export ${v}map_Nodes=page.doc.nodes
export ${v}prects_Nodes=page.doc.nodes
export ${v}pindex_Doc=page.doc
export ${v}pindex_Index=index

# a click on the canvas
export ${v}hit_Doc=page.doc
export ${v}hit_Index=page.index
export ${v}hit_Pos=world
export ${v}hit_Hit=hit
export ${v}sel_Selection=page.selection
export ${v}sel_Hit=hit

export ${v}fit_Canvas=page.canvas
export ${v}fit_Left=TREE_W
export ${v}pan_Canvas=page.canvas
export ${v}grid_Canvas=page.canvas
export ${v}page_Canvas=page.canvas
export ${v}draw_Doc=page.doc
export ${v}draw_Index=page.index
export ${v}draw_Canvas=page.canvas
export ${v}draw_Font=font.as_ref\(\)
export ${v}draw_Selection=page.selection
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
export ${v}banner_Text=\&message

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
            mode: 0,
            edit: None,
        };
        // the page whose edit button warned that its unsaved changes would
        // be replaced, and when (a second click within 5 seconds opens it)
        let mut file_warning: Option<(usize, f64)> = None;

        loop {
            let open_path: Option<std::path::PathBuf> = ws.open.map(|i| ws.pages[i].path.clone());
            let editing = ws.edit.is_some();

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
                        ` ./mouse-rects.sh ${v}rects_ `
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
                            selection: Selection::default(),
                        });
                        ws.open = Some(ws.pages.len() - 1);
                    }
                }
            }

            // ---- the editor gram started, checked each frame ----
            // a node edit that came back changed: its XML
            let mut edited: Option<String> = None;
            // a file edit saw a save: reload the page
            let mut reload = false;
            let mut done = false;
            if let Some(job) = ws.edit.as_mut() {
                ` ./editor-poll.sh ${v}poll_ `
                if let Some(reason) = failed {
                    job.error = Some(reason);
                }
                if job.kind == EditKind::Node && exited && job.error.is_none() {
                    match std::fs::read_to_string(&job.path) {
                        // unchanged: nothing to apply
                        Ok(text) if text == job.written => done = true,
                        Ok(text) => edited = Some(text),
                        Err(err) => job.error = Some(err.to_string()),
                    }
                }
                if job.kind == EditKind::File {
                    ` ./file-watch.sh ${v}watch_ `
                    reload = changed;
                    // stop with the editor, unless it handed the file off and
                    // returned at once; then keep watching until Esc
                    done = exited && job.error.is_none() && get_time() - job.started > 2.0;
                }
            }

            // a node edit came back: it must be one element. Apply it to the
            // node being edited, carry it over to the other selected nodes,
            // then deselect all (the old onApplyEdits and onDone).
            if let Some(text) = edited {
                let svg_text = format!("<svg>{}</svg>", text);

                ` ./svg-load.sh ${v}load_ `

                let refused = match load_error {
                    Some(err) => Some(err),
                    None if doc.nodes.len() != 1 => {
                        Some(format!("the edit must be one element; it has {}", doc.nodes.len()))
                    }
                    None => None,
                };
                let job_page = ws.edit.as_ref().map(|job| job.page).unwrap_or(0);
                let before = ws.edit.as_ref().and_then(|job| job.before.clone());
                if let Some(reason) = refused
                    && let Some(job) = ws.edit.as_mut()
                {
                    job.error = Some(reason);
                } else if let Some(before) = before {
                    let page = &mut ws.pages[job_page];
                    if let Some(&edit_id) = page.selection.ids.last() {
                        ` ./node-apply.sh ${v}apply_ `

                        let after = page.doc.nodes[edit_id].clone();
                        let others: Vec<usize> = page.selection.ids[..page.selection.ids.len() - 1].to_vec();

                        ` ./map.sh ${v}map_ `
                        ` ./mouse-rects.sh ${v}prects_ `
                        ` ./spatial-index.sh ${v}pindex_ `

                        page.index = index;
                        page.selection = Selection::default();
                        page.dirty = true;
                    }
                    done = true;
                }
            }

            // a file edit saved: the page again, from disk, as it now is
            if reload && let Some(job_page) = ws.edit.as_ref().map(|job| job.page) {
                let page = &mut ws.pages[job_page];
                let (svg_text, read_error) = match std::fs::read_to_string(&page.path) {
                    Ok(text) => (text, None),
                    Err(err) => (String::new(), Some(err.to_string())),
                };

                ` ./svg-load.sh ${v}load_ `
                ` ./mouse-rects.sh ${v}rects_ `
                ` ./spatial-index.sh ${v}index_ `

                page.doc = doc;
                page.index = index;
                page.error = read_error.or(load_error);
                page.selection = Selection::default();
                page.dirty = false;
            }
            if done {
                ws.edit = None;
            }

            // ---- keys ----
            // Esc: drop a refused edit or stop watching a file (once its
            // editor is gone), else deselect all (the old Done button)
            if is_key_pressed(KeyCode::Escape) {
                let stop = ws.edit.as_ref().is_some_and(|job| job.child.is_none());
                if stop {
                    ws.edit = None;
                }
                if !editing && let Some(i) = ws.open {
                    ws.pages[i].selection = Selection::default();
                }
            }

            // R: a refused node edit goes back to the editor, as it was left
            let reopen = is_key_pressed(KeyCode::R)
                && ws.edit.as_ref().is_some_and(|job| job.kind == EditKind::Node && job.child.is_none());
            if reopen && let Some(job) = ws.edit.as_mut() {
                let path = job.path.clone();

                ` ./editor-pick.sh ${v}pick_ `
                ` ./editor-open.sh ${v}open_ `

                job.child = child;
                job.error = open_error;
                job.started = get_time();
            }

            // 0-9: the mode (only 0, select, does anything yet)
            let digits = [
                KeyCode::Key0, KeyCode::Key1, KeyCode::Key2, KeyCode::Key3, KeyCode::Key4,
                KeyCode::Key5, KeyCode::Key6, KeyCode::Key7, KeyCode::Key8, KeyCode::Key9,
            ];
            for (num, key) in digits.iter().enumerate() {
                if !editing && is_key_pressed(*key) {
                    ws.mode = num as u8;
                }
            }

            // Enter: the node being edited (the last selected) goes to the
            // editor as XML in a temp file
            let enter = is_key_pressed(KeyCode::Enter) || is_key_pressed(KeyCode::KpEnter);
            if enter
                && !editing
                && let Some(job_page) = ws.open
                && let Some(&edit_id) = ws.pages[job_page].selection.ids.last()
            {
                let page = &ws.pages[job_page];

                ` ./node-xml.sh ${v}xml_ `

                let dir = std::env::temp_dir().join(format!("gram-{}", std::process::id()));
                let path = dir.join("node.svg");
                let written = std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&path, &xml));

                ` ./editor-pick.sh ${v}pick_ `
                ` ./editor-open.sh ${v}open_ `

                ws.edit = Some(EditJob {
                    kind: EditKind::Node,
                    page: job_page,
                    path,
                    child,
                    written: xml,
                    before: Some(page.doc.nodes[edit_id].clone()),
                    stamp: None,
                    error: written.err().map(|err| err.to_string()).or(open_error),
                    started: get_time(),
                });
            }

            // the edit button: the page's own file goes to the editor, and
            // gram reloads the page on each save. A page with unsaved
            // changes warns first, since the file's text replaces them.
            if edit_file
                && !editing
                && let Some(job_page) = ws.open
            {
                let warned = file_warning.is_some_and(|(i, at)| i == job_page && get_time() - at < 5.0);
                if ws.pages[job_page].dirty && !warned {
                    file_warning = Some((job_page, get_time()));
                } else {
                    file_warning = None;
                    let path = ws.pages[job_page].path.clone();

                    ` ./editor-pick.sh ${v}pick_ `
                    ` ./editor-open.sh ${v}open_ `

                    let mut job = EditJob {
                        kind: EditKind::File,
                        page: job_page,
                        path,
                        child,
                        written: String::new(),
                        before: None,
                        stamp: None,
                        error: open_error,
                        started: get_time(),
                    };
                    // the first look, so only later saves count
                    {
                        ` ./file-watch.sh ${v}watch_ `

                        let _ = changed;
                    }
                    ws.edit = Some(job);
                }
            }
            let editing = ws.edit.is_some();

            // a left click on the canvas (not the tree, not a pan) selects
            let mouse = Vec2::from(mouse_position());
            let canvas_click = is_mouse_button_pressed(MouseButton::Left)
                && mouse.x >= TREE_W
                && !is_key_down(KeyCode::Space)
                && !editing;

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

                // a click selects or deselects the node under it
                if canvas_click && page.error.is_none() {
                    let world = page.canvas.offset + mouse / page.canvas.zoom;

                    ` ./hit-test.sh ${v}hit_ `
                    ` ./select.sh ${v}sel_ `
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
                let title = format!(
                    "{}{}  |  mode {}",
                    relative.display(),
                    if page.dirty { "*" } else { "" },
                    ws.mode
                );

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

            // the banner: what the editor is doing, or a warning
            let file_name = |i: usize| {
                ws.pages[i].path.file_name().map(|name| name.to_string_lossy().to_string()).unwrap_or_default()
            };
            let mut message = String::new();
            if let Some(job) = ws.edit.as_ref() {
                let tag = job.before.as_ref().map(|node| node.tag.clone()).unwrap_or_default();
                message = match (job.kind, job.child.is_some(), job.error.as_ref()) {
                    (_, _, Some(err)) if job.kind == EditKind::Node => {
                        format!("{}  -  R: edit again, Esc: drop the edit", err)
                    }
                    (_, _, Some(err)) => format!("{}  -  Esc: close", err),
                    (EditKind::Node, _, None) => {
                        format!("editing the <{}> in your editor: close it to apply the edit", tag)
                    }
                    (EditKind::File, true, None) => {
                        format!("editing {} in your editor: gram reloads it on each save", file_name(job.page))
                    }
                    (EditKind::File, false, None) => {
                        format!("watching {} for saves  -  Esc: stop", file_name(job.page))
                    }
                };
            }
            if let Some((i, at)) = file_warning
                && get_time() - at < 5.0
            {
                message = format!(
                    "{} has unsaved changes; the file replaces them. Click edit again to open it",
                    file_name(i)
                );
            }
            if !message.is_empty() {
                ` ./banner.sh ${v}banner_ `
            }

            next_frame().await
        }
    }

EOF
