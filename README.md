# ArduPilot SITL CLI

[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://docker.com)
[![Platform](https://img.shields.io/badge/platform-macos%20%7C%20linux-lightgrey.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Simple CLI wrapper for running ArduPilot SITL (Software In The Loop) on macOS and Linux using Docker.

Perfect for MAVProxy development and testing without physical hardware.

## Features

- **Headless**: No GUI dependencies or X11 setup required
- **Simple CLI**: Just type `sitl plane` or `sitl copter`
- **Multiple Vehicles**: Support for Plane, Copter, QuadPlane, Rover, and more
- **Swarm Mode**: Launch multiple vehicles simultaneously
- **MAVProxy Ready**: Connect your local MAVProxy installation
- **Cross-Platform**: Works on macOS (Intel/Apple Silicon) and Linux (Ubuntu/Debian)
- **Isolated**: Docker container keeps your system clean

## Prerequisites

### macOS

1. **Docker Desktop** - [Download and install](https://www.docker.com/products/docker-desktop/)
   - Start Docker Desktop after installation
   - No additional Docker configuration needed

2. **Git** - Usually pre-installed, or install via [Homebrew](https://brew.sh)

### Linux (Ubuntu/Debian)

1. **Docker Engine**:
   ```bash
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose
   sudo usermod -aG docker $USER
   # Logout and login again for group changes to take effect
   newgrp docker
   ```

2. **Git** - Usually pre-installed, or `sudo apt-get install git`

## Quick Start

```bash
# Clone the repository
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli

# Run the install script
./install.sh

# Start SITL
sitl plane

# In another terminal, connect with your MAVProxy
mavproxy.py --master=tcp:localhost:5760
```

## Installation

Choose your installation method based on your needs and platform.

### Method 1: Docker Hub (Recommended)

Pull the pre-built image from Docker Hub. This is the fastest method.

#### macOS Setup (Docker Hub)

```bash
# 1. Install Docker Desktop
# Download from: https://docker.com/products/docker-desktop/

# 2. Clone the repository
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli

# 3. Pull the Docker image
docker pull vanfleetdev/sitl-ardupilot:4.6.3

# 4. Install the CLI
mkdir -p ~/bin
cp sitl ~/bin/sitl
chmod +x ~/bin/sitl

# 5. Copy supporting files to ~/bin
cp docker-compose.yml ~/bin/
cp docker-entrypoint.sh ~/bin/

# 6. Ensure ~/bin is in your PATH
export PATH="$HOME/bin:$PATH"
# Add the above line to ~/.zshrc or ~/.bashrc

# 7. Test it
sitl plane
```

#### Linux Setup (Docker Hub)

```bash
# 1. Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker $USER
newgrp docker  # or logout and login

# 2. Clone the repository
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli

# 3. Pull the Docker image
docker pull vanfleetdev/sitl-ardupilot:4.6.3

# 4. Install the CLI
mkdir -p ~/bin
cp sitl ~/bin/sitl
chmod +x ~/bin/sitl

# 5. Copy supporting files to ~/bin
cp docker-compose.yml ~/bin/
cp docker-entrypoint.sh ~/bin/

# 6. Ensure ~/bin is in your PATH
export PATH="$HOME/bin:$PATH"
# Add the above line to ~/.bashrc

# 7. Test it
sitl plane
```

### Method 2: Local Tar File (Offline/Air-Gapped)

Use this method if you have the Docker image tar file (e.g., `sitl-ardupilot-4.6.3.tar`).

#### macOS Setup (Local Tar)

```bash
# 1. Install Docker Desktop
# Download from: https://docker.com/products/docker-desktop/

# 2. Clone the repository
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli

# 3. Load the Docker image from tar
# Place sitl-ardupilot-4.6.3.tar in this directory
docker load -i sitl-ardupilot-4.6.3.tar

# 4. Tag the image
docker tag sitl-ardupilot:4.6.3 vanfleetdev/sitl-ardupilot:4.6.3

# 5. Install the CLI
mkdir -p ~/bin
cp sitl ~/bin/sitl
chmod +x ~/bin/sitl

# 6. Copy supporting files to ~/bin
cp docker-compose.yml ~/bin/
cp docker-entrypoint.sh ~/bin/

# 7. Ensure ~/bin is in your PATH
export PATH="$HOME/bin:$PATH"
# Add the above line to ~/.zshrc or ~/.bashrc

# 8. Test it
sitl plane
```

#### Linux Setup (Local Tar)

```bash
# 1. Install Docker
sudo apt-get update
sudo apt-get install -y docker.io docker-compose
sudo usermod -aG docker $USER
newgrp docker  # or logout and login

# 2. Clone the repository
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli

# 3. Load the Docker image from tar
# Place sitl-ardupilot-4.6.3.tar in this directory
docker load -i sitl-ardupilot-4.6.3.tar

# 4. Tag the image
docker tag sitl-ardupilot:4.6.3 vanfleetdev/sitl-ardupilot:4.6.3

# 5. Install the CLI
mkdir -p ~/bin
cp sitl ~/bin/sitl
chmod +x ~/bin/sitl

# 6. Copy supporting files to ~/bin
cp docker-compose.yml ~/bin/
cp docker-entrypoint.sh ~/bin/

# 7. Ensure ~/bin is in your PATH
export PATH="$HOME/bin:$PATH"
# Add the above line to ~/.bashrc

# 8. Test it
sitl plane
```

### Automated Install (Both Methods)

If you have Docker and the image ready (either pulled or loaded), you can use the install script:

```bash
./install.sh
```

This will:
- Check Docker is running
- Install `sitl` to `~/bin/`
- Copy necessary files
- Verify the installation

**Note:** You must have the Docker image ready before running install.sh (either via `docker pull` or `docker load`).

## Commands

### Vehicle Commands

| Command | Description |
|---------|-------------|
| `sitl plane` | Start ArduPlane (default frame) |
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
| `--offset-line` | Spread swarm in a line | `sitl copter --swarm 5 --offset-line 90,10` |
| `--wipe` | Wipe parameters (fresh start) | `sitl plane --wipe` |
| `--location <name>` | Start at named location | `sitl copter --location CMAC` |
| `--speedup <n>` | Simulation speed multiplier | `sitl plane --speedup 10` |

## Usage Examples

### Basic Testing Workflow

```bash
# Terminal 1: Start SITL
sitl plane

# Terminal 2: Connect with MAVProxy
mavproxy.py --master=tcp:localhost:5760

# When done
sitl stop
```

### Testing Multiple Vehicles

```bash
# Test plane
sitl plane
# ... test ...
sitl stop

# Test copter
sitl copter
# ... test ...
sitl stop

# Test quadplane
sitl quadplane
# ... test ...
sitl stop
```

### Swarm Mode (Multi-Vehicle)

Launch multiple vehicles simultaneously with auto-assigned SYS IDs:

```bash
# Start 5 copters in a swarm
sitl copter --swarm 5

# Start 3 planes at CMAC location
sitl plane --swarm 3 --location CMAC

# Start 10 copters in a line (heading 90°, 10m spacing)
sitl copter --swarm 10 --offset-line 90,10

# Connect with MAVProxy
mavproxy.py --master=tcp:localhost:5760 --master=tcp:localhost:5770
```

**Swarm Features:**
- All vehicles are the same type (e.g., all copters or all planes)
- Auto-assigns unique SYS IDs (1, 2, 3, etc.)
- Vehicles spawn in a line formation to avoid collisions
- MAVProxy can control all vehicles simultaneously
- Use `vehicle <n>` in MAVProxy to switch between vehicles
- Use `alllinks <cmd>` to send commands to all vehicles

**Note:** Maximum recommended swarm size is 20 vehicles for performance.

### Fresh Start with Wiped Parameters

```bash
sitl plane --wipe
```

### Test at Specific Location

```bash
sitl copter --location CMAC
```

## MAVProxy Connection

### Single Vehicle Mode

SITL exposes MAVLink on TCP port 5760:

```bash
# Standard connection
mavproxy.py --master=tcp:localhost:5760

# With console and map (requires X11/XQuartz if using GUI)
mavproxy.py --master=tcp:localhost:5760 --console --map
```

**Connection Details:**
- Protocol: TCP
- Host: localhost (127.0.0.1)
- Port: 5760

### Swarm Mode

In swarm mode, each vehicle uses a separate TCP port:

```bash
# 2 vehicles
mavproxy.py --master=tcp:localhost:5760 --master=tcp:localhost:5770

# 3 vehicles
mavproxy.py --master=tcp:localhost:5760 --master=tcp:localhost:5770 --master=tcp:localhost:5780
```

**Port Mapping:**
- Vehicle 1 (SYS ID 1): tcp:localhost:5760
- Vehicle 2 (SYS ID 2): tcp:localhost:5770
- Vehicle 3 (SYS ID 3): tcp:localhost:5780
- etc. (increments of 10)

## Documentation

- **[Detailed Usage Guide](docs/USAGE.md)** - Comprehensive documentation
- **[Troubleshooting](docs/USAGE.md#troubleshooting)** - Common issues and solutions

## How It Works

```
┌─────────────────────┐         ┌──────────────────┐
│   Your Computer     │         │  Docker Container │
│   (macOS/Linux)     │  TCP/UDP│                  │
│                     │◄───────►│  ArduPilot SITL  │
│  mavproxy.py        │ :14550  │  (Debian-based)  │
│                     │         │                  │
└─────────────────────┘         └──────────────────┘
```

1. `sitl plane` starts a Docker container with ArduPilot SITL
2. SITL runs in headless mode (no MAVProxy inside container)
3. Single vehicle: SITL outputs MAVLink on TCP port 5760
4. Swarm mode: Each vehicle uses TCP ports 5760, 5770, 5780, etc.
5. Your local MAVProxy connects to localhost ports
6. `sitl stop` removes the container

## Development

This project is designed for MAVProxy development:

- Run SITL in Docker (stable, isolated environment)
- Connect with your local, modified MAVProxy
- Test changes without affecting your system
- No need for physical flight controller

## Requirements

### macOS
- macOS 10.14+ (Intel or Apple Silicon)
- Docker Desktop 4.0+

### Linux
- Ubuntu 18.04+ or Debian 10+
- Docker Engine 20.0+
- User must be in `docker` group

### Common
- ~4GB free disk space (for Docker image)
- Git

## File Structure

```
sitl-cli/
├── sitl                 # CLI script
├── docker-compose.yml   # Docker configuration
├── docker-entrypoint.sh # Container entrypoint
├── install.sh          # Installation script
├── docs/
│   └── USAGE.md        # Detailed documentation
├── LICENSE             # MIT License
└── README.md           # This file
```

## Troubleshooting

**Docker permission denied (Linux):**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes
newgrp docker
# or logout and login again
```

**SITL won't start:**
```bash
# Check Docker is running
docker info

# Check status
sitl status

# Force stop and restart
sitl stop
sitl plane
```

**Can't connect with MAVProxy:**
```bash
# Verify SITL is running
sitl status

# Check logs
sitl logs

# Verify port is listening
lsof -i :5760
```

See [docs/USAGE.md](docs/USAGE.md#troubleshooting) for more troubleshooting tips.

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

- Docker image: [vanfleetdev/sitl-ardupilot](https://hub.docker.com/r/vanfleetdev/sitl-ardupilot) with ArduPilot 4.6.3
- ArduPilot: [ardupilot.org](https://ardupilot.org)
- MAVProxy: [ardupilot.org/mavproxy](https://ardupilot.org/mavproxy)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
