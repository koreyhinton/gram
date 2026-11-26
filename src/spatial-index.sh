#!/bin/bash

# spatial-index: build the R-tree over a Doc's node bounds.
#
#   input:   Doc    Doc
#   output:  Index  rstar::RTree<SpatialEntry> (declared here), one entry per
#                   shape (SHAPE_TAGS), its id the node's index in Doc.nodes
#
# Run it after mouse-rects, which sets the bounds it indexes.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Index

cat << EOF

    // index every shape's bounds, so drawing and clicking only look at the
    // nodes near the view. Elements with no shape (g, defs, title, ...) have
    // no box and stay out, so a click at (0, 0) can't land on one.
    let mut ${v}entries: Vec<SpatialEntry> = Vec::with_capacity(${!doc}.nodes.len());
    for (${v}id, ${v}node) in ${!doc}.nodes.iter().enumerate() {
        if SHAPE_TAGS.contains(&${v}node.tag.as_str()) {
            ${v}entries.push(SpatialEntry {
                id: ${v}id,
                min: [${v}node.bounds.x, ${v}node.bounds.y],
                max: [
                    ${v}node.bounds.x + ${v}node.bounds.w,
                    ${v}node.bounds.y + ${v}node.bounds.h,
                ],
            });
        }
    }
    let ${!index} = rstar::RTree::bulk_load(${v}entries);

EOF
