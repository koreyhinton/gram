#!/bin/bash

# svg-load: parse svg text into a Doc.
#
#   input:   Text   &str, the file's contents
#   output:  Doc    Doc (declared here)
#   output:  Error  Option<String> (declared here), why the parse failed
#
# Elements are read flat, in document order, as the old web app's loadSvg
# did (getElementsByTagName('*')), each with the index of the element that
# encloses it (Node.parent). Attribute values and text stay raw (still
# escaped) so a save can write them back unchanged. Each node also keeps its
# raw source (Node.src: the text before it, its start and end tags as
# written), and the Doc the raw text before and after its elements (head,
# tail), so doc-xml.sh writes an untouched file back byte for byte. Click
# boxes aren't set here: run mouse-rects next.

v=$1
# maps
. ${NSMAP}/bind ${v} Text Doc Error

cat << EOF

    // read the svg's elements in document order
    let mut ${!doc} = Doc::default();
    let mut ${!error}: Option<String> = None;
    let mut ${v}reader = quick_xml::Reader::from_str(&${!text});
    ${v}reader.config_mut().trim_text(false);
    let mut ${v}reading = true;
    let mut ${v}seen_root = false;
    // the node whose text is being read, until its end tag
    let mut ${v}in_text: Option<usize> = None;
    // the open elements, innermost last: the root <svg> is None, the rest are
    // node indexes
    let mut ${v}open: Vec<Option<usize>> = vec![];
    // the raw text read since the last start or end tag (whitespace,
    // comments, the prolog), and where the last event ended
    let mut ${v}pending = String::new();
    let mut ${v}read_to = 0usize;
    while ${v}reading {
        // (the element, whether it has children or text)
        let mut ${v}element: Option<(quick_xml::events::BytesStart, bool)> = None;
        let ${v}event = ${v}reader.read_event();
        // this event's text exactly as the file has it
        let ${v}to = (${v}reader.buffer_position() as usize).min(${!text}.len());
        let ${v}raw = ${!text}.get(${v}read_to..${v}to).unwrap_or("").to_string();
        ${v}read_to = ${v}to;
        let ${v}is_end = matches!(${v}event, Ok(quick_xml::events::Event::End(_)));
        match ${v}event {
            Ok(quick_xml::events::Event::Start(start)) => {
                ${v}element = Some((start.into_owned(), true));
            }
            Ok(quick_xml::events::Event::Empty(start)) => {
                ${v}element = Some((start.into_owned(), false));
            }
            Ok(quick_xml::events::Event::Text(text)) => {
                if let Some(i) = ${v}in_text {
                    ${!doc}.nodes[i].text.push_str(&String::from_utf8_lossy(&text));
                }
            }
            // an entity such as &amp; in text, kept as written
            Ok(quick_xml::events::Event::GeneralRef(entity)) => {
                if let Some(i) = ${v}in_text {
                    ${!doc}.nodes[i].text.push('&');
                    ${!doc}.nodes[i].text.push_str(&String::from_utf8_lossy(&entity));
                    ${!doc}.nodes[i].text.push(';');
                }
            }
            Ok(quick_xml::events::Event::End(_)) => {
                ${v}in_text = None;
                let end = std::mem::take(&mut ${v}pending) + &${v}raw;
                match ${v}open.pop() {
                    Some(Some(i)) => {
                        if let Some(src) = ${!doc}.nodes[i].src.as_mut() {
                            src.end = end;
                        }
                    }
                    // the root's end tag: the rest of the file follows it
                    _ => {
                        ${!doc}.tail = end;
                    }
                }
            }
            Ok(quick_xml::events::Event::Eof) => {
                ${v}reading = false;
                ${!doc}.tail.push_str(&std::mem::take(&mut ${v}pending));
            }
            Err(err) => {
                ${!error} = Some(format!(
                    "invalid svg at byte {}: {}",
                    ${v}reader.error_position(),
                    err
                ));
                ${v}reading = false;
            }
            Ok(_) => {}
        }
        // text, comments and the like wait for the next tag; so do the
        // text and entities kept above
        if ${v}element.is_none() && !${v}is_end {
            ${v}pending.push_str(&${v}raw);
        }

        if let Some((start, has_children)) = ${v}element {
            let tag = String::from_utf8_lossy(start.name().as_ref()).to_string();
            let mut attrs: Vec<(String, String)> = vec![];
            for attr in start.attributes() {
                match attr {
                    Ok(attr) => attrs.push((
                        String::from_utf8_lossy(attr.key.as_ref()).to_string(),
                        String::from_utf8_lossy(&attr.value).to_string(),
                    )),
                    Err(err) => {
                        ${!error} = Some(format!("invalid attribute in <{}>: {}", tag, err));
                        ${v}reading = false;
                    }
                }
            }
            let lead = std::mem::take(&mut ${v}pending);
            if tag == "svg" && !${v}seen_root {
                ${!doc}.root_attrs = attrs;
                ${!doc}.head = lead + &${v}raw;
                ${v}seen_root = true;
                if has_children {
                    ${v}open.push(None);
                }
            } else {
                let src = NodeSource {
                    lead,
                    start: ${v}raw.clone(),
                    tag: tag.clone(),
                    attrs: attrs.clone(),
                    text: String::new(),
                    empty: !has_children,
                    end: String::new(),
                };
                ${!doc}.nodes.push(Node {
                    tag,
                    attrs,
                    text: String::new(),
                    bounds: Rect::default(),
                    parent: ${v}open.last().copied().flatten(),
                    src: Some(src),
                });
                if has_children {
                    ${v}in_text = Some(${!doc}.nodes.len() - 1);
                    ${v}open.push(Some(${!doc}.nodes.len() - 1));
                }
            }
        }
    }
    // each node's text as it was read, to tell an edited text from the file's
    for node in ${!doc}.nodes.iter_mut() {
        if let Some(src) = node.src.as_mut() {
            src.text = node.text.clone();
        }
    }
    if ${!error}.is_none() && !${v}seen_root {
        ${!error} = Some("no <svg> root element".to_string());
    }

EOF
