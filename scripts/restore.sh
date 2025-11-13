#!/usr/bin/env bash
set -euo pipefail
# Skrip restore: memulihkan dump DB dan arsip data yang dihasilkan oleh skrip backup
# Penggunaan: ./scripts/restore.sh <backup-sql-file> <backup-data-archive> [--drop]

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ "$#" -lt 2 ]; then
  echo "Penggunaan: $0 <db-dump.sql> <data-archive.tar.gz> [--drop]" >&2
  exit 2
fi

DB_DUMP_FILE=$1
DATA_ARCHIVE=$2
DROP_OPTION=${3:-}

if [ ! -f "$DB_DUMP_FILE" ]; then
  echo "File dump DB tidak ditemukan: $DB_DUMP_FILE" >&2
  exit 1
fi
if [ ! -f "$DATA_ARCHIVE" ]; then
  echo "Arsip data tidak ditemukan: $DATA_ARCHIVE" >&2
  exit 1
fi

# Muat .env jika ada (untuk nama container dan kredensial DB)
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs) || true
fi

DB_CONTAINER=${DB_CONTAINER:-nc-tristan-db}
APP_CONTAINER=${APP_CONTAINER:-nc-tristan-app}

if [ -z "${MYSQL_USER:-}" ] || [ -z "${MYSQL_PASSWORD:-}" ] || [ -z "${MYSQL_DATABASE:-}" ]; then
  echo "Variabel MYSQL_USER / MYSQL_PASSWORD / MYSQL_DATABASE tidak ditemukan di environment atau .env" >&2
  exit 1
fi

echo "Memulihkan database dari $DB_DUMP_FILE ke container $DB_CONTAINER"

if [ "$DROP_OPTION" = "--drop" ]; then
  echo "Menghapus dan membuat ulang database sebelum impor"
  docker exec -i "$DB_CONTAINER" sh -c "mysql -u${MYSQL_USER} -p\"${MYSQL_PASSWORD}\" -e 'DROP DATABASE IF EXISTS ${MYSQL_DATABASE}; CREATE DATABASE ${MYSQL_DATABASE};'"
fi

cat "$DB_DUMP_FILE" | docker exec -i "$DB_CONTAINER" sh -c "mysql -u${MYSQL_USER} -p\"${MYSQL_PASSWORD}\" ${MYSQL_DATABASE}"

echo "Memulihkan direktori data ke container $APP_CONTAINER (akan menimpa data yang ada)"
# Ekstrak konten ke direktori sementara di host lalu salin ke container
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT
tar -xzf "$DATA_ARCHIVE" -C "$TMPDIR"

# Diasumsikan arsip berisi direktori bernama 'data' di root
docker cp "$TMPDIR/data" "$APP_CONTAINER":/var/www/html/

echo "Restore selesai. Disarankan menjalankan occ maintenance:repair di dalam container app dan periksa permission file."
echo "Contoh: docker exec -it $APP_CONTAINER bash -c 'occ maintenance:repair && chown -R www-data:www-data /var/www/html/data'"
