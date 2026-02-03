#!/usr/bin/env bash
set -euo pipefail

if docker compose version >/dev/null 2>&1; then
    DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
    DC=(docker-compose)
else
    echo "Docker Compose not found."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

if [ -f "${PROJECT_DIR}/.env" ]; then
    while IFS= read -r line || [ -n "${line}" ]; do
        case "${line}" in
            ''|\#*) continue ;;
        esac
        line="${line#export }"
        if [[ "${line}" == *"="* ]]; then
            key="${line%%=*}"
            val="${line#*=}"
            val="${val%\"}"
            val="${val#\"}"
            current="${!key:-}"
            if [ -z "${current}" ]; then
                export "${key}=${val}"
            fi
        fi
    done < "${PROJECT_DIR}/.env"
fi

WORDPRESS_PORT="${WORDPRESS_PORT:-8080}"

echo "Building image..."
"${DC[@]}" build wordpress

echo "Starting services..."
"${DC[@]}" up -d --force-recreate

wait_for_health() {
    local service="$1"
    local timeout="${2:-180}"
    local elapsed=0
    local cid

    cid="$("${DC[@]}" ps -q "${service}")"
    if [ -z "${cid}" ]; then
        echo "Service ${service} not running."
        exit 1
    fi

    while true; do
        local status
        status="$(docker inspect -f '{{.State.Health.Status}}' "${cid}" 2>/dev/null || echo "unknown")"
        if [ "${status}" = "healthy" ]; then
            echo "${service} is healthy."
            return
        fi
        if [ "${status}" = "unhealthy" ]; then
            echo "${service} is unhealthy."
            "${DC[@]}" logs --tail=200 "${service}"
            exit 1
        fi

        sleep 2
        elapsed=$((elapsed + 2))
        if [ "${elapsed}" -ge "${timeout}" ]; then
            echo "Timeout waiting for ${service} health."
            "${DC[@]}" logs --tail=200 "${service}"
            exit 1
        fi
    done
}

wait_for_health db 180
wait_for_health redis 180
wait_for_health wordpress 180

echo "Checking HTTP endpoints..."
curl -fsS "http://localhost:${WORDPRESS_PORT}/" >/dev/null
curl -fsS "http://localhost:${WORDPRESS_PORT}/wp-login.php" >/dev/null

echo "Checking plugin/theme mounts..."
"${DC[@]}" exec -T wordpress test -f /var/www/html/wp-content/themes/moinho-novo/style.css
"${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/uploads
"${DC[@]}" exec -T wordpress test -f /opt/seed/db.sql

if [ -f "${PROJECT_DIR}/oxygen-4.9.5.zip" ]; then
    "${DC[@]}" exec -T wordpress test -f /opt/oxygen/oxygen.zip
    "${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/plugins/oxygen
else
    echo "Oxygen zip not found, skipping Oxygen plugin checks."
fi

if [ -f "${PROJECT_DIR}/contact-form-7.6.1.4.zip" ]; then
    "${DC[@]}" exec -T wordpress test -f /opt/plugins/contact-form-7.zip
    "${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/plugins/contact-form-7
else
    echo "Contact Form 7 zip not found, skipping Contact Form 7 checks."
fi

if [ -f "${PROJECT_DIR}/all-in-one-wp-migration-unlimited-main.zip" ]; then
    "${DC[@]}" exec -T wordpress test -f /opt/plugins/all-in-one-wp-migration-unlimited-main.zip
    "${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/plugins/all-in-one-wp-migration-unlimited-main
else
    echo "All-in-One WP Migration zip not found, skipping its checks."
fi

if [ -f "${PROJECT_DIR}/wp-optimize.4.4.1.zip" ]; then
    "${DC[@]}" exec -T wordpress test -f /opt/plugins/wp-optimize.zip
    "${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/plugins/wp-optimize
else
    echo "WP-Optimize zip not found, skipping its checks."
fi

if [ -f "${PROJECT_DIR}/defender-security.5.9.0.zip" ]; then
    "${DC[@]}" exec -T wordpress test -f /opt/plugins/defender-security.zip
    "${DC[@]}" exec -T wordpress test -d /var/www/html/wp-content/plugins/defender-security
else
    echo "Defender Security zip not found, skipping its checks."
fi

echo "Checking Redis extension..."
redis_ext="$("${DC[@]}" exec -T wordpress php -r "echo extension_loaded('redis') ? 'yes' : 'no';")"
if [ "${redis_ext}" != "yes" ]; then
    echo "Redis PHP extension is not loaded."
    exit 1
fi

echo "Checking Redis connectivity..."
redis_ping="$("${DC[@]}" exec -T wordpress php -r "\$host = getenv('WORDPRESS_REDIS_HOST') ?: 'redis'; \$port = (int)(getenv('WORDPRESS_REDIS_PORT') ?: 6379); \$redis = new Redis(); \$redis->connect(\$host, \$port, 2.5); echo \$redis->ping();")"
if [[ "${redis_ping}" != *"PONG"* && "${redis_ping}" != "1" ]]; then
    echo "Redis ping failed: ${redis_ping}"
    exit 1
fi

echo "Checking DB tables..."
db_count="$("${DC[@]}" exec -T wordpress bash -lc 'mysql --skip-ssl -h "$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -N -s -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=\"$WORDPRESS_DB_NAME\";"')"
db_count="$(echo "${db_count:-0}" | tr -d '\r')"
if [ "${db_count}" -lt 1 ]; then
    echo "Database has no tables."
    exit 1
fi

echo "Checking Oxygen activation..."
if [ -f "${PROJECT_DIR}/oxygen-4.9.5.zip" ]; then
    oxygen_active="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; require_once ABSPATH.'wp-admin/includes/plugin.php'; echo is_plugin_active('oxygen/functions.php') ? 'active' : 'inactive';")"
    if [ "${oxygen_active}" != "active" ]; then
        echo "Oxygen plugin is not active."
        exit 1
    fi
else
    echo "Skipping Oxygen activation check (zip missing)."
fi

echo "Checking Contact Form 7 activation..."
if [ -f "${PROJECT_DIR}/contact-form-7.6.1.4.zip" ]; then
    cf7_active="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; require_once ABSPATH.'wp-admin/includes/plugin.php'; echo is_plugin_active('contact-form-7/wp-contact-form-7.php') ? 'active' : 'inactive';")"
    if [ "${cf7_active}" != "active" ]; then
        echo "Contact Form 7 plugin is not active."
        exit 1
    fi
else
    echo "Skipping Contact Form 7 activation check (zip missing)."
fi

echo "Skipping All-in-One WP Migration activation check (manual activation)."

echo "Checking WP-Optimize activation..."
if [ -f "${PROJECT_DIR}/wp-optimize.4.4.1.zip" ]; then
    wp_optimize_file="${WP_OPTIMIZE_PLUGIN_FILE:-wp-optimize/wp-optimize.php}"
    wp_optimize_exists="$("${DC[@]}" exec -T wordpress bash -lc "test -f /var/www/html/wp-content/plugins/${wp_optimize_file} && echo yes || echo no")"
    if [ "${wp_optimize_exists}" = "yes" ]; then
        wp_optimize_active="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; require_once ABSPATH.'wp-admin/includes/plugin.php'; echo is_plugin_active('${wp_optimize_file}') ? 'active' : 'inactive';")"
        if [ "${wp_optimize_active}" != "active" ]; then
            echo "WP-Optimize plugin is not active."
            exit 1
        fi
    else
        echo "WP-Optimize plugin file not found (${wp_optimize_file})."
        exit 1
    fi
else
    echo "Skipping WP-Optimize activation check (zip missing)."
fi

echo "Checking Defender Security activation..."
if [ -f "${PROJECT_DIR}/defender-security.5.9.0.zip" ]; then
    defender_file="${DEFENDER_PLUGIN_FILE:-defender-security/wp-defender.php}"
    defender_exists="$("${DC[@]}" exec -T wordpress bash -lc "test -f /var/www/html/wp-content/plugins/${defender_file} && echo yes || echo no")"
    if [ "${defender_exists}" = "yes" ]; then
        defender_active="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; require_once ABSPATH.'wp-admin/includes/plugin.php'; echo is_plugin_active('${defender_file}') ? 'active' : 'inactive';")"
        if [ "${defender_active}" != "active" ]; then
            echo "Defender Security plugin is not active."
            exit 1
        fi
    else
        echo "Defender Security plugin file not found (${defender_file})."
        exit 1
    fi
else
    echo "Skipping Defender Security activation check (zip missing)."
fi

echo "Checking Defender Security tables..."
if [ -f "${PROJECT_DIR}/defender-security.5.9.0.zip" ]; then
    defender_table="$("${DC[@]}" exec -T wordpress bash -lc 'mysql --skip-ssl -h "$WORDPRESS_DB_HOST" -u "$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -N -s -e "SHOW TABLES LIKE \"${WORDPRESS_TABLE_PREFIX}defender_lockout\";" "$WORDPRESS_DB_NAME"')"
    defender_table="$(echo "${defender_table:-}" | tr -d '\r')"
    if [ -z "${defender_table}" ]; then
        echo "Defender Security table wp_defender_lockout not found."
        exit 1
    fi
else
    echo "Skipping Defender Security table check (zip missing)."
fi

echo "Checking Redis Cache activation..."
redis_cache_active="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; require_once ABSPATH.'wp-admin/includes/plugin.php'; echo is_plugin_active('redis-cache/redis-cache.php') ? 'active' : 'inactive';")"
if [ "${redis_cache_active}" != "active" ]; then
    echo "Redis Cache plugin is not active."
    exit 1
fi

echo "Checking Redis object-cache drop-in..."
"${DC[@]}" exec -T wordpress test -f /var/www/html/wp-content/object-cache.php

echo "Checking Opcache extension..."
opcache_ext="$("${DC[@]}" exec -T wordpress php -r "echo function_exists('opcache_get_status') ? 'yes' : 'no';")"
if [ "${opcache_ext}" != "yes" ]; then
    echo "Opcache extension is not loaded."
    exit 1
fi

license_set="$("${DC[@]}" exec -T wordpress bash -lc 'test -n "$OXYGEN_LICENSE_KEY" && echo yes || echo no')"
if [ "${license_set}" = "yes" ]; then
    license_status="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; echo (string)get_option('oxygen_license_status');")"
    if [ "${license_status}" != "valid" ]; then
        echo "Oxygen license not valid (status=${license_status})."
        exit 1
    fi
else
    echo "OXYGEN_LICENSE_KEY not set, skipping license check."
fi

echo "Checking theme activation..."
theme_slug="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; echo (string)get_option('stylesheet');")"
if [ "${theme_slug}" != "moinho-novo" ]; then
    echo "Theme not active (expected moinho-novo, got ${theme_slug})."
    exit 1
fi

echo "Checking permalinks..."
permalink_structure="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; echo (string)get_option('permalink_structure');")"
if [ -z "${permalink_structure}" ]; then
    echo "Permalink structure is empty."
    exit 1
fi

rewrite_count="$("${DC[@]}" exec -T wordpress php -r "require '/var/www/html/wp-load.php'; \$rules = get_option('rewrite_rules'); echo is_array(\$rules) ? count(\$rules) : 0;")"
rewrite_count="$(echo "${rewrite_count:-0}" | tr -d '\r')"
if [ "${rewrite_count}" -lt 1 ]; then
    echo "Rewrite rules not generated."
    exit 1
fi

echo "Checking uploads write/read..."
upload_rel="uploads/.verify-$(date +%s).txt"
"${DC[@]}" exec -T wordpress bash -lc "printf 'ok' > /var/www/html/wp-content/${upload_rel}"
if [ ! -f "${PROJECT_DIR}/${upload_rel}" ]; then
    echo "Uploads bind mount not reflecting on host."
    exit 1
fi
"${DC[@]}" exec -T wordpress rm -f "/var/www/html/wp-content/${upload_rel}"

echo "All checks passed."
