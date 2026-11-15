#!/bin/sh
set -eu

alembic upgrade head
PYTHONPATH=/app python scripts/seed.py

if [ "${HTTPS_ENABLED:-false}" = "true" ]; then
    certfile="${HTTPS_CERTFILE:-/certs/fullchain.pem}"
    keyfile="${HTTPS_KEYFILE:-/certs/privkey.pem}"

    if [ ! -f "$certfile" ] || [ ! -f "$keyfile" ]; then
        if [ "${HTTPS_AUTO_GENERATE_DEV_CERT:-false}" != "true" ]; then
            echo "HTTPS is enabled but the certificate or key is missing." >&2
            echo "Provide CA-issued files or enable HTTPS_AUTO_GENERATE_DEV_CERT only for local development." >&2
            exit 1
        fi

        mkdir -p "$(dirname "$certfile")" "$(dirname "$keyfile")"
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$keyfile" \
            -out "$certfile" \
            -days 365 \
            -subj "/CN=localhost" \
            -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
        chmod 600 "$keyfile"
        echo "Generated a local self-signed certificate; do not use it in production."
    fi

    exec uvicorn app.main:app --host 0.0.0.0 --port 8443 \
        --ssl-certfile "$certfile" \
        --ssl-keyfile "$keyfile"
fi

exec uvicorn app.main:app --host 0.0.0.0 --port 8000
