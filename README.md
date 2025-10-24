# PostgreSQL Backup to S3

A secure Docker container for automated PostgreSQL database backups to S3-compatible storage. The container runs a single backup operation and terminates, making it ideal for scheduled backups via cron or container orchestration.

## 🔧 Environment Variables

### ✅ Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `PGHOST` | PostgreSQL server hostname/IP | `192.168.1.100` |
| `PGUSER` | PostgreSQL username | `postgres` |
| `PGPASSWORD` | PostgreSQL password | `secret123` |
| `BACKUP_S3_KEY` | S3 access key | `AKIAIOSFODNN7EXAMPLE` |
| `BACKUP_S3_SECRET` | S3 secret key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |
| `BACKUP_S3_PATH` | S3 destination path | `s3://my-bucket/backups/` |

### ⚙️ Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DB_NAME` | - | Specific database to backup (if not set, backs up all databases) |
| `BACKUP_S3_HOST` | `s3.amazonaws.com` | S3-compatible service host |
| `BACKUP_S3_HOST_BUCKET` | `%(bucket)s.s3.amazonaws.com` | S3 host bucket format |
| `BACKUP_NO_SSL` | `false` | Disable SSL for S3 connections |
| `TZ` | `UTC` | Timezone for backup timestamps |

### 🔐 Secret File Variables (Alternative to Direct Environment Variables)

For enhanced security, use these variables to read credentials from files:

| Variable | Description | Example |
|----------|-------------|---------|
| `PGPASSWORD_FILE` | Path to file containing PostgreSQL password | `/run/secrets/pg_password` |
| `DB_NAME_FILE` | Path to file containing database name | `/run/secrets/db_name` |
| `BACKUP_S3_KEY_FILE` | Path to file containing S3 access key | `/run/secrets/s3_key` |
| `BACKUP_S3_SECRET_FILE` | Path to file containing S3 secret key | `/run/secrets/s3_secret` |

## 🛡️ Security Features

- **Read-only filesystem**: Container runs with read-only root filesystem
- **Non-root user**: Runs as `backupuser` instead of root
- **No new privileges**: Security option prevents privilege escalation
- **Temporary filesystem**: Uses tmpfs for temporary storage with size limits
- **Secret file support**: Credentials can be stored in Docker secrets

## 📁 Backup Naming Convention

Backups are named with timestamp and database information:
- Single database: `YYYYMMDDHHMMSS_database_name_postgredump.sql.gz`
- All databases: `YYYYMMDDHHMMSS_all_postgredump.sql.gz`

---

**Disclaimer**: This repository was developed with the assistance of an AI assistant. Please review all code and configurations before use in production environments.