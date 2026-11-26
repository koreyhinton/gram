#!/bin/bash

# svg-load: parse svg text into a Doc.
#
#   input:   Text   &str, the file's contents
#   output:  Doc    Doc (declared here)
#   output:  Error  Option<String> (declared here), why the parse failed
#
# Elements are read flat, in document order, as the old web app's loadSvg
# did (getElementsByTagName('*')). Attribute values and text stay raw (still
# escaped) so a save can write them back unchanged.

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
    while ${v}reading {
        // (the element, whether it has children or text)
        let mut ${v}element: Option<(quick_xml::events::BytesStart, bool)> = None;
        match ${v}reader.read_event() {
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
            }
            Ok(quick_xml::events::Event::Eof) => {
                ${v}reading = false;
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
            if tag == "svg" && !${v}seen_root {
                ${!doc}.root_attrs = attrs;
                ${v}seen_root = true;
            } else {
                ${!doc}.nodes.push(Node {
                    tag,
                    attrs,
                    text: String::new(),
                    bounds: Rect::default(),
                });
                if has_children {
                    ${v}in_text = Some(${!doc}.nodes.len() - 1);
                }
            }
        }
    }
    if ${!error}.is_none() && !${v}seen_root {
        ${!error} = Some("no <svg> root element".to_string());
    }

    // each node's click box, by the old web app's rules (setMouseRects and
    // StartEndFrame.FromText). A missing or unreadable number counts as 0.
    for ${v}node in ${!doc}.nodes.iter_mut() {
        let (mut x, mut y, mut w, mut h, mut stroke_w) = (0.0f32, 0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let (mut cx, mut cy, mut r) = (0.0f32, 0.0f32, 0.0f32);
        let (mut x1, mut y1, mut x2, mut y2) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        let mut points: Vec<f32> = vec![];
        for (name, value) in ${v}node.attrs.iter() {
            // each number as the old web app read it (JS parseFloat): the
            // longest number at the start, after any whitespace, so "10px"
            // is 10 and "1.5e1" is 15; no number at the start is 0. points
            // holds several, split on commas and spaces.
            let texts: Vec<&str> = if name == "points" {
                value
                    .split(|c: char| c == ',' || c.is_whitespace())
                    .filter(|part| !part.is_empty())
                    .collect()
            } else {
                vec![value.as_str()]
            };
            let mut nums: Vec<f32> = Vec::with_capacity(texts.len());
            for text in texts {
                let text = text.trim_start();
                let bytes = text.as_bytes();
                let mut end = 0usize;
                let mut number_end = 0usize;
                let mut has_digits = false;
                if end < bytes.len() && (bytes[end] == b'+' || bytes[end] == b'-') {
                    end += 1;
                }
                while end < bytes.len() && bytes[end].is_ascii_digit() {
                    end += 1;
                    has_digits = true;
                    number_end = end;
                }
                if end < bytes.len() && bytes[end] == b'.' {
                    end += 1;
                    while end < bytes.len() && bytes[end].is_ascii_digit() {
                        end += 1;
                        has_digits = true;
                        number_end = end;
                    }
                }
                // an exponent only counts with digits after it ("1e" is 1)
                if has_digits && end < bytes.len() && (bytes[end] == b'e' || bytes[end] == b'E') {
                    let mut exp_end = end + 1;
                    if exp_end < bytes.len() && (bytes[exp_end] == b'+' || bytes[exp_end] == b'-') {
                        exp_end += 1;
                    }
                    while exp_end < bytes.len() && bytes[exp_end].is_ascii_digit() {
                        exp_end += 1;
                        number_end = exp_end;
                    }
                }
                nums.push(text[..number_end].parse::<f32>().unwrap_or(0.0));
            }
            let num = nums.first().copied().unwrap_or(0.0);
            match name.as_str() {
                "x" => x = num,
                "y" => y = num,
                "width" => w = num,
                "height" => h = num,
                "stroke-width" => stroke_w = num,
                "cx" => cx = num,
                "cy" => cy = num,
                "r" => r = num,
                "x1" => x1 = num,
                "y1" => y1 = num,
                "x2" => x2 = num,
                "y2" => y2 = num,
                "points" => points = nums,
                _ => {}
            }
        }
        let (mut min_x, mut min_y, mut max_x, mut max_y) = (0.0f32, 0.0f32, 0.0f32, 0.0f32);
        match ${v}node.tag.as_str() {
            "circle" => {
                min_x = cx - r - stroke_w;
                max_x = cx + r + stroke_w;
                min_y = cy - r - stroke_w;
                max_y = cy + r + stroke_w;
            }
            "polyline" => {
                // even entries are x, odd are y; no stroke padding
                let xs: Vec<f32> = points.iter().step_by(2).copied().collect();
                let ys: Vec<f32> = points.iter().skip(1).step_by(2).copied().collect();
                if !xs.is_empty() && !ys.is_empty() {
                    min_x = xs.iter().copied().fold(f32::MAX, f32::min);
                    max_x = xs.iter().copied().fold(f32::MIN, f32::max);
                    min_y = ys.iter().copied().fold(f32::MAX, f32::min);
                    max_y = ys.iter().copied().fold(f32::MIN, f32::max);
                }
            }
            "rect" => {
                min_x = x - stroke_w;
                max_x = x + w + stroke_w;
                min_y = y - stroke_w;
                max_y = y + h + stroke_w;
            }
            "line" => {
                min_x = x1.min(x2) - 1.0;
                max_x = x1.max(x2) + 1.0;
                min_y = y1.min(y2) - 1.0;
                max_y = y1.max(y2) + 1.0;
            }
            "text" => {
                // the old per-character widths (in px at 16px), over the raw
                // text as the browser's innerHTML gave it; x and y were read
                // with parseInt, so they're truncated
                let mut width = 0.0f32;
                for ch in ${v}node.text.chars() {
                    width += match ch {
                        'H' | 'W' => 12.0,
                        '?' | 'A'..='B' | 'M'..='O' | 'R' | 'T' | 'V' => 11.0,
                        'C'..='E' | 'G' | 'I' | 'P'..='Q' | 'U' | 'Y'..='Z' => 10.0,
                        'F' | 'J'..='L' | 'S' | 'X' | 'w' => 9.0,
                        'a'..='h' | 'k' | 'm'..='s' | 'u'..='v' | 'x'..='z' => 8.0,
                        'i'..='j' | 'l' | 't' => 7.0,
                        _ => 6.5,
                    };
                }
                min_x = x.trunc() - 3.0;
                min_y = y.trunc() - 17.0;
                max_x = x.trunc() + width;
                max_y = y.trunc() + 4.0;
            }
            _ => {}
        }
        ${v}node.bounds = Rect::new(min_x, min_y, max_x - min_x, max_y - min_y);
    }

EOF
