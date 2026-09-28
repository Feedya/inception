# Developer Documentation

This document describes how to set up, build and operate the project as a developer.
For end-user/administrator usage (starting the site, finding credentials, day-to-day
checks), see [`USER_DOC.md`](./USER_DOC.md).

## 1. Prerequisites

- The whole project must run **inside a virtual machine** (VirtualBox, Debian 12
  "bookworm" recommended — matches the base image used by the `mariadb` service).
- Docker Engine + the Compose plugin, installed from Docker's official apt repository
  (not the Debian repo's `docker.io`/`docker-compose`, which don't ship the `docker
  compose` v2 plugin this Makefile relies on):

  ```bash
  sudo apt update
  sudo apt install -y ca-certificates curl gnupg
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt update
  sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ```

  Verify with `docker --version` and `docker compose version`.

- Optional but convenient: add your user to the `docker` group so `make`/`docker`
  commands don't need `sudo` individually (`sudo usermod -aG docker $USER`, then
  re-login).

## 2. Repository layout

```
.
├── Makefile                     # single entry point, wraps docker compose
├── secrets/                     # generated passwords (gitignored, never committed)
└── srcs/
    ├── compose.yaml
    ├── .env                     # per-machine config (gitignored)
    ├── .env.example             # template, committed
    └── requirements/
        ├── mariadb/  Dockerfile, docker-entrypoint.sh, conf/, tools/
        ├── nginx/    Dockerfile, docker-entrypoint.sh, conf/, tools/
        └── wordpress/Dockerfile, docker-entrypoint.sh, conf/
```

`srcs/` and the root `Makefile` are the only things the subject requires; everything
needed to configure the application lives under `srcs/requirements/`.

## 3. Setting up the environment from scratch

1. Clone the repository inside the VM.
2. Create your local config from the template:

   ```bash
   cp srcs/.env.example srcs/.env
   ```

   Edit `srcs/.env` and set, at minimum:

   ```
   DATA_PATH=/home/fepopadi/data
   DOMAIN_NAME=fedor.42.fr
   ```

   (replace `fepopadi` with your own 42 login — this path is where the two named
   volumes are physically stored on the host, as required by the subject).

3. Secrets (`secrets/db_password.txt`, `db_root_password.txt`, `wp_admin_password.txt`,
   `wp_user_password.txt`) do **not** need to be created manually — `make` generates
   them automatically on first run (see `make seed` below). If you already have them
   from a previous setup, they are left untouched.

## 4. Build and launch via the Makefile

| Target        | What it does |
|---------------|--------------|
| `make` / `make all` | `hosts` + `volumes` + `seed`, then `docker compose up -d --build` |
| `make up`     | Same as `all` (alias) |
| `make down`   | `docker compose down` (stops and removes containers, keeps volumes) |
| `make stop`   | Stops the containers without removing them |
| `make start`  | Restarts previously stopped containers |
| `make logs`   | Follows logs of all services (`docker compose logs -f`) |
| `make ps`     | Shows container status (`docker compose ps`) |
| `make volumes`| Creates `$(DATA_PATH)/mariadb` and `$(DATA_PATH)/wordpress` on the host, with correct ownership |
| `make seed`   | Generates any missing secret in `secrets/` with `openssl rand -hex 24` (idempotent — never overwrites an existing secret) |
| `make hosts`  | Adds `127.0.0.1 <DOMAIN_NAME>` to `/etc/hosts` if not already present |
| `make clean`  | `down` + `docker system prune -af` |
| `make fclean` | `clean` + removes the named volumes + wipes `$(DATA_PATH)` + removes the `/etc/hosts` entry |
| `make re`     | `fclean` then `all` — full clean rebuild from scratch |

`hosts` and `volumes` use `sudo` (writing to `/etc/hosts` and to `/home/<login>/`
require root) — expect a password prompt on the first `sudo` call per shell session
(cached ~15 minutes afterwards).

### Rebuilding after a configuration change

Editing `srcs/.env` (e.g. changing a service's port) and running `make up` again is
enough: `docker compose up -d --build` only recreates the containers whose
configuration changed, and named volumes are untouched — no need for `make re` (which
wipes all data) just to apply a config change.

## 5. Managing containers and volumes directly

```bash
docker compose -f srcs/compose.yaml --env-file srcs/.env ps      # container status
docker compose -f srcs/compose.yaml --env-file srcs/.env logs -f <service>
docker exec -it nginx sh                                         # shell into a container
docker network ls                                                # the "inception" bridge network
docker volume ls                                                 # mariadb_data / wordpress_data
docker volume inspect inception_mariadb_data                     # confirm the host path (/home/<login>/data/mariadb)
```

### Full reset (what the evaluator runs before grading)

```bash
docker stop $(docker ps -qa); docker rm $(docker ps -qa); docker rmi -f $(docker images -qa); docker volume rm $(docker volume ls -q); docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf /home/fepopadi/data/*
```

After this, everything must come back with a single `make` — this is the truest test
of the setup, worth rehearsing before the defense.

## 6. Data persistence

- **`wordpress_data`** (named volume) → bind-mounted to `/home/fepopadi/data/wordpress`
  on the host, mounted at `/var/www/html` in both the `wordpress` and `nginx`
  containers (nginx needs read access to serve static files directly).
- **`mariadb_data`** (named volume) → bind-mounted to `/home/fepopadi/data/mariadb` on
  the host, mounted at `/var/lib/mysql` in the `mariadb` container.
- Both are declared as Docker **named volumes** in `compose.yaml` (not bind mounts) —
  see the README's "Docker Volumes vs Bind Mounts" section for why.
- Removing containers (`make down`, or even a VM reboot) never touches this data.
  Only `make fclean` (or the evaluator's manual reset command above) wipes it — after
  that, WordPress reinstalls itself from scratch on the next `make up`, using
  `WORDPRESS_ADMIN_USER`/`WORDPRESS_USER` etc. from `.env` and the passwords in
  `secrets/`.

## 7. Troubleshooting

- **`apk add`/`apt-get install` fails with a version conflict during build**: Alpine
  and Debian repositories only ever serve the *current* revision of a package, not an
  archive of past revisions. If a Dockerfile pins an exact `-rX`/`+debXuY` revision
  that has since been superseded (typically a security patch), the build breaks. This
  project currently installs OS packages without exact revision pins for this reason;
  if you reintroduce pinning, check the live index first:
  `https://pkgs.alpinelinux.org/packages` or `apt-cache policy <package>` in a
  throwaway container.
- **`make volumes` fails with `Permission denied` under `/home/<login>`**: this happens
  if the login used in `DATA_PATH` differs from the VM's actual local user (they don't
  have to match — `<login>` refers to your 42 intra login, not necessarily your VM
  account name). `make volumes` already handles this with `sudo mkdir`+`sudo chown`.
- **`make` fails immediately with a missing variable**: `srcs/.env` doesn't exist yet —
  copy it from `srcs/.env.example` first (step 3 above).
