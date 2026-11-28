#!/bin/bash

# edit-escape: Esc while an edit is open in the editor. The canvas stays
# locked while the editor is open, so an edit is never lost or applied by
# surprise; Esc twice is the one way out from gram's side.
#
#   input:         Pressed   bool, whether Esc was pressed this frame
#   input:         Now       f64, the time (get_time)
#   input/output:  WarnedAt  Option<f64>, when the first Esc was pressed
#   output:        Drop      bool (declared here), whether to drop the edit
#
# The first Esc sets WarnedAt to Now, and the banner then asks for a second.
# Another Esc within DROP_CONFIRM_SECS of it sets Drop and clears WarnedAt; a
# later one only warns again, from Now. A frame without Esc changes nothing.

v=$1
# maps
. ${NSMAP}/bind ${v} Pressed Now WarnedAt Drop

cat << EOF

    // a second Esc soon after the first drops the edit
    let mut ${!drop} = false;
    if ${!pressed} {
        let ${v}confirms = ${!warned_at}.is_some_and(|at| ${!now} - at < DROP_CONFIRM_SECS);
        if ${v}confirms {
            ${!drop} = true;
            ${!warned_at} = None;
        } else {
            ${!warned_at} = Some(${!now});
        }
    }

EOF
