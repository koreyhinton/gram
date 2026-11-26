#!/bin/bash

# node-apply: put an edited node's XML back onto the node (the old web
# app's xdom2nd).
#
#   input:         Edited  &Node, the node parsed from the editor's XML
#   input/output:  Target  Node, the node in the Doc
#
# The tag is replaced. Each edited attribute replaces the value of the
# attribute with its name, or is added at the end. Attributes missing from
# the edit are kept: an edit never removes one. A text node takes the edited
# text.

v=$1
# maps
. ${NSMAP}/bind ${v} Edited Target

cat << EOF

    // the edited tag and attributes onto the node; none are removed
    ${!target}.tag = ${!edited}.tag.clone();
    if ${!target}.tag == "text" {
        ${!target}.text = ${!edited}.text.clone();
    }
    for (name, value) in ${!edited}.attrs.iter() {
        let existing = ${!target}.attrs.iter().position(|(have, _)| have == name);
        match existing {
            Some(at) => ${!target}.attrs[at].1 = value.clone(),
            None => ${!target}.attrs.push((name.clone(), value.clone())),
        }
    }

EOF
