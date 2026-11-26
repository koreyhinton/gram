#!/bin/bash

# file-watch: whether a file changed on disk since it was last looked at.
#
#   input:         Path     &std::path::Path, the file
#   input/output:  Stamp    Option<(std::time::SystemTime, u64)> (declared by
#                           the caller), the modified time and length last
#                           seen; None when the file couldn't be read
#   output:        Changed  bool (declared here), true when the stamp moved
#
# Call it once to take the first stamp (ignoring Changed), then each frame
# while the file is being edited. A save changes the modified time, and
# usually the length; either one counts.

v=$1
# maps
. ${NSMAP}/bind ${v} Path Stamp Changed

cat << EOF

    // the file's modified time and length now, against the last look
    let ${v}now: Option<(std::time::SystemTime, u64)> = std::fs::metadata(${!path})
        .ok()
        .and_then(|meta| meta.modified().ok().map(|time| (time, meta.len())));
    let ${!changed} = ${v}now != ${!stamp};
    ${!stamp} = ${v}now;

EOF
