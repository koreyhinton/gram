#!/bin/bash

# orc paths, shared by build.sh and test.sh. Source it:
#     . ./orc-env.sh
# It expects orc cloned (or symlinked) next to this repo (../orc). If an orc
# library is added later, export its path and version here.

orc=$(realpath "$(dirname "${BASH_SOURCE[0]}")/../orc")
export NSMAP="${orc}/lib/src/main/bash/com/koreyhinton/nsmap"
