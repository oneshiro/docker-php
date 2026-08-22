# PHP 8.5.9 Apache runtime

Docker image สำหรับ PHP 8.5.9 + Apache ที่รันด้วยผู้ใช้ `www-data` ภายใน container และมี PHP Composer 2 พร้อมใช้งาน เหมาะเป็น runtime สำหรับ consumer ของ SimpleSAMLphp ในอนาคต แต่ image นี้ **ไม่มี** SimpleSAMLphp, application code, PostgreSQL server/client tooling, database data, credentials, keys หรือ application configuration

## Build และ Run

สร้างและเปิด service ผ่าน host port 80:

```sh
docker compose up --build -d
```

ตรวจสอบว่า container ทำงานและเรียกผ่าน `http://localhost/` ได้:

```sh
docker compose ps
curl --fail http://localhost/
```

หยุด service:

```sh
docker compose down
```

ภายใน container Apache ยังฟังที่ port `8080`; `compose.yaml` map `80:8080` เพื่อให้ผู้ใช้เข้าผ่าน host port 80 โดยไม่ต้องให้ process ที่เป็น non-root bind privileged port

## ตรวจสอบ Composer

ตรวจสอบ version ของ Composer ใน PHP container:

```sh
docker compose run --rm php composer --version
```

Composer ใช้สำหรับจัดการ dependency ของ application ที่ mount หรือ build เพิ่มจาก image นี้ ไม่ได้ติดตั้ง application หรือ dependency ใดไว้ล่วงหน้า

## เลือกฐานข้อมูลและตั้งค่า environment

Image นี้มี PDO driver สำหรับฐานข้อมูลหลักดังนี้:

- MySQL/MariaDB: `pdo_mysql` ใช้ DSN เช่น `mysql:host=mysql;port=3306;dbname=app;charset=utf8mb4`
- PostgreSQL: `pdo_pgsql` ใช้ DSN เช่น `pgsql:host=postgres;port=5432;dbname=app`
- SQLite: `pdo_sqlite` ซึ่ง PHP เปิดใช้งานเป็นค่าเริ่มต้น ใช้ DSN เช่น `sqlite:/var/www/html/var/app.sqlite` หรือ `sqlite::memory:`

ให้ application เป็นผู้เลือก driver จาก environment ของตัวเอง ตัวอย่างชื่อแปรที่นิยมใช้:

```env
DB_DRIVER=pgsql
DB_DSN=pgsql:host=postgres;port=5432;dbname=app
DB_USER=app
DB_PASSWORD=change-me
```

ชื่อตัวแปรและรูปแบบ DSN ต้องตรงกับ framework/application ที่ใช้; image นี้ไม่อ่านหรือแปลง `DB_*` ให้โดยอัตโนมัติ อย่าใส่ secret ลงใน image หรือ commit ไฟล์ `.env` ที่มีรหัสผ่าน ให้ inject ตอน runtime ผ่าน secret manager หรือกลไกของ deployment platform

สำหรับ SQL Server หรือ Oracle ไม่มี driver ใน image นี้ เพราะต้องใช้ dependency และ license/vendor setup เพิ่มเติม ให้สร้าง Dockerfile ต่อจาก image นี้ แล้วติดตั้ง `pdo_sqlsrv` ตามคู่มือ Microsoft หรือ OCI8 ตามคู่มือ PHP/Oracle และเพิ่ม smoke test ของ driver นั้นก่อนใช้งานจริง:

```dockerfile
FROM php-runtime:test
# ติดตั้ง vendor dependencies และ PHP driver ตามเอกสารทางการของผู้ให้บริการ
```

อ้างอิง: PDO MySQL https://www.php.net/manual/en/ref.pdo-mysql.php, PDO PostgreSQL https://www.php.net/manual/en/ref.pdo-pgsql.php, PDO SQLite https://www.php.net/manual/en/ref.pdo-sqlite.php, SQL Server https://learn.microsoft.com/en-us/sql/connect/php/installation-tutorial-linux-mac และ OCI8 https://www.php.net/manual/en/oci8.installation.php

## ข้อควรระวังเกี่ยวกับ port 80

- Port 80 บน host ต้องว่าง; หากมี web server หรือ container อื่นใช้อยู่ `docker compose up` จะเริ่มไม่สำเร็จ
- การ publish `80:8080` จะรับการเชื่อมต่อจากทุก network interface ตามค่าเริ่มต้นของ Docker จึงควรใช้เฉพาะเครื่องหรือ firewall ที่เหมาะสม
- ถ้าต้องการให้เข้าจากเครื่องเดียว ให้เปลี่ยนใน `compose.yaml` เป็น `127.0.0.1:80:8080`

Docker กำหนด port mapping เป็น `HOST_PORT:CONTAINER_PORT`; ดูเอกสารทางการที่ https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/ และ Composer แนะนำการคัดลอก binary จาก image `composer/composer:2-bin` ที่ https://getcomposer.org/doc/00-intro.md

## ข้อตกลงของ base image

Base image คือ Docker Official Image `php:8.5.9-apache-bookworm` ที่ pin ด้วย multi-platform manifest index:

```
php@sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b
```

ตรวจสอบเมื่อ 2026-08-22 ว่า image สืบทอดจาก Debian `bookworm-slim` และมี manifest สำหรับ `linux/amd64` กับ `linux/arm64` ให้เปลี่ยน digest เฉพาะใน dependency-update PR ที่ผ่านการ review และต้อง run smoke test ซ้ำทั้งสอง platform โดย source ของ PHP image ระบุ variant นี้ด้วย `FROM debian:bookworm-slim`

Sources: https://hub.docker.com/_/php/tags?name=apache-b and https://github.com/docker-library/php/blob/445bf414f1d5866f7aef715f1203eae043710070/8.5/bookworm/apache/Dockerfile

## Build และตรวจสอบ image

```sh
docker build -t php-runtime:test .
IMAGE=php-runtime:test sh ./test/image-smoke.sh
```

บน Windows ที่ใช้ Docker Desktop/WSL ให้ run smoke script ใน POSIX shell ส่วน static contract check สามารถ run จาก PowerShell ได้:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\dockerfile-contract.ps1
```

Smoke test ตรวจ PHP `8.5.9`; built-in prereqs รวมถึง `mbstring`, `sodium`, `intl`, `curl`, `PDO`, `pdo_mysql`, `pdo_pgsql`, `pdo_sqlite`; ผู้ใช้ non-root; Apache ที่ port 8080; Composer 2 และไม่มี `psql` หรือ SimpleSAMLphp payload

ข้อกำหนด extension และ public directory อ้างอิงคู่มือทางการของ SimpleSAMLphp 2.5: https://simplesamlphp.org/docs/2.5/simplesamlphp-install.html

## ข้อตกลงสำหรับ consumer

Apache รันด้วย `www-data` ที่ port `8080` ภายใน container โดย default document root ว่างและปิด directory listing consumer ในอนาคตต้องเตรียม SimpleSAMLphp 2.5.x ที่ pin version แยกต่างหาก และตั้งค่า vhost ให้ expose เฉพาะ `public/` directory ของ application ห้าม expose configuration, metadata, certificate หรือ source directory

ส่ง database URL และ secrets ตอน runtime โดย database server ต้องเป็น service แยก image นี้มี PDO drivers เพื่อเชื่อมต่อ MySQL/MariaDB, PostgreSQL และ SQLite สำหรับ Production Compose ต้องใช้ immutable digest ที่ publish แล้ว ไม่ใช้ mutable tag:

```yaml
image: ghcr.io/OWNER/REPOSITORY@sha256:RELEASE_DIGEST
```

## Release workflow

GitHub Actions ตรวจ amd64 และ arm64 แยกกัน (รวม smoke test) จากนั้น tag push ที่ตรงกับ `8.5.9-*` จะ publish GHCR manifest แบบสอง platform workflow แสดง digest ใน run summary, เปิด BuildKit provenance และ SBOM, cache layer ใน GitHub Actions Cache และเก็บ Trivy report ไว้ งานจะ fail หากพบ `HIGH` หรือ `CRITICAL` ที่ไม่ได้ waive โดย visibility ของ GHCR ขึ้นกับ repository/package policy; ค่าเริ่มต้นที่ตั้งใจไว้คือ private

Sources: https://docs.docker.com/build/ci/github-actions/multi-platform/ ; https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images ; https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations

Rollback คือ deploy digest ก่อนหน้าที่ผ่านการตรวจสอบแล้ว ห้าม retag หรือ rebuild release เก่า
