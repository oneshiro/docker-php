#!/bin/sh
set -eu

if [ -z "${HTTPS_CERT_FILE:-}" ] && [ -z "${HTTPS_KEY_FILE:-}" ]; then
    HTTPS_CERT_FILE=/var/run/apache2/self-signed.crt
    HTTPS_KEY_FILE=/var/run/apache2/self-signed.key
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -keyout "$HTTPS_KEY_FILE" \
        -out "$HTTPS_CERT_FILE" \
        -subj "/CN=localhost" \
        -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
    chmod 600 "$HTTPS_KEY_FILE"
    chmod 644 "$HTTPS_CERT_FILE"
elif [ -z "${HTTPS_CERT_FILE:-}" ] || [ -z "${HTTPS_KEY_FILE:-}" ]; then
    echo "Set both HTTPS_CERT_FILE and HTTPS_KEY_FILE, or leave both unset." >&2
    exit 1
fi

if [ ! -r "$HTTPS_CERT_FILE" ] || [ ! -r "$HTTPS_KEY_FILE" ]; then
    echo "The HTTPS certificate and key must be readable by www-data." >&2
    exit 1
fi

export HTTPS_CERT_FILE HTTPS_KEY_FILE
exec "$@"
