#!/bin/bash
# update_extra_plugins.sh - re-download the extra plugins listed in
# /app/plugins.json (".extra") from GitHub "master" and replace their
# installed copies under /data/plugins/.
#
#   docker exec <container> bin/update_extra_plugins.sh
#
# Scope: plugin files only. The enabled-plugins list lives in
# /config/roundcubemail/extra.inc.php which is generated once at first start
# and never rewritten - if a repo was ADDED to .extra and is not installed
# yet, remove extra.inc.php and restart the container to regenerate it.

set -u

staging=/data/x
status=0

rm -rf "$staging"
mkdir -p "$staging"

for repo in $(jq -r '.extra[] // empty' /app/plugins.json); do
    name=${repo##*/}
    echo "*** updating ${repo} ..."

    tarball="$staging/${name}.tar.gz"
    if ! curl -fsSL -o "$tarball" "https://github.com/${repo}/archive/master.tar.gz"; then
        echo "!!! download failed: ${repo}" >&2
        status=1
        continue
    fi

    dest="$staging/${name}"
    mkdir -p "$dest"
    if ! tar --strip-components=1 -xzf "$tarball" -C "$dest" || [[ ! -f "${dest}/composer.json" ]]; then
        echo "!!! bad tarball or missing composer.json: ${repo}" >&2
        rm -rf "$tarball" "$dest"
        status=1
        continue
    fi

    # plugin dir name is the tail of the composer name (same rule as setup)
    origin=$(jq -r '.name | split("/")[-1]' "${dest}/composer.json")
    if [[ -n "${origin}" && "${origin}" != "null" && "${origin}" != "${name}" ]]; then
        mv "$dest" "$staging/${origin}"
        name="${origin}"
        dest="$staging/${name}"
    fi

    if [[ ! -d "/data/plugins/${name}" ]]; then
        echo "--- not installed, skipped: ${name} (regenerate extra.inc.php to add it)"
        continue
    fi

    if ! rsync -rlD --delete "${dest}/" "/data/plugins/${name}/"; then
        echo "!!! replace failed: ${name}" >&2
        status=1
        continue
    fi
    lsiown -R abc:abc "/data/plugins/${name}"
    echo "<<< updated: ${name}"
done

rm -rf "$staging"

# reload php-fpm so opcache picks up new files immediately; non-fatal
if ! s6-svc -t /run/service/svc-php-fpm; then
    echo "--- note: could not reload php-fpm, new code may take effect later"
fi

exit $status
