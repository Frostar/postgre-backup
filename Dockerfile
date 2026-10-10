# === Build stage: stage the runtime packages into /rootfs =====================
# Packages resolve from the DHI hardened apk repo where available
# (postgresql-client, tzdata, ca-certificates), plus stock Alpine
# main/community for s3cmd, which DHI does not carry.
FROM dhi.io/alpine-base:3.24-dev AS packages

# Derive the Alpine branch from the image's own DHI repo URL so the stock
# repo URLs below always match the base image after Renovate bumps it.
# --no-scripts skips install triggers (they would need a shell inside
# /rootfs), so the postgresql /usr/bin symlinks are created manually.
RUN mkdir -p /rootfs/etc/apk \
 && cp -r /etc/apk/keys /rootfs/etc/apk/ \
 && cp /etc/apk/repositories /rootfs/etc/apk/ \
 && v="$(sed -n 's#.*/apk/alpine/\(v[0-9.]*\)/main#\1#p' /etc/apk/repositories | head -n1)" \
 && printf 'https://dl-cdn.alpinelinux.org/alpine/%s/main\nhttps://dl-cdn.alpinelinux.org/alpine/%s/community\n' "$v" "$v" \
      >> /rootfs/etc/apk/repositories \
 && apk add --root /rootfs --initdb --no-cache --no-scripts \
      postgresql-client s3cmd tzdata ca-certificates \
 && for f in /rootfs/usr/libexec/postgresql*/*; do \
      ln -sf "${f#/rootfs}" "/rootfs/usr/bin/${f##*/}"; \
    done \
 && rm -rf /rootfs/etc/apk /rootfs/lib/apk /rootfs/var/cache \
           /rootfs/etc/passwd /rootfs/etc/group /rootfs/etc/shadow

# === Runtime stage ============================================================
# Hardened minimal base: busybox only, no package manager, runs as the
# built-in nonroot user (uid 65532).
FROM dhi.io/alpine-base:3.24

COPY --from=packages /rootfs /

COPY --chmod=755 backup /usr/local/bin/backup
COPY --chmod=755 entrypoint.sh /sbin/entrypoint.sh
COPY --chown=65532:65532 s3cfg /home/nonroot/.s3cfg

USER nonroot

CMD ["/sbin/entrypoint.sh"]
