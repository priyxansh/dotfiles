#!/bin/bash

# Script to automatically pause hypridle when a window is fullscreen
# Resumes hypridle when no windows are fullscreen, unless presentation mode is on

# State file to track inhibition
STATE_FILE="/tmp/hypr_idle_inhibited.state"
LOCK_FILE="/tmp/hypr_presentation_mode.lock"
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}

# Function to check if any window is in fullscreen on ANY CURRENTLY VISIBLE workspace (including special/scratchpads)
is_fullscreen_visible() {
    # 1. Get IDs for both active and special workspaces for all monitors
    local active_workspaces
    active_workspaces=$(hyprctl monitors -j | python3 -c "
import sys, json
ids = []
for m in json.load(sys.stdin):
    ids.append(str(m['activeWorkspace']['id']))
    if m.get('specialWorkspace', {}).get('id', 0) != 0:
        ids.append(str(m['specialWorkspace']['id']))
print(' '.join(ids))
" 2>/dev/null)
    
    # 2. Check if any client on those workspaces is fullscreen
    hyprctl clients -j | python3 -c "
import sys, json
active_ws = '$active_workspaces'.split()
clients = json.load(sys.stdin)
fullscreen_active = any(
    str(c.get('workspace', {}).get('id')) in active_ws 
    and c.get('fullscreen', False) 
    for c in clients
)
print(fullscreen_active)
" 2>/dev/null | grep -q "True"
}

# Function to update inhibition state
update_inhibition() {
    local currently_fs
    if is_fullscreen_visible; then
        currently_fs=1
    else
        currently_fs=0
    fi

    local prev_fs=0
    [ -f "$STATE_FILE" ] && prev_fs=$(cat "$STATE_FILE")

    if [ "$currently_fs" -eq 1 ] && [ "$prev_fs" -eq 0 ]; then
        # Transition: Tiled -> Fullscreen
        pkill -STOP hypridle 2>/dev/null
        echo 1 > "$STATE_FILE"
        notify-send "Idle Inhibited" "Fullscreen active on visible workspace." \
            -i "media-playback-pause" -t 2000 -a "Hyprland"
    elif [ "$currently_fs" -eq 0 ] && [ "$prev_fs" -eq 1 ]; then
        # Transition: Fullscreen -> Tiled
        if [ ! -f "$LOCK_FILE" ]; then
            pkill -CONT hypridle 2>/dev/null
            notify-send "Idle Resumed" "No fullscreen windows visible." \
                -i "media-playback-start" -t 2000 -a "Hyprland"
        fi
        echo 0 > "$STATE_FILE"
    fi
}

# Function to handle relevant events
handle_event() {
    case $1 in
        fullscreen\>\>*|workspace\>\>*|focusedmon\>\>*|activespecial\>\>*|toggle\>\>*)
            # Check state on any of these changes
            update_inhibition
            ;;
    esac
}

# Initial check
rm -f "$STATE_FILE"
update_inhibition

# Locate the Hyprland event socket
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if [ ! -S "$SOCKET_PATH" ]; then
    SOCKET_PATH="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
fi

if [ ! -S "$SOCKET_PATH" ]; then
    echo "Error: Could not find Hyprland socket2"
    exit 1
fi

# Listen to events and handle them — reconnect loop survives config reloads
while true; do
    socat -U - "UNIX-CONNECT:$SOCKET_PATH" 2>/dev/null | while IFS= read -r line; do
        line="${line%$'\r'}"
        handle_event "$line"
    done
    sleep 1  # brief pause before reconnecting
done
