#!/bin/bash

v=${1:-mn_}
# maps
export ${v}load_Text=svg_text
export ${v}load_Doc=doc
export ${v}load_Error=load_error

export ${v}index_Doc=doc
export ${v}index_Index=index

export ${v}fit_Canvas=canvas
export ${v}pan_Canvas=canvas
export ${v}grid_Canvas=canvas
export ${v}page_Canvas=canvas
export ${v}draw_Doc=doc
export ${v}draw_Index=index
export ${v}draw_Canvas=canvas
export ${v}draw_Font=font.as_ref\(\)
export ${v}hud_Canvas=canvas
export ${v}hud_Title=title

cat << EOF

    #![allow(non_snake_case)]

    use macroquad::prelude::*;
    use std::sync::Mutex;

EOF

# the app's constants and types (Node, Doc, Canvas, SpatialEntry, ...)
./models.sh

cat << EOF

    const USAGE: &str = "usage: gram <file.svg>";

    // the file loaded before the window opens: (its name, its Doc)
    static LOADED: Mutex<Option<(String, Doc)>> = Mutex::new(None);

    // Runs before the window opens, so a bad argument or file is reported
    // without flashing a window. Loads the file and titles the window after it.
    fn window_conf() -> Conf {
        let args: Vec<String> = std::env::args().skip(1).collect();
        if args.len() != 1 || args[0] == "-h" || args[0] == "--help" {
            eprintln!("{}", USAGE);
            std::process::exit(2);
        }
        let path = std::path::Path::new(&args[0]);
        if path.is_dir() {
            eprintln!(
                "gram: {}: is a folder; folders arrive with the file tree (PLAN.md step 54)",
                path.display()
            );
            std::process::exit(2);
        }
        let svg_text = match std::fs::read_to_string(path) {
            Ok(text) => text,
            Err(err) => {
                eprintln!("gram: {}: {}", path.display(), err);
                std::process::exit(1);
            }
        };

        ` ./svg-load.sh ${v}load_ `

        if let Some(err) = load_error {
            eprintln!("gram: {}: {}", path.display(), err);
            std::process::exit(1);
        }
        let title = path
            .file_name()
            .map(|name| name.to_string_lossy().to_string())
            .unwrap_or_else(|| args[0].clone());
        *LOADED.lock().unwrap() = Some((title.clone(), doc));

        Conf {
            window_title: format!("{} - gram", title),
            window_width: 1280,
            window_height: 900,
            high_dpi: true,
            sample_count: 4,
            ..Default::default()
        }
    }

    #[macroquad::main(window_conf)]
    async fn main() {
        let (title, doc) = LOADED.lock().unwrap().take().expect("window_conf loads the file");
        // Liberation Serif: the same metrics as Times New Roman, the serif
        // font the diagrams' text was laid out in
        let font = load_ttf_font_from_bytes(include_bytes!("../assets/LiberationSerif-Regular.ttf")).ok();

        ` ./spatial-index.sh ${v}index_ `

        let mut canvas = Canvas {
            offset: Vec2::ZERO,
            zoom: 1.0,
            panning: false,
            last_mouse: Vec2::from(mouse_position()),
        };
        // fit once the window has its real size
        let mut fitted_to = vec2(0.0, 0.0);

        loop {
            let screen = vec2(screen_width(), screen_height());
            if fitted_to == Vec2::ZERO && screen.x > 0.0 && screen.y > 0.0
                || is_key_pressed(KeyCode::F)
                || is_key_pressed(KeyCode::Home)
            {
                ` ./canvas-fit.sh ${v}fit_ `
                fitted_to = screen;
            }

            ` ./canvas-update.sh ${v}pan_ `

            clear_background(CANVAS_BG);

            // world space: the camera shows the canvas's view, y down like svg
            let view_w = screen_width() / canvas.zoom;
            let view_h = screen_height() / canvas.zoom;
            set_camera(&Camera2D {
                target: canvas.offset + vec2(view_w, view_h) * 0.5,
                zoom: vec2(2.0 / view_w, 2.0 / view_h),
                ..Default::default()
            });

            ` ./draw-grid.sh ${v}grid_ `
            ` ./draw-page.sh ${v}page_ `
            ` ./draw-doc.sh ${v}draw_ `

            // screen space
            set_default_camera();

            ` ./draw-hud.sh ${v}hud_ `

            next_frame().await
        }
    }

EOF
