#!/bin/bash

# editor-poll: whether the editor has exited, without waiting for it.
#
#   input/output:  Child   Option<std::process::Child> (declared by the
#                          caller, from editor-open); None once it exits
#   output:        Exited  bool (declared here), true on the frame it exits
#   output:        Failed  Option<String> (declared here), set when it exits
#                          unsuccessfully (a command that doesn't exist exits
#                          127)
#
# Uses try_wait, so the frame loop never blocks on the editor.

v=$1
# maps
. ${NSMAP}/bind ${v} Child Exited Failed

cat << EOF

    // check on the editor without waiting for it
    let mut ${!exited} = false;
    let mut ${!failed}: Option<String> = None;
    if let Some(running) = ${!child}.as_mut() {
        match running.try_wait() {
            Ok(Some(status)) => {
                ${!exited} = true;
                if !status.success() {
                    ${!failed} = Some(format!("the editor {}", status));
                }
            }
            Ok(None) => {}
            Err(err) => {
                ${!exited} = true;
                ${!failed} = Some(format!("lost the editor: {}", err));
            }
        }
    }
    if ${!exited} {
        ${!child} = None;
    }

EOF
