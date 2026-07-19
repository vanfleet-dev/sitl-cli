#!/bin/bash

# Docker entrypoint script for SITL
# Handles both single vehicle and swarm modes

set -e

# Default values
SITL_VEHICLE=${SITL_VEHICLE:-ArduPlane}
SITL_FRAME=${SITL_FRAME:-plane}
SWARM_MODE=${SWARM_MODE:-false}
SITL_LOCATION=${SITL_LOCATION:-CMAC}
OFFSET_LINE=${OFFSET_LINE:-90,10}
SITL_WIPE=${SITL_WIPE:-false}
SITL_SPEEDUP=${SITL_SPEEDUP:-1}

if ! [[ "$SITL_SPEEDUP" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid SITL_SPEEDUP: $SITL_SPEEDUP (expected a positive integer)" >&2
    exit 2
fi
RUNTIME_ARGS=(--speedup "$SITL_SPEEDUP")
if [ "$SITL_WIPE" = "true" ]; then
    RUNTIME_ARGS=(-w "${RUNTIME_ARGS[@]}")
fi

echo "========================================="
echo "ArduPilot SITL Docker Container"
echo "========================================="
echo "Vehicle: $SITL_VEHICLE"
echo "Frame: $SITL_FRAME"
echo "Mode: $([ "$SWARM_MODE" = "true" ] && echo "Swarm ($SWARM_COUNT vehicles)" || echo "Single Vehicle")"
echo "Wipe: $SITL_WIPE"
echo "Speedup: ${SITL_SPEEDUP}x"
echo "========================================="

cd /root/ardupilot

if [ "$SWARM_MODE" = "true" ] && [ -n "$SWARM_COUNT" ]; then
    echo ""
    echo "Starting SITL Swarm..."
    echo "Count: $SWARM_COUNT"
    echo "Location: $SITL_LOCATION"
    echo "Offset: $OFFSET_LINE"
    echo ""
    echo "MAVLink Ports (TCP):"
    for i in $(seq 0 $((SWARM_COUNT - 1))); do
        port=$((5760 + i * 10))
        sysid=$((i + 1))
        echo "  Vehicle $sysid: tcp:localhost:$port"
    done
    echo ""
    
    exec ./Tools/autotest/sim_vehicle.py \
        -v "$SITL_VEHICLE" \
        -f "$SITL_FRAME" \
        --no-mavproxy \
        --no-rebuild \
        --count "$SWARM_COUNT" \
        --auto-sysid \
        --location "$SITL_LOCATION" \
        --auto-offset-line "$OFFSET_LINE" \
        "${RUNTIME_ARGS[@]}"
else
    echo ""
    echo "Starting Single Vehicle SITL..."
    echo "Location: $SITL_LOCATION"
    echo "MAVLink: tcp:localhost:5760"
    echo ""
    
    # Check if binary exists and run directly to avoid waf rebuild
    # Convert ArduPlane -> arduplane, ArduCopter -> arducopter, etc.
    VEHICLE_LOWER=$(echo "$SITL_VEHICLE" | tr '[:upper:]' '[:lower:]')
    # Remove "ardu" prefix if present since binaries are named arducopter, arduplane, etc.
    BINARY_NAME=$(echo "$VEHICLE_LOWER" | sed 's/^ardu//')
    BINARY="/root/ardupilot/build/sitl/bin/ardu$BINARY_NAME"
    
    if [ -f "$BINARY" ]; then
        echo "Using pre-built binary: $BINARY"
        # Parse location for --home parameter
        if [ -f "/root/ardupilot/Tools/autotest/locations.txt" ]; then
            HOME_COORDS=$(grep "^$SITL_LOCATION=" /root/ardupilot/Tools/autotest/locations.txt | cut -d'=' -f2 | cut -d'#' -f1)
            if [ -n "$HOME_COORDS" ]; then
                # Set defaults file based on frame type
                DEFAULTS_FILE="/root/ardupilot/Tools/autotest/default_params/$SITL_FRAME.parm"
                BINARY_ARGS=(-S --model "$SITL_FRAME" --home "$HOME_COORDS")
                if [ -f "$DEFAULTS_FILE" ]; then
                    BINARY_ARGS+=(--defaults "$DEFAULTS_FILE")
                fi
                exec "$BINARY" "${BINARY_ARGS[@]}" "${RUNTIME_ARGS[@]}"
            else
                exec "$BINARY" -S --model "$SITL_FRAME" "${RUNTIME_ARGS[@]}"
            fi
        else
            exec "$BINARY" -S --model "$SITL_FRAME" "${RUNTIME_ARGS[@]}"
        fi
    else
        echo "Binary not found, falling back to sim_vehicle.py build..."
        exec ./Tools/autotest/sim_vehicle.py \
            -v "$SITL_VEHICLE" \
            -f "$SITL_FRAME" \
            --no-mavproxy \
            --location "$SITL_LOCATION" \
            "${RUNTIME_ARGS[@]}"
    fi
fi
