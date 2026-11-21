# docker-roundcubemail

Docker image for [Roundcube Webmail](https://roundcube.net), built on top of
[linuxserver/baseimage-alpine-nginx](https://github.com/linuxserver/docker-baseimage-alpine-nginx)
(s6-overlay, nginx, PHP 8.3-fpm, Alpine 3.21).

The Roundcube release tarball is GPG-verified against the official release key
during the image build.

## Images

- Registry: [`ghcr.io/wu-wu/roundcubemail`](https://github.com/Wu-Wu/docker-roundcubemail/pkgs/container/roundcubemail)
- Tags: `<roundcube-version>-re<N>` (e.g. `1.6.21-re1`) plus `latest`
- Architectures: `linux/amd64`, `linux/arm64`

The `-re<N>` suffix is a revision of the image itself: bumping it rebuilds the
same Roundcube version with refreshed base packages or image fixes.

## Quick start

```yaml
services:
  roundcube:
    image: ghcr.io/wu-wu/roundcubemail:latest
    env_file: ./roundcube.env
    volumes:
      - ./x/config:/config
      - ./x/data:/data
    ports:
      - "127.0.0.1:8081:80"
    restart: unless-stopped
```

Minimal `roundcube.env`:

```
ROUNDCUBEMAIL_IMAP_URL=tls://imap.example.com:143
ROUNDCUBEMAIL_SMTP_URL=tls://smtp.example.com:587
```

The web UI listens on port 80 inside the container; TLS is expected to be
terminated by a reverse proxy in front of it.

## Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `ROUNDCUBEMAIL_DB_URL` | `sqlite` | Roundcube `db_dsnw`. The special value `sqlite` maps to `/data/db/roundcubemail.db`; any other value is used verbatim as a DSN (`mysql://…`, `postgres://…`, …). |
| `ROUNDCUBEMAIL_IMAP_URL` | `tls://localhost:143` | IMAP server, e.g. `tls://imap.example.com:143` or `ssl://imap.example.com:993`. |
| `ROUNDCUBEMAIL_SMTP_URL` | `tls://localhost:587` | SMTP server; `smtp_user`/`smtp_pass` are bound to the login credentials (`%u`/`%p`). |
| `ROUNDCUBEMAIL_SIEVE_URL` | `tls://localhost:4190` | ManageSieve server for sieve settings. |

The mail configuration file is generated only if at least one of the three
mail variables is set. The standard linuxserver variables (`PUID`, `PGID`,
`TZ`) are supported as well.

## Volumes

| Path | Contents |
| --- | --- |
| `/config` | generated Roundcube config (`/config/roundcubemail/*.inc.php`) and logs (`/config/log/roundcubemail`) |
| `/data` | mutable app data: `plugins/`, `skins/`, `temp/`, `db/`, `enigma/` |

## Configuration model

On first start the container generates `/config/roundcubemail/`:

- `secret.inc.php` — generated `des_key`
- `db.inc.php`, `mail.inc.php` — from the environment variables above
- `logging.inc.php` — file logging, debug enabled
- `plugins.inc.php`, `extra.inc.php` — see [Plugins](#plugins)
- `custom.inc.php` — image defaults (elastic skin, pspell spellchecker with
  en/ru dictionaries, `temp_dir`, 2FA enrollment, …)

`config.inc.php` only `include`s those files. **Existing files are never
overwritten**, so put your own overrides into `custom.inc.php` (or a separate
file included from `config.inc.php`) and restart. The database schema is
migrated automatically on start (`initdb.sh --update`).

## Plugins

Bundled Roundcube plugins are loaded from `/data/plugins`. In addition, on
first start the following plugins are downloaded from their GitHub `master`
branches (list: `rootfs/app/plugins.json`):

- `roundcube-easy-unsubscribe` (SS88UK)
- `twofactor_gauthenticator` (alexandregz) — enrollment is forced

`enigma`, `database_attachments`, `redundant_attachments`, `persistent_login`
and `account_details` are disabled (the latter two upstream repos are archived).

To refresh the extra plugins on a running container from their `master`
branches (files only; the enabled list is not re-generated):

```
docker exec <container> bin/update_extra_plugins.sh
```

## Building locally

```
make build REGISTRY=<your-registry> REPOSITORY=<repo>   # buildx multi-arch + push
```

A plain `docker build .` also works. Build args: `APP_VERSION` (Roundcube
release to install, e.g. `1.6.21`; empty means "latest release"),
`BUILD_VERSION`, `BUILD_DATE`, `BUILD_REVISION`.

## CI/CD

Pushing a version tag (e.g. `1.6.21-re2`) triggers the workflow: it builds the
multi-arch image, pushes it to `ghcr.io` and creates the GitHub release. A
daily schedule re-checks for tags that were missed, and pull requests build
the image without publishing.
