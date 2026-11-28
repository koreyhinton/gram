#!/bin/bash

# doc-xml: a whole page as SVG text, for a save or a copy (the old web app's
# nds2xml, which the old save and copy buttons wrote out, devbox@df9a465).
#
#   input:   Doc  &Doc
#   output:  Xml  String (declared here)
#
# Written back as the file had it: the head (prolog, comments, <svg ...>),
# each node with the raw text before it, its children inside it (a <g> keeps
# its nesting), then the tail (</svg> and what follows). A node read from the
# file whose tag and attributes haven't changed keeps its start tag as
# written, and one whose text hasn't changed its end tag and text, so an
# untouched file comes out byte for byte. A changed node is written fresh,
# its attributes in order (as node-xml.sh does); a node gram made goes on its
# own line, indented like the sibling before it. A Doc with no head gets a
# plain <svg> with its root attributes.

v=$1
# maps
. ${NSMAP}/bind ${v} Doc Xml

cat << EOF

    // the start tag, as written if unchanged
    let ${v}start = |node: &Node| -> String {
        if let Some(src) = node.src.as_ref()
            && src.tag == node.tag
            && src.attrs == node.attrs
        {
            return src.start.clone();
        }
        let mut tag = format!("<{}", node.tag);
        for (name, value) in node.attrs.iter() {
            tag.push_str(&format!(" {}=\"{}\"", name, value));
        }
        let empty = match node.src.as_ref() {
            Some(src) => src.empty,
            None => node.tag != "text",
        };
        tag.push_str(if empty { "/>" } else { ">" });
        tag
    };
    // the text and end tag of a node that isn't <a/>, as written if unchanged
    let ${v}end = |node: &Node| -> String {
        match node.src.as_ref() {
            Some(src) if src.tag == node.tag && src.text == node.text => src.end.clone(),
            Some(src) if node.tag != "text" => {
                // a renamed container: its own end tag after its last whitespace
                let ws = &src.end[..src.end.rfind("</").unwrap_or(0)];
                format!("{}</{}>", ws, node.tag)
            }
            _ => format!("{}</{}>", node.text, node.tag),
        }
    };
    // whether a node has an end tag (children or text)
    let ${v}open_ended = |node: &Node| match node.src.as_ref() {
        Some(src) => !src.empty,
        None => node.tag == "text",
    };

    // an empty <svg/> that has nodes now opens up to hold them
    let ${v}reopened = ${!doc}.head.ends_with("/>") && !${!doc}.nodes.is_empty();
    let mut ${!xml} = if ${!doc}.head.is_empty() {
        let mut head = "<svg".to_string();
        for (name, value) in ${!doc}.root_attrs.iter() {
            head.push_str(&format!(" {}=\"{}\"", name, value));
        }
        head.push('>');
        head
    } else if ${v}reopened {
        format!("{}>", ${!doc}.head.trim_end_matches("/>"))
    } else {
        ${!doc}.head.clone()
    };
    let ${v}tail = if ${!doc}.head.is_empty() {
        "\n</svg>\n".to_string()
    } else if ${v}reopened {
        format!("\n</svg>{}", ${!doc}.tail)
    } else {
        ${!doc}.tail.clone()
    };

    // the nodes in order, each container closed once its children are out
    let mut ${v}open: Vec<usize> = vec![];
    for (i, node) in ${!doc}.nodes.iter().enumerate() {
        while let Some(&top) = ${v}open.last()
            && Some(top) != node.parent
        {
            ${!xml}.push_str(&${v}end(&${!doc}.nodes[top]));
            ${v}open.pop();
        }
        let lead = match node.src.as_ref() {
            Some(src) => src.lead.clone(),
            // a new node: the whitespace before the sibling before it
            None => ${!doc}.nodes[..i]
                .iter()
                .rev()
                .filter(|sibling| sibling.parent == node.parent)
                .find_map(|sibling| sibling.src.as_ref().map(|src| src.lead.clone()))
                .filter(|lead| !lead.is_empty() && lead.trim().is_empty())
                .unwrap_or_else(|| "\n".to_string()),
        };
        ${!xml}.push_str(&lead);
        ${!xml}.push_str(&${v}start(node));
        if ${v}open_ended(node) {
            ${v}open.push(i);
        }
    }
    while let Some(top) = ${v}open.pop() {
        ${!xml}.push_str(&${v}end(&${!doc}.nodes[top]));
    }
    ${!xml}.push_str(&${v}tail);

EOF
