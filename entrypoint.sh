#!/bin/sh
set +e

# Set timezone via environment variable (no root required)
TZ=${TZ:-UTC}
if [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    export TZ
else
    echo "Warning: Invalid timezone '${TZ}', using UTC as fallback"
    export TZ=UTC
fi

# Run backup immediately and terminate
echo "Running backup..."
/usr/local/bin/backup
echo "Backup completed. Container terminating."
