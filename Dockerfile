FROM alpine:latest

RUN apk add --no-cache postgresql-client s3cmd

COPY backup /usr/local/bin/
RUN chmod +x /usr/local/bin/backup

RUN apk add --no-cache tzdata

COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

# Create a non-root user for security
RUN adduser -D -s /bin/sh backupuser
COPY s3cfg /home/backupuser/.s3cfg
RUN chown backupuser:backupuser /home/backupuser/.s3cfg
USER backupuser

CMD ["/sbin/entrypoint.sh"]
