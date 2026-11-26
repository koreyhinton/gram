#!/bin/bash

# workspace-args: where gram opens, from its command-line path.
#
#   input:   Arg    &str, the path gram was given
#   output:  Root   std::path::PathBuf (declared here), the folder whose tree
#                   is shown
#   output:  Open   Option<std::path::PathBuf> (declared here), the page to
#                   open first: the file, when gram was given an .svg file
#   output:  Error  Option<String> (declared here), why the path can't be
#                   opened
#
# A folder opens with nothing selected. An .svg file opens its folder with
# that file selected. Paths are made absolute, so the tree's paths and the
# file's path compare equal.

v=$1
# maps
. ${NSMAP}/bind ${v} Arg Root Open Error

cat << EOF

    // a folder opens as it is; an .svg file opens its folder, with it selected
    let mut ${!root} = std::path::PathBuf::new();
    let mut ${!open}: Option<std::path::PathBuf> = None;
    let mut ${!error}: Option<String> = None;
    match std::fs::canonicalize(${!arg}) {
        Ok(path) => {
            let is_svg = path
                .extension()
                .is_some_and(|ext| ext.to_string_lossy().eq_ignore_ascii_case("svg"));
            if path.is_dir() {
                ${!root} = path;
            } else if path.is_file() && is_svg {
                ${!root} = path.parent().map(|dir| dir.to_path_buf()).unwrap_or_default();
                ${!open} = Some(path);
            } else {
                ${!error} = Some("not a folder or an .svg file".to_string());
            }
        }
        Err(err) => ${!error} = Some(err.to_string()),
    }

EOF
