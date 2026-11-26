#!/bin/bash

# select-group: a right-click selects a group: every shape inside a <g>.
#
#   input:         Doc        Doc
#   input:         Hit        Option<usize>, the right-clicked node (from
#                             hit-test), or None for empty space
#   input/output:  Selection  Selection (declared by the caller)
#
# The group is the nearest <g> around the clicked node (or, on empty space,
# around the node being edited). When a group is already selected and the
# click is inside it or on empty space, it's the <g> around that one: each
# right-click goes one <g> up. The selection becomes the group's shapes, in
# document order, with the clicked node last, so it's the one Enter edits
# and the rest move with it (map). With no <g> to go to, nothing changes.
# Selection.group remembers the <g>; a left click (select.sh) clears it.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Hit Selection

cat << EOF

    // the node the right-click is about: the clicked one, else the one being
    // edited
    let ${v}base: Option<usize> = ${!hit}.or(${!selection}.ids.last().copied());

    // whether the click is inside the selected group (or on empty space)
    let mut ${v}inside_group = false;
    if let Some(group) = ${!selection}.group {
        let mut up = ${!hit};
        while let Some(at) = up {
            ${v}inside_group = ${v}inside_group || at == group;
            up = ${!doc}.nodes[at].parent;
        }
        ${v}inside_group = ${v}inside_group || ${!hit}.is_none();
    }

    // the <g> to select: above the selected group, or around the node
    let mut ${v}from: Option<usize> = if ${v}inside_group {
        ${!selection}.group.and_then(|group| ${!doc}.nodes[group].parent)
    } else {
        ${v}base.and_then(|node| ${!doc}.nodes[node].parent)
    };
    let mut ${v}target: Option<usize> = None;
    while let Some(at) = ${v}from {
        if ${v}target.is_none() && ${!doc}.nodes[at].tag == "g" {
            ${v}target = Some(at);
        }
        ${v}from = if ${v}target.is_none() { ${!doc}.nodes[at].parent } else { None };
    }

    // its shapes: every node with the <g> among its ancestors
    if let Some(group) = ${v}target {
        let mut shapes: Vec<usize> = vec![];
        for (id, node) in ${!doc}.nodes.iter().enumerate() {
            let mut inside = false;
            let mut up = node.parent;
            while let Some(at) = up {
                inside = inside || at == group;
                up = ${!doc}.nodes[at].parent;
            }
            if inside && SHAPE_TAGS.contains(&node.tag.as_str()) && Some(id) != ${v}base {
                shapes.push(id);
            }
        }
        // the clicked node last, when it's one of them
        if let Some(base) = ${v}base {
            let mut up = ${!doc}.nodes[base].parent;
            let mut base_inside = false;
            while let Some(at) = up {
                base_inside = base_inside || at == group;
                up = ${!doc}.nodes[at].parent;
            }
            if base_inside && SHAPE_TAGS.contains(&${!doc}.nodes[base].tag.as_str()) {
                shapes.push(base);
            }
        }
        ${!selection}.ids = shapes;
        ${!selection}.group = Some(group);
    }

EOF
