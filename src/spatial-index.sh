#!/bin/bash

# spatial-index: build the R-tree over a Doc's node bounds.
#
#   input:   Doc    Doc
#   output:  Index  rstar::RTree<SpatialEntry> (declared here), one entry per
#                   node, its id the node's index in Doc.nodes

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Index

cat << EOF

    // index every node's bounds, so drawing (and later clicking) only looks
    // at the nodes near the view
    let mut ${v}entries: Vec<SpatialEntry> = Vec::with_capacity(${!doc}.nodes.len());
    for (${v}id, ${v}node) in ${!doc}.nodes.iter().enumerate() {
        ${v}entries.push(SpatialEntry {
            id: ${v}id,
            min: [${v}node.bounds.x, ${v}node.bounds.y],
            max: [
                ${v}node.bounds.x + ${v}node.bounds.w,
                ${v}node.bounds.y + ${v}node.bounds.h,
            ],
        });
    }
    let ${!index} = rstar::RTree::bulk_load(${v}entries);

EOF
