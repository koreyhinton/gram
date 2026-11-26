#!/bin/bash

# node-xml: one node as XML (the old web app's nd2xml).
#
#   input:   Node  &Node
#   output:  Xml   String (declared here)
#
# The tag, then each attribute in its order with its raw value:
# <rect x="1" y="2"/>. A text node holds its raw text:
# <text x="1" y="2">Receive</text>. The node's own colors are written: selection is only
# drawn, never stored, so a selected node's XML is as it is in the file.

v=$1
# maps
. ${NSMAP}/bind ${v} Node Xml

cat << EOF

    // the node as one element of XML
    let mut ${!xml} = format!("<{}", ${!node}.tag);
    for (name, value) in ${!node}.attrs.iter() {
        ${!xml}.push_str(&format!(" {}=\"{}\"", name, value));
    }
    if ${!node}.tag == "text" {
        ${!xml}.push_str(&format!(">{}</text>", ${!node}.text));
    } else {
        ${!xml}.push_str("/>");
    }

EOF
