FROM alpine:latest

RUN apk add --no-cache mariadb-client py3-pip py3-magic && pip install s3cmd

COPY backup /usr/local/bin/
RUN chmod +x /usr/local/bin/backup

RUN apk add tzdata && cp /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime && echo "Europe/Copenhagen" > /etc/timezone && apk del tzdata

COPY s3cfg /root/.s3cfg
COPY entrypoint.sh /sbin/entrypoint.sh
RUN chmod +x /sbin/entrypoint.sh

CMD /sbin/entrypoint.sh
