#!/bin/bash
# brightness_control.sh [up|down]
# Controls brightness of the currently focused monitor.
# After changing hardware brightness, notifies quickshell so the OSD shows.

ACTION=$1  # "up" or "down"
STEP=5     # percent per step

# ── Focused monitor ──────────────────────────────────────────────────────────
FOCUSED=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import sys, json
for m in json.load(sys.stdin):
    if m.get('focused'):
        print(m['name'])
        break
" 2>/dev/null)

# ── Notify quickshell OSD with the current brightness (0–1 fraction) ─────────
notify_osd() {
    local fraction="$1"
    qs -c ii ipc call brightnessSet notify "$fraction" 2>/dev/null &
}

# ── Laptop backlight ─────────────────────────────────────────────────────────
laptop_brightness() {
    if [ "$ACTION" = "up" ]; then
        brightnessctl --class backlight s "${STEP}%+" --quiet
    else
        brightnessctl --class backlight s "${STEP}%-" --quiet
    fi
    # Read actual new value and notify OSD
    local cur max
    cur=$(brightnessctl --class backlight g 2>/dev/null)
    max=$(brightnessctl --class backlight m 2>/dev/null)
    if [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ]; then
        local fraction
        fraction=$(python3 -c "print(round($cur / $max, 4))")
        notify_osd "$fraction"
    fi
}

# ── DDC (external monitor) ───────────────────────────────────────────────────
# Cache the I2C bus number per monitor so repeated keypresses are fast.
CACHE_DIR="/tmp/hypr_brightness_cache"
mkdir -p "$CACHE_DIR"

ddc_bus_for() {
    local mon="$1"
    local cache="$CACHE_DIR/${mon//\//_}.bus"
    if [ -f "$cache" ]; then
        cat "$cache"
        return
    fi
    ddcutil detect --brief 2>/dev/null | python3 -c "
import sys, re
target = '$mon'
text = sys.stdin.read()
for block in re.split(r'\n\n+', text.strip()):
    if not block.strip().startswith('Display '):
        continue
    m_con = re.search(r'DRM connector:\s+\S+?-(.+)', block)
    m_bus = re.search(r'I2C bus:\s+/dev/i2c-(\d+)', block)
    if m_con and m_bus and m_con.group(1).strip() == target:
        print(m_bus.group(1))
        break
" 2>/dev/null | tee "$cache"
}

ddc_brightness() {
    local bus="$1"
    local info current max new_val
    info=$(ddcutil -b "$bus" getvcp 10 --brief 2>/dev/null)
    current=$(echo "$info" | awk '{print $4}')
    max=$(echo "$info"     | awk '{print $5}')

    [[ -z "$current" || -z "$max" || "$max" -le 0 ]] 2>/dev/null && return 1

    if [ "$ACTION" = "up" ]; then
        new_val=$(( current + STEP > max ? max : current + STEP ))
    else
        new_val=$(( current - STEP < 1  ? 1   : current - STEP ))
    fi
    ddcutil -b "$bus" setvcp 10 "$new_val" 2>/dev/null

    # Notify OSD with the new fraction
    local fraction
    fraction=$(python3 -c "print(round($new_val / $max, 4))")
    notify_osd "$fraction"
}

# ── Main ─────────────────────────────────────────────────────────────────────
if [ -z "$FOCUSED" ] || [ "$FOCUSED" = "eDP-1" ]; then
    laptop_brightness
else
    BUS=$(ddc_bus_for "$FOCUSED")
    if [ -n "$BUS" ] && ddc_brightness "$BUS"; then
        exit 0
    fi
    # DDC unavailable — fall back to laptop backlight
    laptop_brightness
fi
