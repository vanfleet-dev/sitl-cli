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

ARDUPILOT_ROOT=${ARDUPILOT_ROOT:-/root/ardupilot}
SITL_STATE_DIR=${SITL_STATE_DIR:-$ARDUPILOT_ROOT/logs/$SITL_VEHICLE-$SITL_FRAME}
sim_vehicle="$ARDUPILOT_ROOT/Tools/autotest/sim_vehicle.py"
if [ ! -x "$sim_vehicle" ]; then
    echo "sim_vehicle.py is not executable: $sim_vehicle" >&2
    exit 2
fi

cd "$ARDUPILOT_ROOT"

frame_args=(-f "$SITL_FRAME")
if [ "$SWARM_MODE" = true ] \
    && [ "$SITL_VEHICLE" = Rover ] \
    && [ "$SITL_FRAME" = rover-skid ]; then
    # sim_vehicle.py mis-prefixes the second default file for counted vehicles.
    frame_args=(
        -f rover
        --model rover-skid
        --add-param-file "$ARDUPILOT_ROOT/Tools/autotest/default_params/rover-skid.parm"
    )
fi

sim_args=(
    -v "$SITL_VEHICLE"
    "${frame_args[@]}"
    -I "$SITL_INSTANCE_OFFSET"
    --no-mavproxy
    --no-rebuild
    --location "$SITL_LOCATION"
    --use-dir "$SITL_STATE_DIR"
)

if [ "$SWARM_MODE" = true ]; then
    sim_args+=(
        --count "$SWARM_COUNT"
        --auto-sysid
        --auto-offset-line "$OFFSET_LINE"
    )
else
    sim_args+=(--sysid "$SITL_SYSID_BASE")
fi

exec "$sim_vehicle" "${sim_args[@]}" "${runtime_args[@]}"
