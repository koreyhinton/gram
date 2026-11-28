#!/bin/bash

# node-edit-check: what a node edit's file says this frame.
#
#   input:         Path      &Path, the node file handed to the editor
#   input:         Written   &str, the XML gram wrote there
#   input:         Exited    bool, whether the editor exited this frame
#                            (editor-poll.sh)
#   input:         Elapsed   f64, seconds since the editor started
#   input:         Saved     bool, whether the file changed on disk this
#                            frame (file-watch.sh)
#   input/output:  Watching  bool, whether the editor handed the file off
#   output:        Outcome   NodeEditOutcome (declared here)
#
# When the editor exits, the file is read: changed is Apply(text). Unchanged
# is Unchanged, unless the editor exited within HANDOFF_SECS of starting:
# then it handed the file to another program (xdg-open opening a text editor,
# emacsclient -n), so Watching is set and the edit stays open. While
# watching, the first save that changes the file is Apply(text); a save that
# leaves it as written waits on. A file that can't be read is Failed.
# Otherwise (the editor still open, or no save yet) Wait.

v=$1
# maps
. ${NSMAP}/bind ${v} Path Written Exited Elapsed Saved Watching Outcome

cat << EOF

    // read the file when the editor exits, or, once it handed the file off,
    // when the file is saved
    let ${v}look = (${!exited} && !${!watching}) || (${!watching} && ${!saved});
    let mut ${!outcome} = NodeEditOutcome::Wait;
    if ${v}look {
        match std::fs::read_to_string(${!path}) {
            Ok(text) if text != ${!written} => ${!outcome} = NodeEditOutcome::Apply(text),
            // unchanged, and the editor took its time: it's finished
            Ok(_) if !${!watching} && ${!elapsed} >= HANDOFF_SECS => ${!outcome} = NodeEditOutcome::Unchanged,
            // unchanged, but the editor returned at once: wait for a save
            Ok(_) => ${!watching} = true,
            Err(err) => ${!outcome} = NodeEditOutcome::Failed(err.to_string()),
        }
    }

EOF
