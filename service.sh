#!/system/bin/sh
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

MODDIR="${0%/*}"
CONF_FILE="$MODDIR/thermal.conf"

if [ ! -f "$CONF_FILE" ]; then
    echo "[ERROR] Thermal config file not found at $CONF_FILE. Exiting." >&2
    exit 1
fi

GLOBAL_TEMP_PATH=""
POLL_INTERVAL=2
CDEV_SECTIONS=""
CURRENT_SECTION=""

while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | sed 's/^[ \t]*//;s/[ \t]*$//')
    
    case "$line" in
        \#*|\;*|'') continue ;;
        \[*\])
            CURRENT_SECTION=$(echo "$line" | sed 's/^\[\(.*\)\]$/\1/' | tr -d ' \r\t')
            case "$CURRENT_SECTION" in
                global|GLOBAL) CURRENT_SECTION="global" ;;
                *) CDEV_SECTIONS="$CDEV_SECTIONS $CURRENT_SECTION" ;;
            esac
            continue
            ;;
    esac

    case "$line" in
        *=*)
            key="${line%%=*}"
            val="${line#*=}"
            key=$(echo "$key" | tr -d ' \r\t')
            val=$(echo "$val" | tr -d ' \r\t')

            if [ "$CURRENT_SECTION" = "global" ]; then
                case "$key" in
                    temp_path|TEMP_PATH) GLOBAL_TEMP_PATH="$val" ;;
                    poll_interval|POLL_INTERVAL) POLL_INTERVAL="$val" ;;
                esac
            elif [ -n "$CURRENT_SECTION" ]; then
                case "$key" in
                    path|PATH)
                        eval "cfg_path_${CURRENT_SECTION}=\"$val\""
                        ;;
                    *)
                        eval "cfg_t_${CURRENT_SECTION}_${key}=\"$val\""
                        eval "cfg_keys_${CURRENT_SECTION}=\"\$cfg_keys_${CURRENT_SECTION} $key\""
                        ;;
                esac
            fi
            ;;
    esac
done < "$CONF_FILE"

if [ -z "$GLOBAL_TEMP_PATH" ] || [ ! -f "$GLOBAL_TEMP_PATH" ]; then
    echo "[ERROR] Invalid or missing temp_path in [global]." >&2
    exit 1
fi

active_sections=""
for sec in $CDEV_SECTIONS; do
    eval "path=\$cfg_path_${sec}"
    if [ -z "$path" ] || [ ! -f "$path" ]; then
        echo "[WARN] CDEV section [$sec] path missing or invalid, skipping."
        continue
    fi
    
    eval "keys=\$cfg_keys_${sec}"
    sorted_keys=$(echo "$keys" | tr ' ' '\n' | grep -v '^$' | sort -rn)
    eval "sorted_keys_${sec}=\"$sorted_keys\""
    
    active_sections="$active_sections $sec"
    eval "last_state_${sec}=\"\""
done

if [ -z "$active_sections" ]; then
    echo "[ERROR] No valid cooling device sections configured." >&2
    exit 1
fi

echo "[INFO] Thermal daemon started. Monitoring: $GLOBAL_TEMP_PATH"
echo "[INFO] Poll interval: ${POLL_INTERVAL}s"

while true; do
    if read -r temp < "$GLOBAL_TEMP_PATH"; then
        for sec in $active_sections; do
            eval "path=\$cfg_path_${sec}"
            eval "sorted_keys=\$sorted_keys_${sec}"
            eval "last_state=\$last_state_${sec}"

            target_state=""
            for t in $sorted_keys; do
                eval "val_state=\$cfg_t_${sec}_$t"
                if [ "$temp" -ge "$t" ] 2>/dev/null; then
                    target_state="$val_state"
                    break
                fi
            done

            [ -z "$target_state" ] && target_state=0

            if [ "$target_state" != "$last_state" ]; then
                echo "$target_state" > "$path"
                echo "[$(date '+%H:%M:%S')] [$sec] Temp: ${temp}mC -> State changed: ${last_state:-None} => $target_state"
                eval "last_state_${sec}=\"$target_state\""
            fi
        done
    else
        echo "[WARN] Failed to read temperature from $GLOBAL_TEMP_PATH" >&2
    fi

    sleep "$POLL_INTERVAL"
done