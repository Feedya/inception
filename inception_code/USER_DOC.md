# User Documentation

This document explains, in simple terms, how to use the Inception stack as an end user
or administrator. For setup from scratch and developer commands, see
[`DEV_DOC.md`](./DEV_DOC.md).

## 1. What services are provided

The stack is three containers working together, behind a single web address:

| Service    | Role |
|------------|------|
| **nginx**    | The only door into the infrastructure. Serves the site over HTTPS (port 443 only, TLSv1.2/1.3), forwards PHP requests to WordPress. |
| **wordpress**| Runs the WordPress site itself (PHP-FPM). Not reachable directly from outside — only nginx talks to it. |
| **mariadb**  | The database behind WordPress (posts, users, settings). Not reachable directly from outside either. |

The site is available at **`https://fepopadi.42.fr`** (replace with your own login if
different). Visiting `http://fepopadi.42.fr` (plain HTTP, port 80) must **not** work —
nginx only listens on 443.

## 2. Starting and stopping the project

Run these from the repository root, inside the virtual machine:

```bash
make          # builds (if needed) and starts everything
make stop     # stops the containers, keeps them (and all data) in place
make start    # restarts previously stopped containers
make down     # stops and removes the containers (data is kept, only containers go)
```

After a **VM reboot**, the containers do not start automatically — run `make` (or
`make up`) again. Nothing is lost: WordPress and the database come back exactly as
they were, since their data lives in persistent volumes, not in the containers
themselves.

## 3. Accessing the website and the administration panel

- **Website**: `https://fepopadi.42.fr`
- **Admin dashboard**: `https://fepopadi.42.fr/wp-admin`

Your browser will warn about the certificate ("not trusted" / "self-signed") — this is
expected, the subject only requires a valid TLSv1.2/1.3 connection, not a
publicly-trusted certificate. Accept/continue past the warning.

Two WordPress accounts exist:

- An **administrator** account (username in `srcs/.env` as `WORDPRESS_ADMIN_USER`,
  currently `fepopadi`) — full access to `/wp-admin`. Its username deliberately does
  **not** contain "admin", as required by the subject.
- A regular **editor** account (`WORDPRESS_USER` in `srcs/.env`, currently `visitor`) —
  can log in and publish/edit content, but has no admin dashboard access.

## 4. Locating and managing credentials

All passwords are generated automatically (never hardcoded) and stored as plain text
files under `secrets/` at the repository root — **never committed to git**
(`.gitignore` excludes `secrets/*`):

| File | Belongs to |
|------|-----------|
| `secrets/wp_admin_password.txt`  | WordPress administrator (`WORDPRESS_ADMIN_USER`) |
| `secrets/wp_user_password.txt`   | WordPress regular user (`WORDPRESS_USER`) |
| `secrets/db_password.txt`        | MariaDB application user (`MYSQL_USER`, used by WordPress itself) |
| `secrets/db_root_password.txt`   | MariaDB root user |

Non-sensitive settings (domain name, ports, usernames, database name) live in
`srcs/.env` instead — see `srcs/.env.example` for the full list of variables.

If `secrets/*.txt` don't exist yet, running `make` creates them automatically
(`make seed`, using `openssl rand`) — they are only generated once and never
overwritten on subsequent runs, so existing WordPress/MariaDB logins keep working.

## 5. Checking that services are running correctly

```bash
make ps
```

All three containers (`nginx`, `wordpress`, `mariadb`) should show as `running`
(and `healthy` for `mariadb`/`wordpress`, which have healthchecks). Equivalent direct
command: `docker compose -f srcs/compose.yaml --env-file srcs/.env ps`.

Other quick checks:

```bash
# Website responds over HTTPS
curl -k https://fepopadi.42.fr

# Plain HTTP must be refused (no server listening on port 80)
curl http://fepopadi.42.fr

# TLS version in use
openssl s_client -connect fepopadi.42.fr:443 -tls1_2 </dev/null   # should succeed
openssl s_client -connect fepopadi.42.fr:443 -tls1_1 </dev/null   # should fail/refuse

# Follow logs if something looks wrong
make logs
```

To log into the database directly (e.g. to confirm it isn't empty):

```bash
docker exec -it mariadb mariadb -u root -p wordpress
# password: contents of secrets/db_root_password.txt
```
