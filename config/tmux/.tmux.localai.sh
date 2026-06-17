#!/bin/bash
SESSION="localai"

if tmux has-session -t $SESSION 2>/dev/null; then
    tmux attach -t $SESSION
    exit 0
fi

tmux new-session -d -s $SESSION -n main

# top-left pane: ollama ps watch
tmux send-keys -t $SESSION 'watch -n2 ollama\ ps' C-m

# bottom-left pane: curl/shell
tmux split-window -v -t $SESSION
tmux send-keys -t $SESSION '' C-m

# right pane: gotop
tmux split-window -h -t $SESSION
tmux send-keys -t $SESSION 'gotop -l llmdev' C-m

# apply layout
tmux select-layout -t $SESSION '028b,120x29,0,0{72x29,0,0[72x10,0,0,0,72x18,0,11,1],47x29,73,0,2}'

tmux attach -t $SESSION
