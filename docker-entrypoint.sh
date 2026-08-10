#!/bin/bash

# Start one isolated ArduPilot SITL instance or same-type swarm.

set -e

SITL_INSTANCE=${SITL_INSTANCE:-1}
SITL_VEHICLE=${SITL_VEHICLE:-ArduPlane}
SITL_FRAME=${SITL_FRAME:-plane}
SWARM_MODE=${SWARM_MODE:-false}
SWARM_COUNT=${SWARM_COUNT:-}
SITL_LOCATION=${SITL_LOCATION:-MAVPROXY_USGS1M}
OFFSET_LINE=${OFFSET_LINE:-90,10}
SITL_WIPE=${SITL_WIPE:-false}
SITL_SPEEDUP=${SITL_SPEEDUP:-1}
SITL_PORT_BASE=${SITL_PORT_BASE:-5760}
SITL_INSTANCE_OFFSET=${SITL_INSTANCE_OFFSET:-0}
SITL_SYSID_BASE=${SITL_SYSID_BASE:-1}

if ! [[ "$SITL_SPEEDUP" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SITL_SPEEDUP: $SITL_SPEEDUP" >&2
    exit 2
fi
if ! [[ "$SITL_INSTANCE_OFFSET" =~ ^[0-9]+$ ]]; then
    echo "Invalid SITL_INSTANCE_OFFSET: $SITL_INSTANCE_OFFSET" >&2
    exit 2
fi
if ! [[ "$SITL_SYSID_BASE" =~ ^[1-9][0-9]*$ ]] || [ "$SITL_SYSID_BASE" -gt 255 ]; then
    echo "Invalid SITL_SYSID_BASE: $SITL_SYSID_BASE" >&2
    exit 2
fi
if ! [[ "$SITL_PORT_BASE" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SITL_PORT_BASE: $SITL_PORT_BASE" >&2
    exit 2
fi

expected_port_base=$((5760 + SITL_INSTANCE_OFFSET * 10))
expected_sysid_base=$((SITL_INSTANCE_OFFSET + 1))
if [ "$SITL_PORT_BASE" -ne "$expected_port_base" ]; then
    echo "SITL_PORT_BASE must be $expected_port_base for instance offset $SITL_INSTANCE_OFFSET" >&2
    exit 2
fi
if [ "$SITL_SYSID_BASE" -ne "$expected_sysid_base" ]; then
    echo "SITL_SYSID_BASE must be $expected_sysid_base for instance offset $SITL_INSTANCE_OFFSET" >&2
    exit 2
fi

vehicle_count=1
if [ "$SWARM_MODE" = true ]; then
    if ! [[ "$SWARM_COUNT" =~ ^[1-9][0-9]*$ ]] || [ "$SWARM_COUNT" -gt 20 ]; then
        echo "Invalid SWARM_COUNT: $SWARM_COUNT" >&2
        exit 2
    fi
    vehicle_count="$SWARM_COUNT"
fi
if [ $((SITL_SYSID_BASE + vehicle_count - 1)) -gt 255 ]; then
    echo "SYSID range exceeds 255" >&2
    exit 2
fi

runtime_args=(--speedup "$SITL_SPEEDUP")
if [ "$SITL_WIPE" = true ]; then
    runtime_args=(-w "${runtime_args[@]}")
fi

printf '%s\n' "========================================="
printf 'ArduPilot SITL instance %s\n' "$SITL_INSTANCE"
printf '%s\n' "========================================="
printf 'Vehicle: %s\n' "$SITL_VEHICLE"
printf 'Frame: %s\n' "$SITL_FRAME"
printf 'Location: %s\n' "$SITL_LOCATION"
printf 'Mode: %s\n' "$([ "$SWARM_MODE" = true ] && printf 'swarm (%s)' "$SWARM_COUNT" || printf 'single')"
printf 'Wipe: %s\n' "$SITL_WIPE"
printf 'Speedup: %sx\n' "$SITL_SPEEDUP"
printf 'SYSIDs: %s..%s\n' "$SITL_SYSID_BASE" "$((SITL_SYSID_BASE + vehicle_count - 1))"
printf 'TCP ports: %s..%s (increments of 10)\n' "$SITL_PORT_BASE" "$((SITL_PORT_BASE + (vehicle_count - 1) * 10))"
printf '%s\n' "========================================="

cd /root/ardupilot

if [ "$SWARM_MODE" = true ]; then
    exec ./Tools/autotest/sim_vehicle.py \
        -v "$SITL_VEHICLE" \
        -f "$SITL_FRAME" \
        -I "$SITL_INSTANCE_OFFSET" \
        --no-mavproxy \
        --no-rebuild \
        --count "$SWARM_COUNT" \
        --auto-sysid \
        --location "$SITL_LOCATION" \
        --auto-offset-line "$OFFSET_LINE" \
        "${runtime_args[@]}"
fi

case "$SITL_VEHICLE" in
    ArduPlane) binary=/root/ardupilot/build/sitl/bin/arduplane ;;
    ArduCopter) binary=/root/ardupilot/build/sitl/bin/arducopter ;;
    Rover) binary=/root/ardupilot/build/sitl/bin/ardurover ;;
    *) binary="" ;;
esac

home_coords=""
if [ -f /root/ardupilot/Tools/autotest/locations.txt ]; then
    while IFS='=' read -r name coordinates; do
        if [ "$name" = "$SITL_LOCATION" ]; then
            home_coords=${coordinates%%#*}
            break
        fi
    done < /root/ardupilot/Tools/autotest/locations.txt
fi

if [ -n "$binary" ] && [ -f "$binary" ]; then
    binary_args=(-S -I "$SITL_INSTANCE_OFFSET" --sysid "$SITL_SYSID_BASE" --model "$SITL_FRAME")
    if [ -n "$home_coords" ]; then
        binary_args+=(--home "$home_coords")
    fi
    defaults_file="/root/ardupilot/Tools/autotest/default_params/$SITL_FRAME.parm"
    if [ -f "$defaults_file" ]; then
        binary_args+=(--defaults "$defaults_file")
    fi
    exec "$binary" "${binary_args[@]}" "${runtime_args[@]}"
fi

echo "Prebuilt binary unavailable; falling back to sim_vehicle.py"
exec ./Tools/autotest/sim_vehicle.py \
    -v "$SITL_VEHICLE" \
    -f "$SITL_FRAME" \
    -I "$SITL_INSTANCE_OFFSET" \
    --sysid "$SITL_SYSID_BASE" \
    --no-mavproxy \
    --location "$SITL_LOCATION" \
    "${runtime_args[@]}"
