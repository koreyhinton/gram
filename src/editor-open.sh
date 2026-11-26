#!/bin/bash

# editor-open: start the editor on a file, without waiting for it.
#
#   input:   Editor  &str, the editor command (from editor-pick)
#   input:   Path    &std::path::Path, the file to edit
#   output:  Child   Option<std::process::Child> (declared here), the running
#                    editor; poll it with editor-poll
#   output:  Error   Option<String> (declared here), why it couldn't start
#
# Runs the command through sh with the file as its last argument, so a
# command with arguments works and a path with spaces stays one argument.
# Native only: on wasm there's no editor to start.

v=$1
# maps
. ${NSMAP}/bind ${v} Editor Path Child Error

cat << EOF

    // the editor runs on its own; editor-poll checks on it each frame
    let mut ${!child}: Option<std::process::Child> = None;
    let mut ${!error}: Option<String> = None;
    #[cfg(not(target_arch = "wasm32"))]
    {
        let started = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("{} \"\$1\"", ${!editor}))
            .arg("sh")
            .arg(${!path})
            .spawn();
        match started {
            Ok(running) => ${!child} = Some(running),
            Err(err) => ${!error} = Some(format!("can't start {}: {}", ${!editor}, err)),
        }
    }
    #[cfg(target_arch = "wasm32")]
    {
        ${!error} = Some("no external editor on the web".to_string());
    }

EOF
