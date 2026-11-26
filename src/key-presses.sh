#!/bin/bash

# key-presses: this frame's key presses, counting a key whose release went
# missing.
#
#   input:         Events   &[KeyEvent], this frame's raw key events
#   input/output:  Lost     Vec<KeyCode> (declared by the caller), keys whose
#                           release may never arrive; the caller adds the
#                           keys held when it hands the focus away
#   output:        Presses  Vec<KeyCode> (declared here)
#
# A key's down event is a press, unless it repeats while the key is held.
# miniquad (X11) calls a down event a repeat until it has seen the key's up
# event. When gram starts the editor while Enter is still held, the editor
# takes the focus and Enter's up event goes to it, so miniquad would call
# every later Enter a repeat until one more press and release. So a key in
# Lost counts as pressed on its next down event, repeat or not, and leaves
# Lost then or when its up event arrives.

v=$1
# maps
. ${NSMAP}/bind ${v} Events Lost Presses

cat << EOF

    // presses: down events that aren't repeats, or that follow a lost release
    let mut ${!presses}: Vec<KeyCode> = vec![];
    for event in ${!events}.iter() {
        match *event {
            KeyEvent::Down { key, repeat } => {
                let after_lost_release = ${!lost}.contains(&key);
                if !repeat || after_lost_release {
                    ${!presses}.push(key);
                }
                ${!lost}.retain(|held| *held != key);
            }
            KeyEvent::Up { key } => ${!lost}.retain(|held| *held != key),
        }
    }

EOF
