# ArduPilot SITL Usage Guide

Headless Docker-based SITL environment for testing MAVProxy changes on macOS and Linux.

## Quick Start

```bash
# Start SITL
sitl plane

# In another terminal, connect with your MAVProxy
mavproxy.py --master=tcp:localhost:5760

# When done
sitl stop
```

## Available Commands

### Vehicle Commands

| Command | Description |
|---------|-------------|
| `sitl plane` | Start ArduPlane (default plane frame) |
| `sitl quadplane` | Start ArduPlane with quadplane frame |
| `sitl copter` | Start ArduCopter (quad frame) |
| `sitl copter-hexa` | Start hexacopter |
| `sitl copter-octa` | Start octocopter |
| `sitl copter-tri` | Start tricopter |
| `sitl copter-heli` | Start helicopter |
| `sitl rover` | Start Rover |
| `sitl rover-skid` | Start Rover with skid steering |

### Management Commands

| Command | Description |
|---------|-------------|
| `sitl stop` | Stop the SITL container |
| `sitl status` | Check if SITL is running |
| `sitl shell` | Open bash shell in container |
| `sitl logs` | View SITL logs |
| `sitl --help` | Show help message |

### Options

| Option | Description | Example |
|--------|-------------|---------|
| `--frame <name>` | Override default frame | `sitl copter --frame hexa` |
| `--swarm <n>` | Launch n vehicles as a swarm | `sitl copter --swarm 5` |
| `--offset-line` | Spread swarm in a line (heading,distance) | `sitl copter --swarm 5 --offset-line 90,10` |
| `--wipe` | Wipe parameters (fresh start) | `sitl plane --wipe` |
| `--location <name>` | Start at named location | `sitl copter --location CMAC` |
| `--speedup <n>` | Simulation speed multiplier | `sitl plane --speedup 10` |

## Common Workflows

### Basic Testing

```bash
# 1. Start SITL
sitl plane

# 2. Connect with your local MAVProxy
mavproxy.py --master=localhost:14550

# 3. Test your MAVProxy changes
# ... do your testing ...

# 4. Stop SITL
sitl stop
```

### Testing Multiple Vehicle Types

```bash
# Test plane
sitl plane
mavproxy.py --master=localhost:14550
sitl stop

# Test copter
sitl copter
mavproxy.py --master=localhost:14550
sitl stop

# Test quadplane
sitl quadplane
mavproxy.py --master=localhost:14550
sitl stop
```

## Swarm Mode (Multi-Vehicle Simulation)

Swarm mode allows you to launch multiple vehicles simultaneously, all running the same vehicle type (e.g., 5 copters or 3 planes).

### Starting a Swarm

```bash
# Basic swarm - 5 copters
sitl copter --swarm 5

# Swarm at specific location
sitl copter --swarm 5 --location CMAC

# Swarm with custom formation
sitl copter --swarm 10 --offset-line 90,10

# Swarm of planes
sitl plane --swarm 3
```

### How Swarm Works

- **Auto SYS ID Assignment**: Vehicles automatically get SYS IDs 1, 2, 3, etc.
- **Formation**: Vehicles spawn in a line to avoid collisions
  - Default: Heading 90° (east), 10m spacing
  - Customize with `--offset-line <heading>,<distance>`
- **Single MAVLink Endpoint**: All vehicles communicate through localhost:14550
- **MAVProxy Multi-Vehicle Support**: Auto-detects and manages all vehicles

### MAVProxy Swarm Commands

Once connected to a swarm, use these MAVProxy commands:

```bash
# Connect to swarm
mavproxy.py --master=localhost:14550

# Switch to specific vehicle (e.g., vehicle #3)
vehicle 3

# Send command to all vehicles
alllinks mode guided
alllinks arm throttle
alllinks takeoff 40

# Check vehicle status
vehicle 1
status

# Vehicle #2
vehicle 2
status
```

### Swarm Examples

**Fleet Takeoff:**
```bash
# Terminal 1: Start 5 copters
sitl copter --swarm 5 --location CMAC

# Terminal 2: Connect MAVProxy
mavproxy.py --master=localhost:14550

# In MAVProxy:
alllinks mode guided
alllinks arm throttle
alllinks takeoff 40
```

**Formation Flying:**
```bash
# 10 copters in a north-south line (heading 0°), 15m apart
sitl copter --swarm 10 --offset-line 0,15 --location CMAC
```

**Large-Scale Testing:**
```bash
# 20 copters (maximum supported)
sitl copter --swarm 20 --speedup 5
```

### Swarm Limitations

- One CLI invocation supports one vehicle type (all copters, all planes, etc.)
- Mixed-domain swarms need separate isolated instances with distinct names and port ranges; the current CLI does not configure them
- Maximum supported: 20 vehicles
- All vehicles start at the same location type (use offset to space them)
- Stopping stops the entire swarm (cannot stop individual vehicles)

### Troubleshooting Swarm

**Vehicles not spreading out:**
- Check offset-line format: `--offset-line <heading>,<distance>`
- Example: `--offset-line 90,10` = east heading, 10m spacing

**Performance issues with large swarms:**
- Use `--speedup` to reduce computational load
- Example: `sitl copter --swarm 15 --speedup 5`

**MAVProxy not detecting all vehicles:**
- Wait a few seconds after swarm starts for all vehicles to initialize
- Check swarm status: `sitl status` (shows "Swarm" mode)
- Verify in MAVProxy: `vehicle list` should show all SYS IDs

### Fresh Start with Wiped Parameters

```bash
sitl plane --wipe
```

### Test at Specific Location

```bash
sitl copter --location CMAC
```

Available locations are defined in the SITL locations.txt file. Common ones include:
- `CMAC` - Canberra Model Aircraft Club, Australia
- `Ballarat` - Ballarat, Australia
- `OBC` - Outback Challenge location

## MAVProxy Connection Details

- **Protocol**: UDP
- **Host**: `localhost` or `127.0.0.1`
- **Port**: `14550`
- **Alternative TCP Port**: `5760`

Example connection commands:

```bash
# Standard connection
mavproxy.py --master=localhost:14550

# With console and map (if you have XQuartz)
mavproxy.py --master=localhost:14550 --console --map

# Connection with specific system ID
mavproxy.py --master=localhost:14550 --target-system=1
```

## File Locations

```
~/bin/
├── sitl                  # Canonical CLI
├── sitlctl -> sitl       # Compatibility command
├── docker-compose.yml    # Docker configuration
├── docker-entrypoint.sh  # Container entrypoint
├── locations.txt         # Named launch locations
└── logs/                 # SITL logs directory
```

## Troubleshooting

### SITL won't start

```bash
# Check Docker is running
docker info

# Check if container already exists
sitl status

# Force stop and restart
sitl stop
sitl plane
```

### Can't connect with MAVProxy

1. Verify SITL is running:
   ```bash
   sitl status
   ```

2. Check logs for errors:
   ```bash
   sitl logs
   ```

3. Verify port is listening:
   ```bash
   lsof -i :14550
   ```

### Container issues

```bash
# Open shell to debug
sitl shell

# Check running processes inside container
ps aux

# Check SITL binary location
ls -la /ardupilot/build/sitl/bin/
```

### Permission errors

The script should work without sudo. If you get permission errors:

```bash
# Fix ownership of the installed runtime bundle
sudo chown $(whoami) ~/bin/sitl ~/bin/docker-compose.yml ~/bin/docker-entrypoint.sh

# Ensure the launcher and entrypoint are executable
chmod +x ~/bin/sitl ~/bin/docker-entrypoint.sh
```

## Advanced Usage

### Custom Frame Types

```bash
# List available frames (inside container)
sitl shell
sim_vehicle.py --help | grep -A 50 "Frame Type"

# Use custom frame
sitl plane --frame plane-jet
sitl copter --frame dodeca-hexa
```

### Multiple MAVProxy Outputs

If you need to connect multiple GCS applications, configure MAVProxy to output to additional ports:

```bash
mavproxy.py --master=localhost:14550 --out udp:127.0.0.1:14551
```

Then connect your second GCS to port 14551.

### Accessing Logs

Use `sitl logs` for container output. The installed bundle keeps its host runtime directory under `~/bin/`.

## Development Notes

### Docker Image

- **Image**: `vanfleetdev/sitl-ardupilot:4.6.3`
- **Base**: Debian 12 (Bookworm)
- **ArduPilot Version**: 4.6.3

### Port Mapping

- Single vehicle: host TCP 5760
- Swarm: host TCP 5760, 5770, ... 5950 (one endpoint per vehicle, maximum 20)

### Container Lifecycle

1. `sitl plane` creates and starts the container
2. The container runs prebuilt SITL with MAVProxy disabled
3. SITL serves MAVLink over TCP, starting at port 5760
4. Local MAVProxy connects to `tcp:localhost:5760` and the additional swarm endpoints
5. `sitl stop` stops and removes the container

## References

- [ArduPilot SITL Documentation](https://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html)
- [MAVProxy Documentation](https://ardupilot.org/mavproxy/index.html)
- [Docker SITL Repository](https://github.com/ben-xD/ardupilot-sitl-docker)
- [SITL Tutorial](https://ardupilot.org/dev/docs/copter-sitl-mavproxy-tutorial.html)

## Support

For issues with:
- **SITL/ArduPilot**: [ArduPilot Discord](https://ardupilot.org/discord) or [Discuss Forum](https://discuss.ardupilot.org/)
- **Docker Image**: [GitHub Issues](https://github.com/ben-xD/ardupilot-sitl-docker/issues)
- **This Setup**: Check the runbook in your home directory
