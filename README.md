# PHP 8.5.9 Apache Runtime

Docker image สำหรับรัน PHP 8.5.9 บน Apache 2.4 รองรับ `linux/amd64` และ `linux/arm64` ออกแบบเป็น runtime กลางสำหรับนำ application มาติดตั้งหรือ mount เพิ่มภายหลัง

Image รันด้วยผู้ใช้ non-root `www-data` ภายใน container, Apache ฟัง HTTP ที่ port `8080` และ HTTPS ที่ port `8443` มี Composer 2 พร้อมใช้งาน ไม่รวม application code, database server, credentials หรือไฟล์ secret

## ส่วนประกอบหลัก

- PHP 8.5.9 บน Debian Bookworm
- Apache 2.4 พร้อม `mod_rewrite` และ `mod_ssl`
- Composer 2 จาก official Composer image
- `unzip` สำหรับแตก ZIP archive ที่ Composer ใช้งานได้
- PDO สำหรับเชื่อมต่อ MySQL/MariaDB, PostgreSQL และ SQLite
- Apache ทำงานด้วย `www-data` และไม่ใช้สิทธิ์ root
- GitHub Actions build และตรวจทั้ง `amd64` กับ `arm64`
- Trivy สร้างรายงานช่องโหว่ทั้งหมด และบล็อก `HIGH/CRITICAL` ซึ่งมีแพตช์

## PHP extensions

Extensions สำคัญพร้อมใช้งานใน image:

| Extension | ใช้งาน |
| --- | --- |
| `bcmath` | คำนวณเลขแบบ arbitrary precision |
| `curl` | ติดต่อ HTTP/HTTPS API |
| `intl` | locale, Unicode และ internationalization |
| `ldap` | เชื่อมต่อ LDAP directory service |
| `mbstring` | จัดการข้อความหลาย byte |
| `sodium` | cryptography |
| `SimpleXML` | อ่านและประมวลผล XML |
| `zip` | อ่านและเขียน ZIP archive |
| `PDO` | API กลางสำหรับฐานข้อมูล |
| `pdo_mysql` | MySQL และ MariaDB |
| `pdo_pgsql` | PostgreSQL |
| `pdo_sqlite` | SQLite |

ตรวจรายการทั้งหมดจาก container:

```sh
docker compose run --rm php php -m
```

## Build และ Run

เปิด service ผ่าน host port `80` และ `443`:

```sh
docker compose up --build -d
docker compose ps
```

เข้าใช้ได้ทั้ง `http://localhost` และ `https://localhost` โดย Compose map `80:8080` และ `443:8443` ตามลำดับ Container สร้าง self-signed certificate สำหรับ `localhost` ตอนเริ่มทำงาน จึงมีคำเตือนเรื่องความน่าเชื่อถือใน browser

สำหรับ production ให้ mount certificate และ private key ของ domain แล้วตั้งค่า path ใน `compose.override.yaml`:

```yaml
services:
  php:
    environment:
      HTTPS_CERT_FILE: /certs/fullchain.pem
      HTTPS_KEY_FILE: /certs/privkey.pem
    volumes:
      - ./certs:/certs:ro
```

วางไฟล์ certificate ใน `./certs` private key ต้องไม่เข้ารหัส และกำหนด permission ให้ process `www-data` (UID 33) อ่าน certificate กับ private key ได้

ตรวจ PHP, Composer และ `unzip`:

```sh
docker compose run --rm php php --version
docker compose run --rm php composer --version
docker compose run --rm php unzip -v
```

หยุด service:

```sh
docker compose down
```

Document root เริ่มต้นไม่มี application ให้ build application ต่อจาก image นี้ หรือ mount source เข้า `/var/www/html`

## เชื่อมต่อฐานข้อมูล

ตัวอย่าง DSN:

```text
mysql:host=mysql;port=3306;dbname=app;charset=utf8mb4
pgsql:host=postgres;port=5432;dbname=app
sqlite:/var/www/html/var/app.sqlite
```

Application ต้องอ่านค่า database configuration เอง เช่น:

```env
DB_DRIVER=pgsql
DB_DSN=pgsql:host=postgres;port=5432;dbname=app
DB_USER=app
DB_PASSWORD=change-me
```

อย่าเก็บรหัสผ่านใน image หรือ commit ไฟล์ `.env` ซึ่งมี secret ให้ส่งค่าผ่าน secret manager หรือ deployment platform ตอน runtime

SQL Server และ Oracle ต้องเพิ่ม vendor libraries กับ PHP driver ใน downstream Dockerfile แล้วเพิ่ม smoke test เฉพาะ driver ก่อนใช้งานจริง

## ทดสอบ image

```sh
docker build -t php-runtime:test .
IMAGE=php-runtime:test sh ./test/image-smoke.sh
```

Static contract บน Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\test\dockerfile-contract.ps1
```

Smoke test ตรวจ version, extensions, Composer, `unzip`, non-root user และ PHP endpoint ผ่าน Apache port `8080`

## GHCR และ Release

การ push Git tag ชื่อใดก็ได้จะ trigger workflow เพื่อ validate, build multi-platform image และ publish ไปยัง:

```text
ghcr.io/OWNER/REPOSITORY:TAG
```

ตัวอย่าง:

```sh
docker pull ghcr.io/oneshiro/docker-php:8.5.9
docker run -d --name php-runtime -p 80:8080 -p 443:8443 ghcr.io/oneshiro/docker-php:8.5.9
```

Production ควร pin immutable digest จาก GitHub Actions run summary:

```yaml
image: ghcr.io/oneshiro/docker-php@sha256:RELEASE_DIGEST
```

แก้ README อย่างเดียวไม่ต้องสร้าง tag ใหม่ เพราะเนื้อหาเอกสารไม่เปลี่ยน image หากแก้ Dockerfile, runtime configuration หรือ dependency จึงค่อยสร้าง tag release ใหม่หลัง CI ผ่าน

## Base image

Base image pin ด้วย multi-platform digest:

```text
php@sha256:68e1de9a82af09f1b0ae70611bd64a8702069ac1e036bdc5a12eb48e1a5cab2b
```

เมื่อต้องอัปเดต base image ให้เปลี่ยน digestผ่าน dependency update ซึ่งผ่าน review แล้วรัน smoke test ซ้ำทั้ง `amd64` และ `arm64`
