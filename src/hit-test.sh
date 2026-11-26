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
# those, text wins, so a click on a label inside a box picks the label (the
# old sortSvgNodes put text first in the array); then the first in document
# order, as xy2nd took the first match in its array. Only the choice is
# reordered: the document keeps its order.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Index Pos Hit

cat << EOF

    // of the nodes whose click box holds the point: text first, then the
    // first in document order
    let ${!hit}: Option<usize> = ${!index}
        .locate_all_at_point([${!pos}.x, ${!pos}.y])
        .map(|entry| entry.id)
        .min_by_key(|id| (${!doc}.nodes[*id].tag != "text", *id));

EOF
