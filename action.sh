#!/system/bin/sh

idx=0
while true; do
    zone="/sys/class/thermal/thermal_zone${idx}"

    if [ ! -d "$zone" ]; then
        break
    fi

    name=""
    if [ -f "$zone/type" ]; then
        name="$(cat "$zone/type" 2>/dev/null)" || name=""
    fi
    if [ -z "$name" ]; then
        name="unknown"
    fi

    if [ ! -f "$zone/temp" ]; then
        idx=$((idx + 1))
        continue
    fi

    raw="$(cat "$zone/temp" 2>/dev/null)" || { idx=$((idx + 1)); continue; }

    case "$raw" in
        ''|*[!0-9-]*) idx=$((idx + 1)); continue ;;
    esac

    temp="$(printf '%s\n' "$raw" | awk '{printf "%.1f", $1/1000}')"

    printf "%s: %s = %s C\n" "$idx" "$name" "$temp"

    idx=$((idx + 1))
done