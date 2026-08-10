# sitlctl

A small operator-facing wrapper for running ArduPilot SITL in Docker or Colima.

`SITLCTL` manages two independent containers, so a Copter and Rover (or any other two supported vehicle selections) can run at the same time and connect to one MAVProxy session.

## Runtime layout

| Instance | Container | TCP endpoints | SYSIDs | State root |
|---|---|---|---|---|
| `1` | `ardupilot-sitl-1` | `5760, 5770, ... 5950` | `1..20` | `~/bin/logs/1` |
| `2` | `ardupilot-sitl-2` | `5960, 5970, ... 6150` | `21..40` | `~/bin/logs/2` |

Each instance can run one vehicle or a same-type swarm of up to 20 vehicles. Container names, Compose projects, host ports, ArduPilot instance offsets, SYSIDs, start locks, and state roots are separate. State is further isolated by vehicle and frame below each root. `sitlctl logs` reads the selected container's Docker output.

The launcher never stops Colima and never touches unrelated Docker workloads.

## Requirements

- Docker or Colima
- Docker Compose plugin (`docker compose`) or standalone `docker-compose`
- Cached image `vanfleetdev/sitl-ardupilot:4.6.3`

On macOS with Homebrew:

```bash
brew install colima docker docker-compose
brew services start colima
```

## Install

```bash
git clone https://github.com/vanfleet-dev/sitl-cli.git
cd sitl-cli
./install.sh
```

The installer:

1. keeps the cached image when present, or pulls it when missing;
2. stages `sitlctl`, `docker-compose.yml`, `docker-entrypoint.sh`, and `locations.txt` as one bundle;
3. verifies the staged `sitlctl --help` path before replacing installed files;
4. installs the complete bundle under `~/bin`;
5. removes the old `~/bin/sitl` command only after the verified bundle is installed.

Ensure `~/bin` is in `PATH`:

```bash
export PATH="$HOME/bin:$PATH"
```

## Commands

```text
sitlctl start <1|2> <vehicle> [options]
sitlctl stop <1|2|all>
sitlctl status [1|2|all]
sitlctl logs <1|2>
sitlctl shell <1|2>
sitlctl --help
```

Supported vehicles:

- `plane`
- `quadplane`
- `copter`
- `copter-hexa`
- `copter-octa`
- `copter-tri`
- `rover`
- `rover-skid`

Helicopter is not advertised because the pinned image does not contain the separate `arducopter-heli` binary required by ArduPilot's frame metadata. The known `heli`, `heli-gas`, `heli-dual`, and `heli-blade360` frame overrides are rejected before Docker startup.

Start options:

```text
--swarm <1..20>
--frame <name>
--wipe
--location <name>
--speedup <positive integer>
--offset-line <heading,distance>
```

Unknown commands, options, and location names fail before Docker startup instead of being ignored.

## Two-vehicle example

```bash
sitlctl start 1 copter
sitlctl start 2 rover
sitlctl status all
```

Connect both links:

```bash
mavproxy.py \
  --master=tcp:localhost:5760 \
  --master=tcp:localhost:5960
```

Stop one vehicle without affecting the other:

```bash
sitlctl stop 1
sitlctl status 2
```

Stop everything owned by this tool:

```bash
sitlctl stop all
```

## Swarms

```bash
sitlctl start 1 copter --swarm 5 --offset-line 90,10
sitlctl start 2 rover --swarm 3 --location CMAC
```

Instance 1 receives SYSIDs `1..5` at TCP ports `5760..5800`. Instance 2 receives SYSIDs `21..23` at TCP ports `5960..5980`.

Connect each published endpoint separately:

```bash
mavproxy.py \
  --master=tcp:localhost:5760 \
  --master=tcp:localhost:5770 \
  --master=tcp:localhost:5960 \
  --master=tcp:localhost:5970
```

## Named locations

The default is `MAVPROXY_USGS1M`. Select another exact entry from `locations.txt` with:

```bash
sitlctl start 1 rover --location CMAC
```

All MAVLink endpoints are published on host loopback only (`127.0.0.1`).

## Image behavior

Normal starts never pull or replace the image. If the configured image is absent, `sitlctl` exits and prints the explicit `docker pull` command.

Override the image for a deliberate test:

```bash
SITL_IMAGE=example/image:tag sitlctl start 1 copter
```

## Development checks

```bash
bash -n sitlctl install.sh docker-entrypoint.sh
python3 -m unittest discover -s tests -v
docker compose -f docker-compose.yml config
```

Runtime acceptance still requires real ArduPilot heartbeats on every requested MAVLink link; container startup alone is not sufficient.

## License

MIT. See [LICENSE](LICENSE).
