#!/bin/bash

# hit-test: the node under a world point (the old web app's xy2nd).
#
#   input:   Doc    Doc
#   input:   Index  rstar::RTree<SpatialEntry> (from spatial-index)
#   input:   Pos    Vec2, the point in world units
#   output:  Hit    Option<usize> (declared here), the node's index in
#                   Doc.nodes
#
# The R-tree finds every click box holding the point, edges included. Of
# those, the first in document order wins, as xy2nd took the first match in
# its array.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Index Pos Hit

cat << EOF

    // the first node, in document order, whose click box holds the point
    let ${!hit}: Option<usize> = ${!index}
        .locate_all_at_point([${!pos}.x, ${!pos}.y])
        .map(|entry| entry.id)
        .min();

EOF
