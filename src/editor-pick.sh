#!/bin/bash

# editor-pick: the editor command, from the environment.
#
#   output:  Editor  String (declared here), a shell command that takes the
#                    file as its last argument
#
# The first of $GRAM_EDITOR, $VISUAL and $EDITOR that is set and not blank,
# else xdg-open. A command may carry arguments ("emacsclient -c").

v=$1
# maps
. ${NSMAP}/bind ${v} Editor

cat << EOF

    // the editor: \$GRAM_EDITOR, then \$VISUAL, then \$EDITOR, else xdg-open
    let ${!editor}: String = ["GRAM_EDITOR", "VISUAL", "EDITOR"]
        .iter()
        .filter_map(|name| std::env::var(name).ok())
        .find(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "xdg-open".to_string());

EOF
