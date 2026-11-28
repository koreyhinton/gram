#!/bin/bash

# mode-notice: the mode just picked, in large type at the top right for a
# few seconds, in screen space (call it with the default camera).
#
#   input:  Mode   u8, the mode (0-9)
#   input:  Since  f64, seconds since the mode was picked
#
# "0 => Select Mode", "1 => Line Mode", "2 => Arrow Mode", "3 => Rect Mode",
# or "N => Coming Soon" for the modes that do nothing yet, white on NOTICE_BG, for MODE_NOTICE_SECS.

v=$1
# maps
. ${NSMAP}/bind ${v} Mode Since

cat << EOF

    // the mode's notice, while it's fresh
    if ${!since} < MODE_NOTICE_SECS {
        let text = match ${!mode} {
            0 => "0 => Select Mode".to_string(),
            1 => "1 => Line Mode".to_string(),
            2 => "2 => Arrow Mode".to_string(),
            3 => "3 => Rect Mode".to_string(),
            other => format!("{} => Coming Soon", other),
        };
        let size = measure_text(&text, None, NOTICE_PX, 1.0);
        let left = screen_width() - size.width - 24.0;
        draw_rectangle(left - 12.0, 0.0, size.width + 36.0, NOTICE_PX as f32 + 24.0, NOTICE_BG);
        draw_text(&text, left, NOTICE_PX as f32 + 4.0, NOTICE_PX as f32, NOTICE_TEXT);
    }

EOF
