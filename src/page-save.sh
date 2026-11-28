#!/bin/bash

# page-save: write a page's SVG to its file, atomically (the old web app's
# download button, devbox@df9a465, which gram makes a save over the file).
#
#   input:   Path   &std::path::Path, the page's file
#   input:   Xml    &str, the page as doc-xml.sh writes it
#   output:  Error  Option<String> (declared here), why the save failed
#
# Writes <file>.tmp next to the file, then renames it over the file, so a
# crash or a full disk never leaves the file half written. The text is
# written as it is: the old button put it in a data: URI with encodeURI,
# which cut the file at the first '#' (a hex color), so files were lost.
# Native only: on the web nothing is written and Error says so.

v=$1
# maps
. ${NSMAP}/bind ${v} Path Xml Error

cat << EOF

    // <file>.tmp, then rename it over the file
    #[cfg(not(target_arch = "wasm32"))]
    let ${!error}: Option<String> = {
        let mut tmp = ${!path}.as_os_str().to_owned();
        tmp.push(".tmp");
        let tmp = std::path::PathBuf::from(tmp);
        match std::fs::write(&tmp, ${!xml}).and_then(|_| std::fs::rename(&tmp, ${!path})) {
            Ok(()) => None,
            Err(err) => {
                let _ = std::fs::remove_file(&tmp);
                Some(format!("couldn't save {}: {}", ${!path}.display(), err))
            }
        }
    };
    #[cfg(target_arch = "wasm32")]
    let ${!error}: Option<String> = Some("saving needs the desktop app".to_string());

EOF
