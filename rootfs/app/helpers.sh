#!/usr/bin/with-contenv bash
# shellcheck shell=bash

ensure_included() {
    grep -qF /config/roundcubemail/${1}.inc.php \
        /config/roundcubemail/config.inc.php ||
        cat >>/config/roundcubemail/config.inc.php <<EOT
include('/config/roundcubemail/${1}.inc.php');
EOT
}

fail() { 
    echo "   FAIL (${1})"
}
okay() { 
    echo "   OKAY" 
}
