#!/bin/bash

# tree-scan: the folder tree under a root: its .svg files and the folders
# that hold them.
#
#   input:   Root     &std::path::Path, the folder to scan
#   output:  Entries  Vec<TreeEntry> (declared here), in tree order
#
# Tree order lists a folder's subfolders before its files, each sorted by
# name ignoring case, and puts each folder's contents right after it.
# Hidden files and folders (a name starting with '.') are skipped, and so
# are folders with no .svg file anywhere inside. Symlinked folders aren't
# followed, so a link loop can't hang the scan. Folders that can't be read
# are skipped.

v=$1
# maps
. ${NSMAP}/bind ${v} Root Entries

cat << EOF

    // every .svg file under the root, from a walk with an explicit stack
    let mut ${v}files: Vec<std::path::PathBuf> = vec![];
    let mut ${v}to_read: Vec<std::path::PathBuf> = vec![${!root}.to_path_buf()];
    while let Some(dir) = ${v}to_read.pop() {
        let items: Vec<std::fs::DirEntry> = match std::fs::read_dir(&dir) {
            Ok(read) => read.flatten().collect(),
            Err(_) => vec![],
        };
        for item in items {
            let hidden = item.file_name().to_string_lossy().starts_with('.');
            // the entry itself, not what a symlink points at
            let (is_dir, is_link) = match item.file_type() {
                Ok(kind) => (kind.is_dir(), kind.is_symlink()),
                Err(_) => (false, false),
            };
            let path = item.path();
            let is_svg = path
                .extension()
                .is_some_and(|ext| ext.to_string_lossy().eq_ignore_ascii_case("svg"));
            if !hidden && is_dir {
                ${v}to_read.push(path);
            } else if !hidden && is_svg && (!is_link || path.is_file()) {
                ${v}files.push(path);
            }
        }
    }

    // each file, and each folder above it, with its sort key: per path
    // component (is a file, name lowercased, name), so a folder sorts before
    // its contents and folders before files
    let mut ${v}keyed: Vec<(Vec<(bool, String, String)>, TreeEntry)> = vec![];
    let mut ${v}seen_dirs: std::collections::HashSet<std::path::PathBuf> = std::collections::HashSet::new();
    for file in ${v}files.iter() {
        let relative = file.strip_prefix(${!root}).unwrap_or(file);
        let names: Vec<String> = relative
            .components()
            .map(|part| part.as_os_str().to_string_lossy().to_string())
            .collect();
        let mut key: Vec<(bool, String, String)> = vec![];
        let mut path = ${!root}.to_path_buf();
        for (depth, name) in names.iter().enumerate() {
            let is_file = depth + 1 == names.len();
            key.push((is_file, name.to_lowercase(), name.clone()));
            path.push(name);
            if is_file || ${v}seen_dirs.insert(path.clone()) {
                ${v}keyed.push((
                    key.clone(),
                    TreeEntry { path: path.clone(), name: name.clone(), depth, is_dir: !is_file },
                ));
            }
        }
    }
    ${v}keyed.sort_by(|a, b| a.0.cmp(&b.0));
    let ${!entries}: Vec<TreeEntry> = ${v}keyed.into_iter().map(|(_, entry)| entry).collect();

EOF
