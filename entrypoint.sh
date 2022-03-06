#!/bin/sh
set +e

BACKUP_CRON_SCHEDULE=${BACKUP_CRON_SCHEDULE:-"0 5 * * *"}
echo "${BACKUP_CRON_SCHEDULE} /usr/local/bin/backup" > /etc/crontabs/root

# Starting cron
crond -f -l 4
