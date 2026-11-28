#!/bin/bash

# history-push: record the page before a change, so it can be undone.
#
#   input/output:  History  History, the page's undo history
#   input:         Doc      Doc, the page as it is before the change
#
# Pushes a copy of Doc onto History.undo and clears History.redo (a new
# change means the undone ones can't come back). At most UNDO_LIMIT
# snapshots are kept; the oldest goes first.

v=$1
# maps
. ${NSMAP}/bind ${v} History Doc

cat << EOF

    // the page as it was, newest last; a new change ends redo
    ${!history}.undo.push(${!doc}.clone());
    if ${!history}.undo.len() > UNDO_LIMIT {
        ${!history}.undo.remove(0);
    }
    ${!history}.redo.clear();

EOF
