#!/usr/bin/env bash
set -euo pipefail
# Skrip backup sederhana yang melakukan dump database MariaDB dan mengarsipkan data Nextcloud
# Penggunaan: ./scripts/backup.sh [output-dir]

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# Muat .env jika ada
if [ -f .env ]; then
  # eksport variabel dalam bentuk KEY=VALUE, abaikan baris komentar
  export $(grep -v '^#' .env | xargs) || true
fi

OUT_DIR=${1:-${BACKUP_DIR:-./backups}}
mkdir -p "$OUT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

DB_CONTAINER=${DB_CONTAINER:-nc-tristan-db}
APP_CONTAINER=${APP_CONTAINER:-nc-tristan-app}

echo "Memulai backup ke $OUT_DIR"

if [ -z "${MYSQL_USER:-}" ] || [ -z "${MYSQL_PASSWORD:-}" ] || [ -z "${MYSQL_DATABASE:-}" ]; then
  echo "Variabel MYSQL_USER / MYSQL_PASSWORD / MYSQL_DATABASE tidak ditemukan di environment atau .env" >&2
  exit 1
fi

DB_DUMP_FILE="$OUT_DIR/db_${TIMESTAMP}.sql"
DATA_ARCHIVE="$OUT_DIR/data_${TIMESTAMP}.tar.gz"

echo "Melakukan dump database dari container $DB_CONTAINER ke $DB_DUMP_FILE"
docker exec -i "$DB_CONTAINER" sh -c "exec mysqldump --single-transaction -u${MYSQL_USER} -p\"${MYSQL_PASSWORD}\" ${MYSQL_DATABASE}" > "$DB_DUMP_FILE"

echo "Mengarsipkan direktori data Nextcloud dari container $APP_CONTAINER ke $DATA_ARCHIVE"
docker exec -i "$APP_CONTAINER" sh -c "tar -C /var/www/html -czf - data" > "$DATA_ARCHIVE"

echo "Backup selesai:"
ls -lh "$OUT_DIR"
