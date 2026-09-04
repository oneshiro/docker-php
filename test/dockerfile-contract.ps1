$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dockerfile = Get-Content -Raw (Join-Path $root 'Dockerfile')
$workflow = Join-Path $root '.github/workflows/container.yml'

foreach ($required in @(
  'php@sha256:de13b730d81098236cde5fe90810e1572dc5c51cd190f83024ccf9e7a142ec05',
  'apt-get upgrade -y', 'docker-php-ext-install', 'libldap2-dev', 'libmemcached-dev', 'libxml2-dev', 'libsqlite3-dev',
  'intl', 'ldap', 'mbstring', 'pdo_mysql', 'pdo_pgsql', 'pdo_sqlite', 'simplexml',
  'pecl install memcached-3.1.5', 'docker-php-ext-enable memcached',
  'predis/predis:1.1.10', '/opt/predis', 'libldap-2.4-2', 'libmemcached11',
  'USER www-data', 'EXPOSE 8080',
  'COPY --from=composer/composer:2.2-bin@sha256:47adfdf4370e7ec65f826166d563752ba2f4afedf499a9f963b0a04d5c38f05c /composer /usr/local/bin/composer'
)) {
  if ($dockerfile -notmatch [regex]::Escape($required)) { throw "Dockerfile contract missing: $required" }
}

if ($dockerfile -match 'libonig-(dev|5)') { throw 'Dockerfile must use PHP 7.3 bundled Oniguruma for mbstring' }
if ($dockerfile -match '(?i)simplesaml') { throw 'Dockerfile must not bundle SimpleSAMLphp' }

$compose = Join-Path $root 'compose.yaml'
if (-not (Test-Path $compose)) { throw 'Compose service definition missing: compose.yaml' }
$composeContent = Get-Content -Raw $compose
foreach ($required in @('build:', '80:8080')) {
  if ($composeContent -notmatch [regex]::Escape($required)) { throw "Compose contract missing: $required" }
}

foreach ($path in @('docker/apache/000-default.conf', 'docker/apache/ports.conf', 'docker/php/conf.d/zz-runtime.ini', 'test/image-smoke.sh')) {
  if (-not (Test-Path (Join-Path $root $path))) { throw "Required runtime file missing: $path" }
}

$smokeTest = Get-Content -Raw (Join-Path $root 'test/image-smoke.sh')
if ($smokeTest -cnotmatch '\bSimpleXML\b') { throw 'Image smoke contract missing case-sensitive PHP module name: SimpleXML' }
foreach ($required in @('health.php', 'php-smoke-ok', 'type=bind', 'ldap', 'memcached', '/opt/predis/vendor/autoload.php')) {
  if ($smokeTest -notmatch [regex]::Escape($required)) { throw "Image smoke health contract missing: $required" }
}
if ($smokeTest -match '(?i)simplesaml') { throw 'Image smoke test must not depend on SimpleSAMLphp' }

$apacheRuntimeConfig = Get-Content -Raw (Join-Path $root 'docker/apache/zz-runtime.conf')
if ($apacheRuntimeConfig -notmatch '(?m)^ServerName localhost\r?$') { throw 'Apache runtime contract missing global ServerName' }

$virtualHostConfig = Get-Content -Raw (Join-Path $root 'docker/apache/000-default.conf')
if ($virtualHostConfig -match '(?i)simplesaml') { throw 'Apache virtual host must not expose SimpleSAMLphp' }

if (Test-Path $workflow) {
  $content = Get-Content -Raw $workflow
  foreach ($required in @('linux/amd64', 'linux/arm64', 'provenance: mode=max', 'sbom: true', 'CRITICAL,HIGH')) {
    if ($content -notmatch [regex]::Escape($required)) { throw "Workflow contract missing: $required" }
  }
  foreach ($required in @('Report all local image vulnerabilities', 'Enforce fixable local image vulnerabilities', 'Report all published vulnerabilities', 'Enforce fixable published vulnerabilities')) {
    if ($content -notmatch [regex]::Escape($required)) { throw "Workflow vulnerability policy missing: $required" }
  }
  if ([regex]::Matches($content, 'ignore-unfixed: true').Count -ne 2) { throw 'Workflow must gate fixable vulnerabilities in validation and publish jobs' }
}

Write-Host 'Static Docker contract passed.'
