$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dockerfile = Get-Content -Raw (Join-Path $root 'Dockerfile')
$workflow = Join-Path $root '.github/workflows/container.yml'

foreach ($required in @(
  'php@sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b',
  'apt-get upgrade -y', 'docker-php-ext-install',
  'docker-php-ext-configure ldap --with-ldap', 'docker-php-ext-configure zip --with-zip',
  'libxml2-dev', 'libldap2-dev', 'libldap-2.5-0', 'libzip-dev', 'libzip4', 'unzip',
  'bcmath', 'intl', 'ldap', 'pdo_mysql', 'pdo_pgsql', 'simplexml',
  'USER www-data', 'EXPOSE 8080',
  'COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer'
)) {
  if ($dockerfile -notmatch [regex]::Escape($required)) { throw "Dockerfile contract missing: $required" }
}

if ($dockerfile -notmatch 'docker-php-ext-install [^\r\n]*\bzip\b') {
  throw 'Dockerfile contract missing PHP zip extension installation'
}

if ($dockerfile -notmatch 'apt-mark manual (?=[^\r\n]*\blibldap-2\.5-0\b)(?=[^\r\n]*\blibzip4\b)(?=[^\r\n]*\bunzip\b)') {
  throw 'Dockerfile contract missing retained OpenLDAP/libzip runtime dependencies or unzip'
}

if ($dockerfile -match [regex]::Escape('liblber-2.5-0')) {
  throw 'Dockerfile must not reference nonexistent Bookworm package: liblber-2.5-0'
}

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
foreach ($required in @('health.php', 'php-smoke-ok', 'type=bind')) {
  if ($smokeTest -notmatch [regex]::Escape($required)) { throw "Image smoke health contract missing: $required" }
}

$apacheRuntimeConfig = Get-Content -Raw (Join-Path $root 'docker/apache/zz-runtime.conf')
if ($apacheRuntimeConfig -notmatch '(?m)^ServerName localhost$') { throw 'Apache runtime contract missing global ServerName' }

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
