#!/bin/bash
# Nightly database backup with retention.
#
# Dumps the production Postgres (docker-compose.prod.yml "db" service) to
# backups/orderq-YYYY-MM-DD_HHMM.sql.gz and prunes dumps older than
# RETENTION_DAYS (default 14).
#
# Install as a cron job on the production host (as the user that owns the
# compose project):
#   crontab -e
#   30 2 * * * cd /home/ubuntu/OrderQ && ./scripts/backup_db.sh >> backups/backup.log 2>&1
#
# Restore:
#   gunzip -c backups/orderq-<date>.sql.gz | \
#     docker compose -f docker-compose.prod.yml exec -T db psql -U postgres -d orderq
#
# NOTE: this keeps backups on the same host. Replicate the backups/ directory
# offsite (S3, rclone, another machine) — see docs/BACKLOG.md.
set -euo pipefail

cd "$(dirname "$0")/.."

COMPOSE="docker compose -f docker-compose.prod.yml"
BACKUP_DIR="backups"
RETENTION_DAYS="${RETENTION_DAYS:-14}"
DB_NAME="${DB_NAME:-orderq}"
DB_USER="${DB_USER:-postgres}"
STAMP="$(date +%Y-%m-%d_%H%M)"
TARGET="${BACKUP_DIR}/orderq-${STAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo "[$(date -Is)] Dumping ${DB_NAME} to ${TARGET}"
${COMPOSE} exec -T db pg_dump -U "${DB_USER}" --clean --if-exists "${DB_NAME}" \
  | gzip > "${TARGET}"

# A dump that small is a failed dump — don't silently keep it.
if [ "$(stat -c%s "${TARGET}")" -lt 1024 ]; then
  echo "[$(date -Is)] ERROR: dump is suspiciously small, keeping as .failed"
  mv "${TARGET}" "${TARGET}.failed"
  exit 1
fi

echo "[$(date -Is)] Pruning dumps older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name 'orderq-*.sql.gz' -mtime "+${RETENTION_DAYS}" -delete

echo "[$(date -Is)] Done: $(du -h "${TARGET}" | cut -f1)"
