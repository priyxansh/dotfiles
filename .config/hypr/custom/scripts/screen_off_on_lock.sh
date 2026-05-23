#!/bin/bash
# Turns the screen off 10 seconds after screen lock.
# Re-arms the timer every time the display is woken while still locked.
# Restores display on unlock (unless presentation mode is active).
# Detects lock/unlock via the hyprlock workspace (ID 2147483644).

XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
LOCK_STATE_FILE="/tmp/hypr_screen_locked.state"
DPMS_MANAGER_PID_FILE="/tmp/hypr_dpms_manager.pid"
PRESENTATION_LOCK="/tmp/hypr_presentation_mode.lock"

# Returns "yes" if any monitor has DPMS on, "no" if all are off
is_display_on() {
    hyprctl monitors -j 2>/dev/null | python3 -c "
import sys, json
try:
    monitors = json.load(sys.stdin)
    print('yes' if any(m.get('dpmsStatus', True) for m in monitors) else 'no')
except:
    print('yes')
" 2>/dev/null
}

# Loops while locked: turns display off after 10s, then waits for it to wake
# and repeats. Exits when the lock state file is removed.
dpms_manager() {
    while [ -f "$LOCK_STATE_FILE" ]; do
        # 10s countdown then turn off display
        sleep 10
        [ -f "$LOCK_STATE_FILE" ] || break
        hyprctl dispatch dpms off

        # Poll every 2s until display wakes (or we unlock)
        while [ -f "$LOCK_STATE_FILE" ]; do
            sleep 2
            if [ "$(is_display_on)" = "yes" ]; then
                break  # Display woke — restart the 10s countdown
            fi
        done
    done
}

stop_dpms_manager() {
    if [ -f "$DPMS_MANAGER_PID_FILE" ]; then
        kill "$(cat "$DPMS_MANAGER_PID_FILE")" 2>/dev/null
        rm -f "$DPMS_MANAGER_PID_FILE"
    fi
    rm -f "$LOCK_STATE_FILE"
}

handle_event() {
    local event="$1"
    echo "[$(date +%T)] event: $event" >> /tmp/screen_off_on_lock.log
    case "$event" in
        createworkspace\>\>2147483644*)
            # Hyprlock workspace created — screen is now locked
            stop_dpms_manager
            touch "$LOCK_STATE_FILE"
            dpms_manager &
            echo $! > "$DPMS_MANAGER_PID_FILE"
            echo "[$(date +%T)] Lock detected, DPMS manager started" >> /tmp/screen_off_on_lock.log
            ;;
        destroyworkspace\>\>2147483644*)
            # Hyprlock workspace destroyed — screen is now unlocked
            stop_dpms_manager
            # Don't restore dpms if presentation mode has it intentionally off
            if [ ! -f "$PRESENTATION_LOCK" ]; then
                hyprctl dispatch dpms on
            fi
            echo "[$(date +%T)] Unlock detected, dpms restored" >> /tmp/screen_off_on_lock.log
            ;;
    esac
}

# Locate the Hyprland event socket
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
if [ ! -S "$SOCKET_PATH" ]; then
    SOCKET_PATH="/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
fi

if [ ! -S "$SOCKET_PATH" ]; then
    echo "Error: Could not find Hyprland socket2"
    exit 1
fi

# Reconnect loop — socat dies on Hyprland config reloads, so we restart it
while true; do
    socat -U - "UNIX-CONNECT:$SOCKET_PATH" 2>/dev/null | while IFS= read -r line; do
        line="${line%$'\r'}"  # Strip trailing carriage return
        handle_event "$line"
    done
    sleep 1  # brief pause before reconnecting
done
