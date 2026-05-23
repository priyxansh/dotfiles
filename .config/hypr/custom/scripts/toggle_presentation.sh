#!/bin/bash
# Toggle "presentation mode":
#   ON  → stop hypridle, turn display off (system stays awake)
#   OFF → turn display back on, restart hypridle

LOCK_FILE="/tmp/hypr_presentation_mode.lock"

if [ -f "$LOCK_FILE" ]; then
    # --- Exit presentation mode ---
    rm -f "$LOCK_FILE"
    hyprctl dispatch dpms on
    hypridle &
    notify-send "Presentation mode OFF" "Display on, idle service resumed." \
        -i "display" -t 3000 -a "Hyprland"
else
    # --- Enter presentation mode ---
    touch "$LOCK_FILE"
    pkill hypridle
    sleep 1 && hyprctl dispatch dpms off
    notify-send "Presentation mode ON" "Display off, system will stay awake." \
        -i "display" -t 3000 -a "Hyprland"
fi
