#!/usr/bin/env sh
set -eu

: "${IMAGE:?Set IMAGE to the locally built image reference}"
EXPECTED_PHP_VERSION="${EXPECTED_PHP_VERSION:-8.5.9}"
PLATFORM="${PLATFORM:-}"
run_args=""
if [ -n "$PLATFORM" ]; then
  run_args="--platform $PLATFORM"
fi

run() {
  # shellcheck disable=SC2086
  docker run --rm $run_args "$IMAGE" "$@"
}

actual_version="$(run php -r 'echo PHP_VERSION;')"
[ "$actual_version" = "$EXPECTED_PHP_VERSION" ] || { echo "expected PHP $EXPECTED_PHP_VERSION, got $actual_version" >&2; exit 1; }

for module in date dom fileinfo filter hash json libxml mbstring openssl pcre PDO pdo_mysql pdo_pgsql pdo_sqlite posix session SimpleXML sodium SPL zlib intl curl; do
  run php -m | grep -Fx "$module" >/dev/null || { echo "missing PHP module: $module" >&2; exit 1; }
done

[ "$(run id -u)" != "0" ] || { echo "container runs as root" >&2; exit 1; }
run composer --version | grep -F 'Composer version 2.' >/dev/null || { echo "Composer 2 is unavailable" >&2; exit 1; }
! run sh -c 'command -v psql' || { echo "PostgreSQL client must not be present" >&2; exit 1; }
! run sh -c 'for root in /var/www /opt /srv /usr/local; do [ ! -d "$root" ] || find "$root" -iname "*simplesaml*" -print -quit; done' | grep -q . || { echo "SimpleSAMLphp payload must not be present" >&2; exit 1; }

health_dir="$(mktemp -d)"
printf '%s\n' '<?php echo "php-smoke-ok";' > "$health_dir/health.php"
chmod 755 "$health_dir"
container_id=""
cleanup() {
  [ -z "$container_id" ] || docker rm -f "$container_id" >/dev/null 2>&1 || true
  rm -f "$health_dir/health.php"
  rmdir "$health_dir" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
container_id="$(docker run -d --read-only --cap-drop=ALL --tmpfs /tmp --tmpfs /var/run/apache2:uid=33,gid=33,mode=755 --tmpfs /var/lock/apache2:uid=33,gid=33,mode=755 --mount "type=bind,src=$health_dir/health.php,dst=/var/www/html/health.php,readonly" -p 127.0.0.1::8080 $run_args "$IMAGE")"

for _ in 1 2 3 4 5 6 7 8 9 10; do
  host_port="$(docker port "$container_id" 8080/tcp | sed 's/.*://')"
  if [ "$(curl --fail --silent "http://127.0.0.1:${host_port}/health.php" 2>/dev/null || true)" = "php-smoke-ok" ]; then
    echo "image smoke test passed: $IMAGE"
    exit 0
  fi
  sleep 1
done

docker logs "$container_id" >&2 || true
echo "Apache/PHP health endpoint did not become ready on port 8080" >&2
exit 1
