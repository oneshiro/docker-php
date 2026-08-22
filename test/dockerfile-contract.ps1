$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dockerfile = Get-Content -Raw (Join-Path $root 'Dockerfile')
$workflow = Join-Path $root '.github/workflows/container.yml'

foreach ($required in @(
  'php@sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b',
  'docker-php-ext-install', 'intl', 'pdo_mysql', 'pdo_pgsql', 'USER www-data', 'EXPOSE 8080',
  'COPY --from=composer/composer:2-bin /composer /usr/local/bin/composer'
)) {
  if ($dockerfile -notmatch [regex]::Escape($required)) { throw "Dockerfile contract missing: $required" }
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

if (Test-Path $workflow) {
  $content = Get-Content -Raw $workflow
  foreach ($required in @('linux/amd64', 'linux/arm64', 'provenance: mode=max', 'sbom: true', 'CRITICAL,HIGH')) {
    if ($content -notmatch [regex]::Escape($required)) { throw "Workflow contract missing: $required" }
  }
}

Write-Host 'Static Docker contract passed.'
