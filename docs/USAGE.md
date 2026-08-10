# sitlctl usage

## Quick start

```bash
sitlctl start 1 copter
sitlctl start 2 rover
sitlctl status all
```

Connect MAVProxy to both primary links:

```bash
mavproxy.py \
  --master=tcp:localhost:5760 \
  --master=tcp:localhost:5960
```

Stop each instance explicitly:

```bash
sitlctl stop 1
sitlctl stop 2
```

## Command shape

### Start

```text
sitlctl start <1|2> <vehicle> [options]
```

Examples:

```bash
sitlctl start 1 plane
sitlctl start 2 quadplane --wipe
sitlctl start 1 copter --speedup 5
sitlctl start 2 rover --location MAVPROXY_USGS1M
```

A running instance must be stopped before it can be replaced. Starting instance 1 never replaces instance 2.

### Status

```bash
sitlctl status
sitlctl status all
sitlctl status 1
sitlctl status 2
```

Status reports the exact container, vehicle, frame, location, mode, SYSIDs, and host-facing TCP endpoints.

### Stop

```bash
sitlctl stop 1
sitlctl stop 2
sitlctl stop all
```

`stop` requires an explicit target. Only `all` stops both SITL containers. Colima and unrelated containers remain running.

### Logs and shell

```bash
sitlctl logs 1
sitlctl logs 2
sitlctl shell 1
sitlctl shell 2
```

Logs follow the selected container. Shell requires the selected instance to be running.

## Vehicles and frames

| Vehicle argument | ArduPilot vehicle | Default frame |
|---|---|---|
| `plane` | ArduPlane | `plane` |
| `quadplane` | ArduPlane | `quadplane` |
| `copter` | ArduCopter | `quad` |
| `copter-hexa` | ArduCopter | `hexa` |
| `copter-octa` | ArduCopter | `octa` |
| `copter-tri` | ArduCopter | `tri` |
| `rover` | Rover | `rover` |
| `rover-skid` | Rover | `rover-skid` |

Helicopter is not available in the pinned image because ArduPilot requires a separate `arducopter-heli` binary that the image does not contain.

Override a frame only when ArduPilot supports it:

```bash
sitlctl start 1 copter --frame dodeca-hexa
```

## Instance allocation

### Instance 1

- container: `ardupilot-sitl-1`
- Compose project: `sitlctl-1`
- ArduPilot instance offsets: `0..19`
- SYSIDs: `1..20`
- TCP ports: `5760, 5770, ... 5950`
- logs: `~/bin/logs/1`

### Instance 2

- container: `ardupilot-sitl-2`
- Compose project: `sitlctl-2`
- ArduPilot instance offsets: `20..39`
- SYSIDs: `21..40`
- TCP ports: `5960, 5970, ... 6150`
- logs: `~/bin/logs/2`

The fixed ranges prevent cross-container port and SYSID collisions without hidden runtime allocation.

## Swarms

Each container can run up to 20 vehicles of one type:

```bash
sitlctl start 1 copter --swarm 3
sitlctl start 2 rover --swarm 2 --offset-line 0,15
```

MAVProxy needs one `--master` argument for each published TCP link:

```bash
mavproxy.py \
  --master=tcp:localhost:5760 \
  --master=tcp:localhost:5770 \
  --master=tcp:localhost:5780 \
  --master=tcp:localhost:5960 \
  --master=tcp:localhost:5970
```

## Troubleshooting

### Docker is unavailable

```bash
docker context show
docker info
colima status
```

On xmac, select the Colima context if needed:

```bash
docker context use colima
```

### Image is missing

Normal starts do not pull:

```bash
docker pull vanfleetdev/sitl-ardupilot:4.6.3
```

### Instance exits during startup

```bash
sitlctl status 1
sitlctl logs 1
```

Use instance `2` in both commands when diagnosing the second container.

### MAVProxy cannot connect

1. Confirm the selected instance is `running` with `sitlctl status`.
2. Read `sitlctl logs <instance>` for the ArduPilot TCP port.
3. Use `tcp:localhost:5760` for instance 1 or `tcp:localhost:5960` for instance 2.
4. Require an actual heartbeat. An open port without a heartbeat is not a healthy SITL link.

## Runtime files

```text
~/bin/
├── sitlctl
├── docker-compose.yml
├── docker-entrypoint.sh
├── locations.txt
└── logs/
    ├── 1/
    └── 2/
```

The old `~/bin/sitl` command is removed after the verified install.
