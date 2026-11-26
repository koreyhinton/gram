#!/bin/bash

# orc paths, shared by build.sh and test.sh. Source it:
#     . ./orc-env.sh || exit 1
# It expects orc cloned (or symlinked) next to this repo (../orc). If an orc
# library is added later, export its path and version here.

orc=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../orc")

# the orc core version gram builds against; another orc stops the build. To
# move to a newer orc, bump it here and in CI's orc checkout
# (.github/workflows/rust.yml, ref: core/v<version>).
if [[ ! -f "${orc}/lib/src/main/bash/com/koreyhinton/version.sh" ]]; then
    echo "orc at ${orc} has no core version (older than core/v0.1.0): check out core/v0.1.0" >&2
    return 1 2>/dev/null || exit 1
fi
. "${orc}/lib/src/main/bash/com/koreyhinton/version.sh" 0.1.0 || { return 1 2>/dev/null || exit 1; }

export NSMAP="${orc}/lib/src/main/bash/com/koreyhinton/nsmap"
