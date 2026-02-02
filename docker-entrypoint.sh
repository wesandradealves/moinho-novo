#!/usr/bin/env bash
set -euo pipefail

: "${WORDPRESS_DB_HOST:=db}"
: "${WORDPRESS_DB_NAME:=wordpress}"
: "${WORDPRESS_DB_USER:=wordpress}"
: "${WORDPRESS_DB_PASSWORD:=wordpress}"
: "${WORDPRESS_TABLE_PREFIX:=wp_}"
: "${WORDPRESS_DEBUG:=0}"
: "${WORDPRESS_DB_DUMP:=/opt/seed/db.sql}"

copy_wordpress() {
    if [ ! -f /var/www/html/wp-includes/version.php ]; then
        echo "Copying WordPress into /var/www/html..."
        rm -f /var/www/html/index.html || true
        mkdir -p /var/www/html
        cp -a /usr/src/wordpress/. /var/www/html/
        chown -R www-data:www-data /var/www/html
    fi
}

generate_wp_config() {
    if [ -f /var/www/html/wp-config.php ]; then
        return
    fi

    echo "Creating wp-config.php..."

    salts="$(curl -fsSL https://api.wordpress.org/secret-key/1.1/salt/ || true)"
    if [ -z "${salts}" ]; then
        salts="$(cat <<'PHP'
define('AUTH_KEY',         'change-me');
define('SECURE_AUTH_KEY',  'change-me');
define('LOGGED_IN_KEY',    'change-me');
define('NONCE_KEY',        'change-me');
define('AUTH_SALT',        'change-me');
define('SECURE_AUTH_SALT', 'change-me');
define('LOGGED_IN_SALT',   'change-me');
define('NONCE_SALT',       'change-me');
PHP
)"
    fi

    wp_debug=false
    case "${WORDPRESS_DEBUG}" in
        1|true|TRUE|yes|YES) wp_debug=true ;;
    esac

    db_name="$(php -r 'echo var_export(getenv("WORDPRESS_DB_NAME"), true);')"
    db_user="$(php -r 'echo var_export(getenv("WORDPRESS_DB_USER"), true);')"
    db_pass="$(php -r 'echo var_export(getenv("WORDPRESS_DB_PASSWORD"), true);')"
    db_host="$(php -r 'echo var_export(getenv("WORDPRESS_DB_HOST"), true);')"
    table_prefix="$(php -r 'echo var_export(getenv("WORDPRESS_TABLE_PREFIX"), true);')"

    cat > /var/www/html/wp-config.php <<PHP
<?php
define('DB_NAME', ${db_name});
define('DB_USER', ${db_user});
define('DB_PASSWORD', ${db_pass});
define('DB_HOST', ${db_host});
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

${salts}

\$table_prefix = ${table_prefix};

define('WP_DEBUG', ${wp_debug});
define('FS_METHOD', 'direct');

if ( ! defined('ABSPATH') ) {
    define('ABSPATH', __DIR__ . '/');
}

require_once ABSPATH . 'wp-settings.php';
PHP

    chown www-data:www-data /var/www/html/wp-config.php
}

install_oxygen_plugin() {
    local zip_source=""
    local cleanup_zip=0

    if [ -n "${OXYGEN_ZIP_PATH:-}" ] && [ -f "${OXYGEN_ZIP_PATH}" ]; then
        zip_source="${OXYGEN_ZIP_PATH}"
    elif [ -n "${OXYGEN_ZIP_URL:-}" ]; then
        zip_source="/tmp/oxygen.zip"
        cleanup_zip=1
        curl -fsSL "${OXYGEN_ZIP_URL}" -o "${zip_source}"
    else
        return
    fi

    echo "Ensuring Oxygen plugin is installed..."

    if [ -n "${OXYGEN_ZIP_SHA256:-}" ]; then
        echo "${OXYGEN_ZIP_SHA256}  ${zip_source}" | sha256sum -c -
    fi

    plugin_root="/var/www/html/wp-content/plugins"
    mkdir -p "${plugin_root}"

    # Detect top-level folders inside the zip.
    mapfile -t top_dirs < <(unzip -Z1 "${zip_source}" | awk -F/ 'NF>1{print $1}' | sort -u)

    need_extract=1
    if [ "${#top_dirs[@]}" -gt 0 ]; then
        need_extract=0
        for dir in "${top_dirs[@]}"; do
            if [ ! -d "${plugin_root}/${dir}" ]; then
                need_extract=1
                break
            fi
        done
    fi

    if [ "${need_extract}" -eq 1 ]; then
        unzip -qo "${zip_source}" -d "${plugin_root}"
    fi

    if [ "${cleanup_zip}" -eq 1 ]; then
        rm -f "${zip_source}"
    fi

    chown -R www-data:www-data "${plugin_root}"
}

mysql_args() {
    local host="${WORDPRESS_DB_HOST}"
    local port=""
    if [[ "${host}" == *:* ]]; then
        port="${host#*:}"
        host="${host%%:*}"
    fi

    local args=( -h "${host}" -u "${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" --skip-ssl )
    if [ -n "${port}" ] && [ "${port}" != "${host}" ]; then
        args+=( -P "${port}" )
    fi

    echo "${args[@]}"
}

db_table_count() {
    local args
    args=($(mysql_args))
    mysql "${args[@]}" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${WORDPRESS_DB_NAME}';" 2>/dev/null || echo "0"
}

import_db_if_empty() {
    if [ ! -f "${WORDPRESS_DB_DUMP}" ]; then
        return
    fi

    local count
    count="$(db_table_count | tr -d '\r' | tail -n 1)"
    if [ "${count}" != "0" ]; then
        return
    fi

    echo "Importing database dump from ${WORDPRESS_DB_DUMP}..."
    local args
    args=($(mysql_args))

    if [[ "${WORDPRESS_DB_DUMP}" == *.gz ]]; then
        gunzip -c "${WORDPRESS_DB_DUMP}" | mysql "${args[@]}" "${WORDPRESS_DB_NAME}"
    else
        mysql "${args[@]}" "${WORDPRESS_DB_NAME}" < "${WORDPRESS_DB_DUMP}"
    fi

    echo "Flushing permalinks..."
    php -r "require '/var/www/html/wp-load.php'; if (function_exists('flush_rewrite_rules')) { flush_rewrite_rules(true); }"
}

copy_wordpress

# Ensure uploads dir exists even when mounted from host.
mkdir -p /var/www/html/wp-content/uploads
chown -R www-data:www-data /var/www/html/wp-content/uploads

generate_wp_config
install_oxygen_plugin
import_db_if_empty

exec "$@"
