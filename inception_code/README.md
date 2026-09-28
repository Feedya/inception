*This project has been created as part of the 42 curriculum by Fedor le meilleure programmeur du monde.*

# Inception

## Description

Inception is a system administration project. The goal is to build a small, self-hosted
web infrastructure entirely with Docker, orchestrated by Docker Compose, and running
inside a dedicated virtual machine.

The stack is composed of three containers, each built from a Dockerfile written from
scratch (no ready-made images from Docker Hub):

- **nginx** — the single entry point of the infrastructure, exposed on port 443 only,
  serving HTTPS with TLSv1.2/TLSv1.3 and a self-signed certificate.
- **wordpress** — WordPress running on PHP-FPM (no web server bundled), reachable only
  from the internal Docker network.
- **mariadb** — the database backing WordPress, also reachable only from the internal
  Docker network.

WordPress data (site files) and the MariaDB data (database) are persisted with two
Docker named volumes, physically stored on the host at `/home/fepopadi/data`. The whole
stack is reachable at `https://fepopadi.42.fr`, which resolves to the VM's own loopback
address via `/etc/hosts`.

## Project Description

### Docker usage and sources

Each service under `srcs/requirements/<service>/` has its own `Dockerfile`, its own
`docker-entrypoint.sh`, and, where relevant, a `conf/` directory (static configuration)
and a `tools/` directory (init scripts run at container startup). The entrypoint scripts
for `mariadb`, `nginx` and `wordpress` are adapted from the official
[docker-library](https://github.com/docker-library) entrypoints (see Resources), rewired
to read credentials from Docker secrets instead of plain environment variables, and to
this project's own configuration templates.

`srcs/compose.yaml` builds the three images (image name = service name, as required),
attaches them to a single custom bridge network (`inception`), wires the two persistent
volumes, and injects the secrets. The root `Makefile` is the single entry point: it
prepares the host (`/etc/hosts`, data directories, secrets) before calling
`docker compose`.

### Main design choices

- **One Dockerfile per service**, each built from a pinned base image
  (`alpine:3.22.4` for nginx/wordpress, `debian:bookworm` for mariadb) — never `latest`.
- **No hardcoded credentials.** Every password is generated with `openssl rand` by
  `make seed` and injected exclusively through Docker secrets.
- **PID 1 discipline.** Every entrypoint ends with `exec "$@"`, so the actual service
  process (`nginx`, `php-fpm83`, `mariadbd`) becomes PID 1 of its container — no shell
  wrapper, no `tail -f`, no background process left dangling.
- **`restart: on-failure`** on all three services so a crashed container comes back up
  on its own.

### Virtual Machines vs Docker

A VM virtualizes an entire machine — its own kernel, its own drivers — through a
hypervisor, which gives strong isolation but costs real overhead in boot time, disk
footprint and RAM per instance. A Docker container shares the host kernel and only
isolates processes (namespaces, cgroups), so it starts in milliseconds, is a fraction of
the size, and lets you run one container per service without paying a full OS tax for
each. This project actually uses both, for different reasons: the *VM* exists because
the school workstation gives no root access and Docker needs one — the VM is a
disposable, fully-privileged sandbox. *Docker*, inside that VM, is what actually
implements the "one isolated service per container" architecture the subject asks for.

### Secrets vs Environment Variables

Environment variables set in `.env` end up readable in `docker inspect`, in the
container's `/proc/<pid>/environ`, and in the image/container metadata — fine for
non-sensitive configuration (`DOMAIN_NAME`, ports, usernames), risky for passwords.
Docker secrets are mounted as an in-memory `tmpfs` file under `/run/secrets/<name>`
inside the container, root-readable only, never exposed by `docker inspect` and never
part of any image layer. This project therefore keeps every password
(`db_password`, `db_root_password`, `wp_admin_password`, `wp_user_password`) as a Docker
secret referenced via the `*_FILE` convention already supported by the upstream
entrypoints (`MYSQL_PASSWORD_FILE`, `WORDPRESS_ADMIN_PASSWORD_FILE`, …), and reserves
`.env` for everything that is not a credential.

### Docker Network vs Host Network

`network_mode: host` makes a container share the host's network namespace directly —
no isolation between containers, port collisions become likely, and it is explicitly
forbidden by the subject. This project instead declares a dedicated bridge network
(`inception`) in `compose.yaml`: each container gets its own network namespace and
virtual interface, and containers address each other by service name through Docker's
embedded DNS (`wordpress:9000`, `mariadb:3306`). Only nginx publishes a port to the
host (`443`), keeping the smallest possible attack surface and matching the "nginx is
the only entry point" requirement.

### Docker Volumes vs Bind Mounts

A bind mount is a direct passthrough of an existing host path into a container — the
host is fully responsible for that path's existence and permissions, and the mapping is
not tracked by Docker as an object of its own. A named volume is a storage object
managed by Docker (`docker volume ls`, `docker volume inspect`), with a lifecycle
independent of any container. This project uses named volumes (`mariadb_data`,
`wordpress_data`) configured with the `local` driver's bind options
(`o: bind, device: /home/fepopadi/data/...`) — this gets the best of both worlds: the
physical on-host location the subject mandates (`/home/login/data`), while still being
addressed, listed and inspected as a proper Docker volume rather than an ad hoc mount.

## Instructions

Full setup is documented in [`DEV_DOC.md`](./DEV_DOC.md) (developer / from-scratch
setup) and [`USER_DOC.md`](./USER_DOC.md) (day-to-day usage). Quick start, run inside
the project's virtual machine:

```bash
git clone <this-repository> inception && cd inception
cp srcs/.env.example srcs/.env
make
```

Then open `https://fepopadi.42.fr` in a browser (self-signed certificate warning is
expected).

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker Compose secrets](https://docs.docker.com/compose/how-tos/use-secrets/)
- [docker-library/mariadb](https://github.com/docker-library/mariadb) — source for the adapted MariaDB entrypoint
- [docker-library/wordpress](https://github.com/docker-library/wordpress) — source for the adapted WordPress entrypoint
- [docker-library/nginx](https://github.com/nginxinc/docker-nginx) — source for the adapted nginx entrypoint
- [WP-CLI documentation](https://wp-cli.org/)
- [NGINX: configuring HTTPS servers](https://nginx.org/en/docs/http/configuring_https_servers.html)
- [Mozilla SSL configuration generator](https://ssl-config.mozilla.org/)
- [Alpine Linux package index](https://pkgs.alpinelinux.org/) / [Debian package index](https://packages.debian.org/)

### Use of AI

An AI assistant (Claude Code) was used throughout this project as a review and
troubleshooting aid, not as a code generator to copy-paste blindly:

- **Code review**: auditing the Dockerfiles and entrypoint scripts against the subject's
  constraints (forbidden patterns like `tail -f`/`sleep infinity`, PID 1 handling,
  unused/dead code such as a leftover unused `ARG` and an inert init script that was
  subsequently removed).
- **Debugging**: diagnosing a live `docker compose build` failure caused by an Alpine
  package revision bump (`nginx` moving from `-r6` to `-r7` on the live mirror), and
  cross-checking every other pinned package against the current Alpine index before
  deciding to drop strict `-rX` pinning project-wide for build resilience.
- **Makefile hardening**: adding the `seed` target (secret generation via
  `openssl rand`) and fixing a permission bug in the `volumes` target when the VM's
  local login differs from the 42 login used for `/home/<login>/data`.
- **Sysadmin guidance**: general, non-project-specific advice on VirtualBox networking
  (NAT vs Bridged), SSH agent forwarding for cloning a private repository inside the VM,
  and apt/Docker installation steps on Debian.
- **Documentation**: drafting this README and `DEV_DOC.md`/`USER_DOC.md`, which were
  then reviewed against the subject and the evaluation sheet.

Every suggestion was reviewed, tested (including a full local `docker compose build`)
and understood before being kept in the project.
