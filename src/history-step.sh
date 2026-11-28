#!/bin/bash

# history-step: one undo or one redo.
#
#   input/output:  History  History, the page's undo history
#   input/output:  Doc      Doc, the page
#   input:         Saved    Doc, the page as last loaded or saved
#   input:         Back     bool, true to undo, false to redo
#   input/output:  Dirty    bool, the page's unsaved-changes flag
#   output:        Stepped  bool (declared here), whether there was anything
#                           to undo or redo
#
# Undo takes the newest snapshot from History.undo as the page and keeps the
# page it replaces on History.redo; redo is the same the other way. When it
# stepped, Dirty becomes whether the page now differs from Saved, so undoing
# back to the saved page clears it. With nothing to step to, nothing changes.

v=$1
# maps
. ${NSMAP}/bind ${v} History Doc Saved Back Dirty Stepped

cat << EOF

    // take a snapshot from one stack, and keep the page it replaces on the other
    let ${!stepped} = {
        let ${v}history = &mut ${!history};
        let (${v}from, ${v}to) = if ${!back} {
            (&mut ${v}history.undo, &mut ${v}history.redo)
        } else {
            (&mut ${v}history.redo, &mut ${v}history.undo)
        };
        match ${v}from.pop() {
            Some(snapshot) => {
                ${v}to.push(std::mem::replace(&mut ${!doc}, snapshot));
                true
            }
            None => false,
        }
    };
    if ${!stepped} {
        ${!dirty} = ${!doc} != ${!saved};
    }

EOF
